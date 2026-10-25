with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;

with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Ls is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);
   package String_Vector_Sorting is new String_Vectors.Generic_Sorting;

   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Hidden_Mode is (Hide_Hidden, Almost_All, All_Entries);

      Hidden            : Hidden_Mode := Hide_Hidden;
      Directory_As_File : Boolean := False;
      First             : Positive := 1;
      Ok                : Boolean := True;
      Emitted           : Boolean := False;

      procedure Emit_Line (Text : String);

      procedure List_Path (Path : String; With_Header : Boolean);

      procedure Emit_Line (Text : String) is
      begin
         Context.Put_Line (Text);
         Emitted := True;
      end Emit_Line;

      procedure List_Path (Path : String; With_Header : Boolean) is
         package Listing renames Posix_Tools.File_Operations.Listing;

         use type Listing.Read_Outcome;

         Names   : String_Vectors.Vector;
         Entries : Listing.Entry_Vectors.Vector;
         Outcome : Listing.Read_Outcome;
      begin
         if FS.Kind (Path) = FS.Directory and then not Directory_As_File then
            if With_Header then
               if Emitted then
                  Context.Put_Line ("");
               end if;
               Emit_Line (Path & ":");
            end if;
            Listing.Read_Directory
              (Path,
               (Include_Hidden => Hidden /= Hide_Hidden, With_Status => False),
               Entries,
               Outcome);
            if Outcome /= Listing.Read_Complete then
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
            for Item of Entries loop
               Names.Append (Ada.Strings.Unbounded.To_String (Item.Name));
            end loop;
            String_Vector_Sorting.Sort (Names);
            for Name of Names loop
               Emit_Line (Name);
            end loop;
         elsif FS.Exists (Path) or else FS.Is_Link (Path) then
            --  A link is listed as itself, the one to nothing too.
            Emit_Line (Path);
         else
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
      end List_Path;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when '1' =>
                        null;
                     when 'a' =>
                        Hidden := All_Entries;
                     when 'A' =>
                        if Hidden /= All_Entries then
                           Hidden := Almost_All;
                        end if;
                     when 'd' =>
                        Directory_As_File := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                        return;
                  end case;
               end loop;
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;

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
               begin
                  if not FS.Exists (Path) and then not FS.Is_Link (Path) then
                     List_Path (Path, False);
                  elsif FS.Kind (Path) = FS.Directory and then not Directory_As_File then
                     Directories.Append (Path);
                  else
                     Files.Append (Path);
                  end if;
               end;
            end loop;

            String_Vector_Sorting.Sort (Files);
            String_Vector_Sorting.Sort (Directories);

            for Path of Files loop
               List_Path (Path, False);
            end loop;

            for Path of Directories loop
               List_Path (Path, With_Header => Headers);
            end loop;
         end;
      end if;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Ls;
