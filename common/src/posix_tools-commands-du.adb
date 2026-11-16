with Ada.Containers;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Vectors;
with Ada.IO_Exceptions;
with Interfaces;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Counts;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Du is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   use type FS.Entry_Identity;

   function Identity_Hash (Value : FS.Entry_Identity) return Ada.Containers.Hash_Type;

   function Identity_Hash (Value : FS.Entry_Identity) return Ada.Containers.Hash_Type is
      use type Interfaces.Unsigned_64;
      Mixed : constant Interfaces.Unsigned_64 :=
        Value.Volume
        xor Interfaces.Rotate_Left (Value.File_Number, 13)
        xor Interfaces.Rotate_Left (Value.Generation_High, 29)
        xor Interfaces.Rotate_Left (Value.Generation_Low, 47);
   begin
      return Ada.Containers.Hash_Type
        (Mixed mod Interfaces.Unsigned_64 (Ada.Containers.Hash_Type'Modulus));
   end Identity_Hash;

   package Identity_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => FS.Entry_Identity,
      Hash                => Identity_Hash,
      Equivalent_Elements => "=");

   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Listed_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First        : Positive;
      Valid        : Boolean;
      All_Entries  : Boolean := False;
      Summary_Only : Boolean := False;
      Unit_Size    : Long_Long_Integer := 512;
      All_Ok       : Boolean := True;
      Seen_Identities : Identity_Sets.Set;
      Unidentified_Dirs : String_Vectors.Vector;
      Output        : Posix_Tools.Commands.Helpers.Output_Buffer;

      function Allocated_Units (Path : String) return Long_Long_Integer;
      function Already_Seen_Directory
        (Path      : String;
         Listed_As : FS.Listed_Kind) return Boolean;
      procedure Print_Usage (Units : Long_Long_Integer; Path : String);
      procedure Walk
        (Path        : String;
         Listed_As   : FS.Listed_Kind;
         Top_Level   : Boolean;
         Total_Units : in out Long_Long_Integer;
         Ok          : in out Boolean);

      function Allocated_Units (Path : String) return Long_Long_Integer is
         Available : Boolean := False;
         Bytes     : constant Long_Long_Integer := FS.Allocated_Size (Path, Available);
         pragma Unreferenced (Available);
      begin
         return Posix_Tools.Counts.Rounded_Units (Bytes, Unit_Size);
      end Allocated_Units;

      function Already_Seen_Directory
        (Path      : String;
         Listed_As : FS.Listed_Kind) return Boolean
      is
         --  Only a link (or a top-level/unknown entry) needs resolving before
         --  its identity is taken. A listed directory already names itself.
         Resolved : constant String :=
           (if Listed_As in FS.Listed_Link | FS.Listed_Unknown
            then FS.Real_Path (Path)
            else "");
         Identity : constant FS.Entry_Identity :=
           FS.Entry_Identity_Of ((if Resolved = "" then Path else Resolved));
      begin
         if Identity.Available then
            if Seen_Identities.Contains (Identity) then
               return True;
            end if;
            Seen_Identities.Include (Identity);
         else
            for I in 1 .. Natural (Unidentified_Dirs.Length) loop
               if FS.Same_File (Path, Unidentified_Dirs.Element (I)) then
                  return True;
               end if;
            end loop;
            Unidentified_Dirs.Append
              ((if Resolved = "" then FS.Full_Name (Path) else Resolved));
         end if;
         return False;
      end Already_Seen_Directory;

      procedure Print_Usage (Units : Long_Long_Integer; Path : String) is
         Line : constant String :=
           Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Units)
           & Character'Val (9) & Path;
      begin
         if not Context.Output_Failed then
            Posix_Tools.Commands.Helpers.Buffered_Put_Line
              (Output, Context, Line);
         end if;
      end Print_Usage;

      procedure Walk
        (Path        : String;
         Listed_As   : FS.Listed_Kind;
         Top_Level   : Boolean;
         Total_Units : in out Long_Long_Integer;
         Ok          : in out Boolean)
      is
         --  Directory enumeration already obtained these types without a
         --  metadata query. A direct size query both follows and classifies
         --  the usual link to a regular file; only links to other kinds need
         --  the more expensive general resolution path.
         Kind            : FS.File_Kind;
         Link_Units      : Long_Long_Integer := 0;
         Link_Is_Regular : Boolean := False;
      begin
         if Listed_As = FS.Listed_Link then
            begin
               Link_Units := Allocated_Units (Path);
               Link_Is_Regular := True;
            exception
               when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
                  null;
            end;
         end if;

         Kind :=
           (if Link_Is_Regular then FS.Ordinary_File
            else
              (case Listed_As is
                 when FS.Listed_Regular   => FS.Ordinary_File,
                 when FS.Listed_Directory => FS.Directory,
                 when FS.Listed_Other     => FS.Special_File,
                 when FS.Listed_Link | FS.Listed_Unknown => FS.Kind (Path)));

         case Kind is
            when FS.Missing_File | FS.Uninspectable_File =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               Ok := False;
            when FS.Ordinary_File | FS.Special_File =>
               declare
                  Size_Units : Long_Long_Integer := 0;
               begin
                  begin
                     Size_Units :=
                       (if Link_Is_Regular then Link_Units
                        else Allocated_Units (Path));
                  exception
                     when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
                        Posix_Tools.Commands.Helpers.Subject_Operational_Error
                          (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                        Ok := False;
                        return;
                  end;

                  Total_Units := Total_Units + Size_Units;
                  if All_Entries or else Top_Level then
                     Print_Usage (Size_Units, Path);
                  end if;
               end;
            when FS.Directory =>
               declare
                  Directory_Units : Long_Long_Integer := 0;
                  Iteration_Ok    : Boolean := True;
                  procedure Visit_Child
                    (Name : String;
                     Kind : FS.Listed_Kind;
                     Stop : in out Boolean);

                  procedure Visit_Child
                    (Name : String;
                     Kind : FS.Listed_Kind;
                     Stop : in out Boolean)
                  is
                     Child_Units : Long_Long_Integer := 0;
                  begin
                     Walk
                       (FS.Child_Path (Path, Name), Kind, False,
                        Child_Units, Ok);
                     Directory_Units := Directory_Units + Child_Units;
                     Stop := Context.Output_Failed;
                  end Visit_Child;

                  procedure Each is new FS.For_Each_Listed_Entry (Visit_Child);
               begin
                  if Already_Seen_Directory (Path, Listed_As) then
                     Total_Units := 0;
                     return;
                  end if;
                  --  A directory's own blocks are not counted: the host
                  --  adapter has a size only for a file, not a directory.
                  Directory_Units := 0;

                  Each (Path, Iteration_Ok);
                  if not Iteration_Ok then
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                     Ok := False;
                  end if;

                  Total_Units := Total_Units + Directory_Units;
                  if not Summary_Only or else Top_Level then
                     Print_Usage (Directory_Units, Path);
                  end if;
               end;
         end case;
      end Walk;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Value, Result);
      begin
         Valid := True;
         case Name is
            when 'a' => All_Entries := True;
            when 's' => Summary_Only := True;
            when others => Unit_Size := 1024;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "aks", "", First, Valid);
      if not Valid then
         return;
      end if;

      if First > Context.Argument_Count then
         declare
            Total : Long_Long_Integer := 0;
         begin
            Seen_Identities.Clear;
            Unidentified_Dirs.Clear;
            Walk (".", FS.Listed_Unknown, True, Total, All_Ok);
         end;
      else
         for I in First .. Context.Argument_Count loop
            declare
               Total : Long_Long_Integer := 0;
            begin
               Seen_Identities.Clear;
               Unidentified_Dirs.Clear;
               Walk
                 (Context.Argument (I), FS.Listed_Unknown,
                  True, Total, All_Ok);
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Result.Status :=
        (if Context.Output_Failed or else not All_Ok then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Du;
