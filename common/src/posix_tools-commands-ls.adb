with Ada.Containers.Indefinite_Vectors;

with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Ls is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);
   package String_Vector_Sorting is new String_Vectors.Generic_Sorting;

   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Entry_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Hidden_Mode is (Hide_Hidden, Almost_All, All_Entries);
      type Path_Knowledge is
        (Unknown_Path, Missing_Path, Existing_Nondirectory, Existing_Directory);

      Hidden            : Hidden_Mode := Hide_Hidden;
      Directory_As_File : Boolean := False;
      First             : Positive;
      Valid             : Boolean;
      Ok                : Boolean := True;
      Emitted           : Boolean := False;
      Output            : Posix_Tools.Commands.Helpers.Output_Buffer;

      procedure Emit_Line (Text : String);

      procedure List_Path
        (Path        : String;
         With_Header : Boolean;
         Known       : Path_Knowledge := Unknown_Path);

      procedure Emit_Line (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Buffered_Put_Line (Output, Context, Text);
         Emitted := True;
      end Emit_Line;

      procedure List_Path
        (Path        : String;
         With_Header : Boolean;
         Known       : Path_Knowledge := Unknown_Path)
      is
         Names        : String_Vectors.Vector;
         Iteration_Ok : Boolean;
         Kind         : constant FS.File_Kind :=
           (if Known = Existing_Directory then FS.Directory
            elsif Known = Existing_Nondirectory then FS.Ordinary_File
            elsif Known = Missing_Path then FS.Missing_File
            else FS.Kind (Path));

         procedure Add_Name
           (Name : String;
            Kind : FS.Listed_Kind;
            Stop : in out Boolean);

         procedure Add_Name
           (Name : String;
            Kind : FS.Listed_Kind;
            Stop : in out Boolean)
         is
            pragma Unreferenced (Kind, Stop);
            Is_Hidden : constant Boolean :=
              Name'Length > 0 and then Name (Name'First) = '.';
         begin
            if Hidden /= Hide_Hidden or else not Is_Hidden then
               Names.Append (Name);
            end if;
         end Add_Name;

         procedure Read_Names is new FS.For_Each_Listed_Entry (Add_Name);
      begin
         if Kind = FS.Directory and then not Directory_As_File then
            if With_Header then
               if Emitted then
                  Emit_Line ("");
               end if;
               Emit_Line (Path & ":");
            end if;
            Read_Names (Path, Iteration_Ok);
            if not Iteration_Ok then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
               return;
            end if;
            --  The listing leaves out the directory's own two entries, and
            --  hidden ones unless asked for them.
            if Hidden = All_Entries then
               Names.Append (".");
               Names.Append ("..");
            end if;
            String_Vector_Sorting.Sort (Names);
            for Name of Names loop
               Emit_Line (Name);
               exit when Context.Output_Failed;
            end loop;
         elsif Known = Existing_Nondirectory
           or else
             (Known = Unknown_Path
              and then (Kind /= FS.Missing_File or else FS.Is_Link (Path)))
         then
            --  A link is listed as itself, the one to nothing too.
            Emit_Line (Path);
         else
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
      end List_Path;

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
            when 'a' => Hidden := All_Entries;
            when 'A' =>
               if Hidden /= All_Entries then
                  Hidden := Almost_All;
               end if;
            when '1' => null;  --  one entry a line, as always
            when others => Directory_As_File := True;  --  -d
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "1aAd", "", First, Valid);
      if not Valid then
         return;
      end if;

      if Context.Argument_Count < First then
         List_Path (".", False);
      else
         --  POSIX: the operands that are not directories first, then the
         --  directories, each sorted; what is not there is reported first.
         declare
            Files       : String_Vectors.Vector;
            Directories : String_Vectors.Vector;
            Headers     : constant Boolean := Context.Argument_Count - First + 1 > 1;
         begin
            for I in First .. Context.Argument_Count loop
               declare
                  Path : constant String := Context.Argument (I);
                  Entry_Type : constant FS.Entry_Kind := FS.Entry_Kind_Of (Path);
                  Kind       : constant FS.File_Kind :=
                    (case Entry_Type is
                       when FS.Entry_Missing   => FS.Missing_File,
                       when FS.Entry_Error     => FS.Missing_File,
                       when FS.Entry_Directory => FS.Directory,
                       when FS.Entry_Regular   => FS.Ordinary_File,
                       when FS.Entry_Special   => FS.Special_File,
                       when FS.Entry_Link      =>
                         (if Directory_As_File
                          then FS.Ordinary_File
                          else FS.Kind (Path)));
               begin
                  if Entry_Type = FS.Entry_Error then
                     Ok := False;
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Path,
                        "posix_tools.diagnostic.file.read_failed", "cannot read file");
                  elsif Kind = FS.Missing_File and then Entry_Type /= FS.Entry_Link then
                     List_Path (Path, False, Missing_Path);
                  elsif Kind = FS.Directory and then not Directory_As_File then
                     Directories.Append (Path);
                  else
                     Files.Append (Path);
                  end if;
               end;
            end loop;

            String_Vector_Sorting.Sort (Files);
            String_Vector_Sorting.Sort (Directories);

            for Path of Files loop
               List_Path (Path, False, Existing_Nondirectory);
            end loop;

            for Path of Directories loop
               List_Path (Path, With_Header => Headers, Known => Existing_Directory);
            end loop;
         end;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Ls;
