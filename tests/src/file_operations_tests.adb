with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Accounts;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Temporary_Storage;
with Posix_Tools.Host_Adapters.Temporary_Storage.Testing;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Natural_Order;
with Project_Tools.Files;
with Test_Support;
with Tooling_Support;

package body File_Operations_Tests is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Containers.Count_Type;
   use type FS.Entry_Kind;
   use type FS.File_Kind;
   use type Listing.Entry_Kind;
   use type Listing.Read_Outcome;
   use type Posix_Tools.Accounts.Id;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Finish_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Read_Outcome;

   function Fixture_Directory return String is
     (Test_Support.Work_Path ("listing-fixture"));

   --  A directory with a file of each size, a subdirectory, a hidden file,
   --  and links to each and to nothing.
   procedure Make_Fixture;

   function Names (Entries : Listing.Entry_Vectors.Vector) return String;

   procedure Remove_Fixture;

   procedure Write (Path : String; Size : Natural);

   procedure Make_Fixture is
      Root : constant String := Fixture_Directory;
   begin
      Remove_Fixture;
      Ada.Directories.Create_Path (Project_Tools.Files.Join (Root, "dir"));
      Write (Project_Tools.Files.Join (Root, "file10.txt"), 10);
      Write (Project_Tools.Files.Join (Root, "file9.log"), 900);
      Write (Project_Tools.Files.Join (Root, "File2.txt"), 2);
      Write (Project_Tools.Files.Join (Root, ".hidden"), 1);

      if not FS.Create_Link ("file9.log", Project_Tools.Files.Join (Root, "to-file"))
        or else not FS.Create_Link ("dir", Project_Tools.Files.Join (Root, "to-dir"))
        or else not FS.Create_Link ("nowhere", Project_Tools.Files.Join (Root, "to-nothing"))
      then
         AUnit.Assertions.Assert (False, "fixture links could not be made");
      end if;
   end Make_Fixture;

   function Names (Entries : Listing.Entry_Vectors.Vector) return String is
      Result : Unbounded.Unbounded_String;
   begin
      for Item of Entries loop
         if Unbounded.Length (Result) > 0 then
            Unbounded.Append (Result, " ");
         end if;

         Unbounded.Append (Result, Item.Name);
      end loop;

      return Unbounded.To_String (Result);
   end Names;

   procedure Remove_Fixture is
      Root : constant String := Fixture_Directory;

      --  Links go first, so that removing the tree never goes through one.
      procedure Unlink (Name : String);

      procedure Unlink (Name : String) is
         Path : constant String := Project_Tools.Files.Join (Root, Name);
      begin
         if FS.Is_Link (Path) then
            AUnit.Assertions.Assert (FS.Delete_Link (Path), "fixture link removed: " & Name);
         end if;
      end Unlink;
   begin
      if FS.Kind (Root) = FS.Directory then
         Unlink ("to-file");
         Unlink ("to-dir");
         Unlink ("to-nothing");
         Ada.Directories.Delete_Tree (Root);
      end if;
   end Remove_Fixture;

   procedure Test_Directory_Listing (T : in out Fixture) is
      pragma Unreferenced (T);
      Entries : Listing.Entry_Vectors.Vector;
      Outcome : Listing.Read_Outcome;

      function Find (Name : String) return Listing.Listed_Entry;

      function Find (Name : String) return Listing.Listed_Entry is
      begin
         for Item of Entries loop
            if Unbounded.To_String (Item.Name) = Name then
               return Item;
            end if;
         end loop;

         AUnit.Assertions.Assert (False, "listed: " & Name);
         return Entries.First_Element;
      end Find;
   begin
      Make_Fixture;

      AUnit.Assertions.Assert
        (FS.Entry_Kind_Of (Project_Tools.Files.Join (Fixture_Directory, "file9.log")) = FS.Entry_Regular,
         "entry kind: regular file");
      AUnit.Assertions.Assert
        (FS.Entry_Kind_Of (Project_Tools.Files.Join (Fixture_Directory, "dir")) = FS.Entry_Directory,
         "entry kind: directory");
      AUnit.Assertions.Assert
        (FS.Entry_Kind_Of (Project_Tools.Files.Join (Fixture_Directory, "to-file")) = FS.Entry_Link
         and then FS.Entry_Kind_Of (Project_Tools.Files.Join (Fixture_Directory, "to-nothing")) = FS.Entry_Link,
         "entry kind: resolving and broken links");
      AUnit.Assertions.Assert
        (FS.Entry_Kind_Of (Project_Tools.Files.Join (Fixture_Directory, "missing")) = FS.Entry_Missing,
         "entry kind: missing");

      Listing.Read_Directory (Fixture_Directory, (Include_Hidden => False, With_Status => True), Entries, Outcome);
      AUnit.Assertions.Assert (Outcome = Listing.Read_Complete, "read completes");
      AUnit.Assertions.Assert
        (Entries.Length = 7, "every entry but the hidden one, and never . or ..: " & Names (Entries));

      AUnit.Assertions.Assert (Find ("dir").Kind = Listing.Directory_Entry and then not Find ("dir").Is_Link, "dir");
      AUnit.Assertions.Assert
        (Find ("file9.log").Kind = Listing.Regular_Entry and then Find ("file9.log").Status.Size = 900,
         "a file with its own size");
      AUnit.Assertions.Assert
        (Find ("to-file").Is_Link
         and then Find ("to-file").Kind = Listing.Regular_Entry
         and then Unbounded.To_String (Find ("to-file").Link_Target) = "file9.log",
         "a link to a file is a link, with the kind and the target it points to");
      AUnit.Assertions.Assert
        (Find ("to-dir").Is_Link and then Find ("to-dir").Kind = Listing.Directory_Entry, "a link to a directory");
      AUnit.Assertions.Assert
        (Find ("to-nothing").Is_Link and then Find ("to-nothing").Kind = Listing.Missing_Entry,
         "a link to nothing is listed, as missing");
      AUnit.Assertions.Assert
        (Find ("file9.log").Status.Available and then Find ("file9.log").Status.Mode mod 8#1000# /= 0,
         "status carries the permission bits");
      declare
         Path                : constant String :=
           Project_Tools.Files.Join (Fixture_Directory, "file9.log");
         Status              : constant FS.Entry_Status := Find ("file9.log").Status;
         Native              : constant Hostkit.Metadata.Entry_Status :=
           Hostkit.Metadata.Entry_Status_Of (Path);
      begin
         AUnit.Assertions.Assert
           (Status.Available
            and then Native.Available
            and then Status.Size = Long_Long_Integer (Native.Size)
            and then Status.Modified_Seconds = Native.Modified_Seconds
            and then Status.Mode = Native.Mode
            and then Status.User = Posix_Tools.Accounts.Id (Native.User_Id)
            and then Status.Group = Posix_Tools.Accounts.Id (Native.Group_Id),
            "entry status preserves Hostkit's coherent portable metadata");
      end;
      declare
         Path   : constant String :=
           Project_Tools.Files.Join (Fixture_Directory, "to-file");
         Status : constant FS.Entry_Status := Find ("to-file").Status;
         Native : constant Hostkit.Metadata.Entry_Status :=
           Hostkit.Metadata.Entry_Status_Of (Path);
      begin
         AUnit.Assertions.Assert
           (Status.Available
            and then Native.Available
            and then Status.Mode / 8#10000# mod 16 = 10
            and then Status.Size = Long_Long_Integer (Native.Size)
            and then Status.Modified_Seconds = Native.Modified_Seconds
            and then Status.Mode = Native.Mode
            and then Status.User = Posix_Tools.Accounts.Id (Native.User_Id)
            and then Status.Group = Posix_Tools.Accounts.Id (Native.Group_Id),
            "link status is one coherent no-follow observation");

         declare
            Followed : constant FS.Entry_Status := FS.File_Status_Of (Path);
            Native_Followed : constant Hostkit.Metadata.Entry_Status :=
              Hostkit.Metadata.File_Status_Of (Path);
         begin
            AUnit.Assertions.Assert
              (Followed.Available
               and then Native_Followed.Available
               and then Followed.Mode / 8#10000# mod 16 = 8
               and then Followed.Size = Long_Long_Integer (Native_Followed.Size)
               and then Followed.Modified_Seconds =
                 Native_Followed.Modified_Seconds
               and then Followed.Mode = Native_Followed.Mode
               and then Followed.User =
                 Posix_Tools.Accounts.Id (Native_Followed.User_Id)
               and then Followed.Group =
                 Posix_Tools.Accounts.Id (Native_Followed.Group_Id),
               "followed status is one coherent Hostkit observation");
         end;
      end;

      Listing.Read_Directory (Fixture_Directory, (Include_Hidden => True, With_Status => False), Entries, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Listing.Read_Complete and then Entries.Length = 8, "hidden entries when asked for");
      AUnit.Assertions.Assert (not Find (".hidden").Status.Available, "no status when not asked for");

      declare
         Asked : Natural := 0;

         function Stop_After_Two return Boolean;

         function Stop_After_Two return Boolean is
         begin
            Asked := Asked + 1;
            return Asked > 2;
         end Stop_After_Two;
      begin
         Listing.Read_Directory
           (Fixture_Directory, (Include_Hidden => True, With_Status => True), Entries, Outcome,
            Stop_After_Two'Access);
         AUnit.Assertions.Assert
           (Outcome = Listing.Read_Stopped and then Entries.Length <= 2, "a stop request ends the read early");
      end;

      Listing.Read_Directory
        (Project_Tools.Files.Join (Fixture_Directory, "missing"), (others => <>), Entries, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Listing.Read_Failed and then Entries.Is_Empty, "a missing directory fails");

      Remove_Fixture;
   exception
      when others =>
         Tooling_Support.Best_Effort_Delete_Tree (Fixture_Directory);
         raise;
   end Test_Directory_Listing;

   procedure Test_Listing_Sort (T : in out Fixture) is
      pragma Unreferenced (T);
      Entries : Listing.Entry_Vectors.Vector;
      Outcome : Listing.Read_Outcome;

      procedure Expect (Order : Listing.Sort_Order; Expected : String);

      procedure Expect (Order : Listing.Sort_Order; Expected : String) is
      begin
         Listing.Sort (Entries, Order);
         AUnit.Assertions.Assert
           (Names (Entries) = Expected, Listing.Sort_Key'Image (Order.Key) & ": " & Names (Entries));
      end Expect;
   begin
      Make_Fixture;
      Listing.Read_Directory (Fixture_Directory, (Include_Hidden => False, With_Status => True), Entries, Outcome);

      Expect ((others => <>), "dir to-dir File2.txt file9.log file10.txt to-file to-nothing");
      Expect
        ((Key => Listing.By_Natural_Name, Directories_First => False, others => <>),
         "dir File2.txt file9.log file10.txt to-dir to-file to-nothing");
      Expect
        ((Key => Listing.By_Name, Fold_Case => False, others => <>),
         "dir to-dir File2.txt file10.txt file9.log to-file to-nothing");
      Expect
        ((Key => Listing.By_Natural_Name, Descending => True, others => <>),
         "to-dir dir to-nothing to-file file10.txt file9.log File2.txt");
      Expect
        ((Key => Listing.By_Extension, others => <>),
         "dir to-dir to-file to-nothing file9.log File2.txt file10.txt");

      declare
         Sizes : Listing.Entry_Vectors.Vector;
      begin
         for Item of Entries loop
            if Item.Kind = Listing.Regular_Entry and then not Item.Is_Link then
               Sizes.Append (Item);
            end if;
         end loop;

         Listing.Sort (Sizes, (Key => Listing.By_Size, others => <>));
         AUnit.Assertions.Assert (Names (Sizes) = "File2.txt file10.txt file9.log", "by size: " & Names (Sizes));
         Listing.Sort (Sizes, (Key => Listing.By_Size, Descending => True, others => <>));
         AUnit.Assertions.Assert
           (Names (Sizes) = "file9.log file10.txt File2.txt", "by size, largest first: " & Names (Sizes));
      end;

      AUnit.Assertions.Assert (Listing.Extension ("a.tar.gz") = "gz", "extension is after the last dot");
      AUnit.Assertions.Assert (Listing.Extension (".profile") = "", "a leading dot is not an extension");
      AUnit.Assertions.Assert (Listing.Extension ("README") = "", "no dot, no extension");

      Remove_Fixture;
   exception
      when others =>
         Tooling_Support.Best_Effort_Delete_Tree (Fixture_Directory);
         raise;
   end Test_Listing_Sort;

   procedure Test_Natural_Order (T : in out Fixture) is
      pragma Unreferenced (T);

      procedure Before (Left, Right : String; Fold_Case : Boolean := False);

      procedure Before (Left, Right : String; Fold_Case : Boolean := False) is
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Natural_Order.Less (Left, Right, Fold_Case),
            "'" & Left & "' before '" & Right & "'");
         AUnit.Assertions.Assert
           (not Posix_Tools.Text.Natural_Order.Less (Left => Right, Right => Left, Fold_Case => Fold_Case),
            "'" & Right & "' not before '" & Left & "'");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Natural_Order.Sort_Key (Left, Fold_Case)
              < Posix_Tools.Text.Natural_Order.Sort_Key (Right, Fold_Case),
            "the key of '" & Left & "' before that of '" & Right & "'");
      end Before;

      --  Every name of up to three characters from an alphabet of letters
      --  in both cases, digits with zeros, and a dot.
      Alphabet : constant String := "aAb019.";

      function Name (Number, Length : Natural) return String is
        (if Length = 0 then ""
         else Name (Number / Alphabet'Length, Length - 1) & Alphabet (Alphabet'First + Number mod Alphabet'Length));
   begin
      for Fold_Case in Boolean loop
         for Left_Length in 0 .. 3 loop
            for Left_Number in 0 .. Alphabet'Length ** Left_Length - 1 loop
               declare
                  Left     : constant String := Name (Left_Number, Left_Length);
                  Left_Key : constant String := Posix_Tools.Text.Natural_Order.Sort_Key (Left, Fold_Case);
               begin
                  for Right_Length in 0 .. 3 loop
                     for Right_Number in 0 .. Alphabet'Length ** Right_Length - 1 loop
                        declare
                           Right : constant String := Name (Right_Number, Right_Length);
                        begin
                           if Posix_Tools.Text.Natural_Order.Less (Left, Right, Fold_Case)
                             /= (Left_Key < Posix_Tools.Text.Natural_Order.Sort_Key (Right, Fold_Case))
                           then
                              AUnit.Assertions.Assert
                                (False, "keys order '" & Left & "' and '" & Right & "' as Less does");
                           end if;
                        end;
                     end loop;
                  end loop;
               end;
            end loop;
         end loop;
      end loop;

      Before ("file9", "file10");
      Before ("file2", "file10");
      Before ("a", "b");
      Before ("a", "a1");
      Before ("x1y2", "x1y10");
      Before ("v1.9", "v1.10");
      Before ("007", "8");
      Before ("a01", "a1");
      Before ("a001", "a01");
      Before ("B", "a");
      Before ("a", "B", Fold_Case => True);
      Before ("A", "a", Fold_Case => True);
      Before ("", "a");
      Before ("99999999999999999999999", "100000000000000000000000");
      AUnit.Assertions.Assert (not Posix_Tools.Text.Natural_Order.Less ("same", "same"), "irreflexive");
      AUnit.Assertions.Assert (not Posix_Tools.Text.Natural_Order.Less ("", ""), "empty is not before itself");
   end Test_Natural_Order;

   procedure Test_Permission_Image (T : in out Fixture) is
      pragma Unreferenced (T);
      package Modes renames Posix_Tools.Text.File_Modes;
   begin
      AUnit.Assertions.Assert (Modes.Permission_Image (8#755#) = "rwxr-xr-x", "755");
      AUnit.Assertions.Assert (Modes.Permission_Image (8#640#) = "rw-r-----", "640");
      AUnit.Assertions.Assert (Modes.Permission_Image (0) = "---------", "000");
      AUnit.Assertions.Assert (Modes.Permission_Image (8#4755#) = "rwsr-xr-x", "set-user-ID with execute");
      AUnit.Assertions.Assert (Modes.Permission_Image (8#2644#) = "rw-r-Sr--", "set-group-ID without execute");
      AUnit.Assertions.Assert (Modes.Permission_Image (8#1777#) = "rwxrwxrwt", "sticky with execute");
      AUnit.Assertions.Assert (Modes.Permission_Image (8#1666#) = "rw-rw-rwT", "sticky without execute");
   end Test_Permission_Image;

   procedure Test_Temporary_Storage_Long_Path (T : in out Fixture) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      use type Hostkit.Fs.Delete_Tree_Outcome;

      Was_Defined : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Value   : constant String :=
        (if Was_Defined then Ada.Environment_Variables.Value ("TMPDIR") else "");
      Base : constant String := Hostkit.Fs.Create_Temporary_Directory ("posix-tools-long-temp");
      Root : Unbounded_String := To_Unbounded_String (Base);

      procedure Restore is
      begin
         if Was_Defined then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Value);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore;

      procedure Cleanup_Safely is
         Ignored : Hostkit.Fs.Delete_Tree_Outcome;
         pragma Unreferenced (Ignored);
      begin
         Restore;
         if Base /= "" and then Ada.Directories.Exists (Base) then
            Ignored := Hostkit.Fs.Delete_Tree_No_Follow (Base);
         end if;
      exception
         when others =>
            --  Intentional terminal exception barrier
            --  Preserve the exception raised by the storage test.
            null;
      end Cleanup_Safely;

      procedure Remove_Base is
         Outcome : Hostkit.Fs.Delete_Tree_Outcome;
      begin
         if Base /= "" and then Ada.Directories.Exists (Base) then
            Outcome := Hostkit.Fs.Delete_Tree_No_Follow (Base);
            AUnit.Assertions.Assert (Outcome = Hostkit.Fs.Tree_Deleted, "temporary fixture removed");
         end if;
      end Remove_Base;
   begin
      --  This regression exercises the POSIX TMPDIR path.  Windows uses a
      --  different temporary-directory API and has legacy path limits.
      if GNAT.OS_Lib.Directory_Separator /= '/' then
         Remove_Base;
         return;
      end if;

      AUnit.Assertions.Assert (Base /= "", "unique temporary fixture created");
      for Index in 1 .. 7 loop
         Append (Root, "/segment-" & Integer'Image (Index) & String'(1 .. 80 => 'x'));
      end loop;
      Ada.Directories.Create_Path (To_String (Root));
      Ada.Environment_Variables.Set ("TMPDIR", To_String (Root));

      declare
         Store : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Host_Adapters.Temporary_Storage.Create (Store, 1_024) =
              Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete,
            "temporary spill storage accepts paths longer than fixed legacy buffers");
      end;

      Restore;
      --  Delete_Directory succeeds only if Store.Finalize removed its spill
      --  file and the directory created beneath TMPDIR.
      Ada.Directories.Delete_Directory (To_String (Root));
      Remove_Base;
   exception
      when others =>
         Cleanup_Safely;
         raise;
   end Test_Temporary_Storage_Long_Path;

   procedure Test_Temporary_Storage_Outcomes (T : in out Fixture) is
      pragma Unreferenced (T);
      package Storage renames Posix_Tools.Host_Adapters.Temporary_Storage;
      Store : Storage.Store;
      Buffer : constant Ada.Streams.Stream_Element_Array (1 .. 3) := [1, 2, 3];
      Read_Buffer : Ada.Streams.Stream_Element_Array (1 .. 3);
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      if GNAT.OS_Lib.Directory_Separator = '/' then
         declare
            Name       : constant String := "TMPDIR";
            Invalid    : constant String :=
              Test_Support.Work_Path ("temporary-storage-invalid-base");
            Was_Set    : constant Boolean :=
              Ada.Environment_Variables.Exists (Name);
            Previous   : constant String :=
              (if Was_Set then Ada.Environment_Variables.Value (Name) else "");
            Restored   : Boolean := False;

            procedure Restore;

            procedure Restore is
            begin
               if not Restored then
                  if Was_Set then
                     Ada.Environment_Variables.Set (Name, Previous);
                  else
                     Ada.Environment_Variables.Clear (Name);
                  end if;
                  Restored := True;
               end if;
            end Restore;
         begin
            Test_Support.Delete_If_Exists (Invalid);
            Project_Tools.Files.Write_Raw_File (Invalid, "not a directory");
            Ada.Environment_Variables.Set (Name, Invalid);
            AUnit.Assertions.Assert
              (Storage.Create (Store, 3) = Storage.Create_Directory_Failed,
               "temporary-directory creation failure has a distinct outcome");
            Restore;
            Test_Support.Delete_If_Exists (Invalid);
         exception
            when others =>
               Restore;
               Test_Support.Delete_If_Exists (Invalid);
               raise;
         end;
      end if;

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "unprepared read fixture created");
      AUnit.Assertions.Assert
        (Storage.Read_Next (Store, Read_Buffer, Last) =
           Storage.Read_Not_Prepared,
         "an unprepared sequential read has a distinct outcome");
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store), "unprepared read fixture cleaned");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 2) = Storage.Create_Complete,
         "capacity fixture created");
      AUnit.Assertions.Assert
        (Storage.Append (Store, Buffer, Buffer'Last) =
           Storage.Append_Capacity_Exceeded,
         "capacity exhaustion has a distinct outcome");
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store), "capacity fixture cleaned");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "write failure fixture created");
      Storage.Testing.Close_Backing_File (Store);
      AUnit.Assertions.Assert
        (Storage.Append (Store, Buffer, Buffer'Last) =
           Storage.Append_Write_Failed,
         "host write failure has a distinct outcome");
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store), "write failure fixture cleaned");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "open failure fixture created");
      AUnit.Assertions.Assert
        (Storage.Append (Store, Buffer, Buffer'Last) =
           Storage.Append_Complete,
         "open failure fixture populated");
      Storage.Testing.Remove_Backing_File (Store);
      AUnit.Assertions.Assert
        (Storage.Prepare_For_Read (Store) = Storage.Prepare_Open_Failed,
         "read-open failure has a distinct outcome");
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store), "open failure fixture cleaned");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "read failure fixture created");
      AUnit.Assertions.Assert
        (Storage.Append (Store, Buffer, Buffer'Last) =
           Storage.Append_Complete,
         "read failure fixture populated");
      AUnit.Assertions.Assert
        (Storage.Finish_Writing (Store) = Storage.Finish_Complete,
         "read failure fixture finished");
      AUnit.Assertions.Assert
        (Storage.Prepare_For_Read (Store) = Storage.Prepare_Complete,
         "read failure fixture prepared");
      Storage.Testing.Close_Backing_File (Store);
      AUnit.Assertions.Assert
        (Storage.Read_Next (Store, Read_Buffer, Last) =
           Storage.Read_Transfer_Failed,
         "a host read failure has a distinct outcome");
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store), "read failure fixture cleaned");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "cleanup retry fixture created");
      Storage.Testing.Force_Cleanup_Failure (Store);
      AUnit.Assertions.Assert
        (not Storage.Try_Cleanup (Store),
         "a failed cleanup remains observable");
      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Cleanup_Failed,
         "create reports the retained cleanup failure");
      Storage.Testing.Repair_Cleanup_Failure (Store);
      AUnit.Assertions.Assert
        (Storage.Try_Cleanup (Store),
         "retained cleanup state can be repaired and retried");

      AUnit.Assertions.Assert
        (Storage.Create (Store, 3) = Storage.Create_Complete,
         "deferred cleanup fixture created");
      declare
         Failed_Path : constant String :=
           Storage.Testing.Backing_Path (Store);
         Failed_Directory : constant String :=
           Storage.Testing.Backing_Directory (Store);
      begin
         Storage.Testing.Force_Cleanup_Failure (Store);
         AUnit.Assertions.Assert
           (not Storage.Cleanup_Or_Defer (Store),
            "failed cleanup is transferred to deferred ownership");
         AUnit.Assertions.Assert
           (Storage.Testing.Backing_Path (Store) = "",
            "deferred store releases its cleanup path");

         Ada.Directories.Delete_Directory (Failed_Path);
         AUnit.Assertions.Assert
           (Storage.Create (Store, 3) = Storage.Create_Complete,
            "a later create retries deferred cleanup");
         AUnit.Assertions.Assert
           (not Ada.Directories.Exists (Failed_Directory),
            "deferred cleanup removes the recovered directory");
         AUnit.Assertions.Assert
           (Storage.Try_Cleanup (Store),
            "post-retry temporary store cleaned");
      end;

      declare
         Failed_Path      : Unbounded.Unbounded_String;
         Failed_Directory : Unbounded.Unbounded_String;
      begin
         declare
            Finalized_Store : Storage.Store;
         begin
            AUnit.Assertions.Assert
              (Storage.Create (Finalized_Store, 3) = Storage.Create_Complete,
               "finalizer cleanup fixture created");
            Failed_Path := Unbounded.To_Unbounded_String
              (Storage.Testing.Backing_Path (Finalized_Store));
            Failed_Directory := Unbounded.To_Unbounded_String
              (Storage.Testing.Backing_Directory (Finalized_Store));
            Storage.Testing.Force_Cleanup_Failure (Finalized_Store);
         end;

         Ada.Directories.Delete_Directory (Unbounded.To_String (Failed_Path));
         AUnit.Assertions.Assert
           (Storage.Create (Store, 3) = Storage.Create_Complete,
            "a later create retries cleanup deferred by finalization");
         AUnit.Assertions.Assert
           (not Ada.Directories.Exists
              (Unbounded.To_String (Failed_Directory)),
            "finalization preserves failed cleanup for a later retry");
         AUnit.Assertions.Assert
           (Storage.Try_Cleanup (Store),
            "post-finalizer-retry temporary store cleaned");
      end;
   end Test_Temporary_Storage_Outcomes;

   procedure Write (Path : String; Size : Natural) is
      Ok : Boolean;
   begin
      FS.Write_File (Path, [1 .. Size => 'x'], Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture file written: " & Path);
   end Write;
end File_Operations_Tests;
