with Ada.Containers;
with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Natural_Order;
with Project_Tools.Files;

package body File_Operations_Tests is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Containers.Count_Type;
   use type FS.File_Kind;
   use type Listing.Entry_Kind;
   use type Listing.Read_Outcome;

   function Fixture_Directory return String is
     (Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-listing-fixture"));

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
         Remove_Fixture;
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
         Remove_Fixture;
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
      end Before;
   begin
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

   procedure Write (Path : String; Size : Natural) is
      Ok : Boolean;
   begin
      FS.Write_File (Path, [1 .. Size => 'x'], Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture file written: " & Path);
   end Write;
end File_Operations_Tests;
