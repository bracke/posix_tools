with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Mv is
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Operands : String_Vectors.Vector;
      Ok       : Boolean := True;
      Verbose  : Boolean := False;
      Force    : Boolean := False;
      Interactive : Boolean := False;
      Parsing_Operands : Boolean := False;

      function Confirm_Overwrite (Path : String) return Boolean is
      begin
         if not Interactive or else Force or else not FS.Exists (Path) then
            return True;
         end if;

         Context.Put_Error_Line ("mv: overwrite '" & Path & "'?");
         return Posix_Tools.Commands.Helpers.Read_Affirmative_Response (Context);
      end Confirm_Overwrite;

      procedure Copy_Then_Remove (Source, Destination : String; Moved : out Boolean) is
         Copied : Boolean;
      begin
         Moved := False;
         Posix_Tools.Commands.File_Helpers.Copy_Path
           (Context, Source, Destination, True, True, False, Copied);
         if not Copied then
            return;
         end if;

         begin
            if FS.Kind (Source) = FS.Directory
            then
               FS.Delete_Tree (Source);
            else
               FS.Delete_File (Source);
            end if;
            Moved := True;
         exception
            when others =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end Copy_Then_Remove;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Operands.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'f' =>
                        Force := True;
                        Interactive := False;
                     when 'i' =>
                        Force := False;
                        Interactive := True;
                     when 'v' =>
                        Verbose := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Operands.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Operands.Length < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Count  : constant Natural := Natural (Operands.Length);
         Target : constant String := Operands.Element (Count);
      begin
         if Count > 2
           and then FS.Kind (Target) /= FS.Directory
         then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in 1 .. Count - 1 loop
            declare
               Destination : constant String :=
                 (if Count = 2
                  then Target
                  else Posix_Tools.Commands.File_Helpers.Join_Path
                    (Target,
                     Posix_Tools.Commands.File_Helpers.Simple_Name (Operands.Element (I))));
               Overwrite_Accepted : constant Boolean := Confirm_Overwrite (Destination);
            begin
               if Overwrite_Accepted then
                  FS.Rename (Operands.Element (I), Destination);
                  if Verbose then
                     Context.Put_Line ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                  end if;
               end if;
            exception
               when others =>
                  declare
                     Moved : Boolean;
                  begin
                     if not Overwrite_Accepted then
                        Moved := True;
                     else
                        Copy_Then_Remove (Operands.Element (I), Destination, Moved);
                     end if;

                     if not Moved then
                        Ok := False;
                        Posix_Tools.Commands.Helpers.Subject_Operational_Error
                          (Context,
                           Operands.Element (I),
                           "posix_tools.diagnostic.file.open_failed",
                           "cannot open file");
                     elsif Verbose then
                        Context.Put_Line ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                     end if;
                  end;
            end;
         end loop;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

end Posix_Tools.Commands.Mv;
