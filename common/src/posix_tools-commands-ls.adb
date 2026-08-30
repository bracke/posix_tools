with Ada.Containers.Indefinite_Vectors;

with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Ls is
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

      function Visible (Name : String) return Boolean;

      procedure Emit_Line (Text : String) is
      begin
         Context.Put_Line (Text);
         Emitted := True;
      end Emit_Line;

      procedure List_Path (Path : String; With_Header : Boolean) is
         Names  : String_Vectors.Vector;
         Listed : Boolean := True;

         procedure Add_Entry (Name : String; Full_Name : String; Stop : in out Boolean);

         procedure Add_Entry (Name : String; Full_Name : String; Stop : in out Boolean) is
            pragma Unreferenced (Full_Name, Stop);
         begin
            if Visible (Name) then
               Names.Append (Name);
            end if;
         end Add_Entry;

         procedure Each is new FS.For_Each_Directory_Entry (Add_Entry);
      begin
         if FS.Kind (Path) = FS.Directory and then not Directory_As_File then
            if With_Header then
               if Emitted then
                  Context.Put_Line ("");
               end if;
               Emit_Line (Path & ":");
            end if;
            Each (Path, Listed);
            if not Listed then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
               return;
            end if;
            String_Vector_Sorting.Sort (Names);
            for Name of Names loop
               Emit_Line (Name);
            end loop;
         elsif FS.Exists (Path) then
            Emit_Line (Path);
         else
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
      end List_Path;

      function Visible (Name : String) return Boolean is
      begin
         case Hidden is
            when All_Entries =>
               return True;
            when Almost_All =>
               return Name /= "." and then Name /= "..";
            when Hide_Hidden =>
               return Name = "" or else Name (Name'First) /= '.';
         end case;
      end Visible;
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
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Ch & "'");
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
         for I in First .. Context.Argument_Count loop
            List_Path
              (Context.Argument (I),
               With_Header =>
                 Context.Argument_Count - First + 1 > 1
                 and then FS.Kind (Context.Argument (I)) = FS.Directory
                 and then not Directory_As_File);
         end loop;
      end if;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Ls;
