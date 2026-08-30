with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Localization;

package body Posix_Tools.Commands.Cp is
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
      Recursive : Boolean := False;
      Preserve_Mode : Boolean := False;
      Preserve_Links : Boolean := False;
      Verbose : Boolean := False;
      Force : Boolean := False;
      Interactive : Boolean := False;
      Ok       : Boolean := True;
      Parsing_Operands : Boolean := False;

      function Confirm_Overwrite (Path : String) return Boolean is
      begin
         if not Interactive or else Force or else not FS.Exists (Path) then
            return True;
         end if;

         Context.Put_Error_Line
           (Posix_Tools.Localization.Text_1
              (Context.Effective_Locale,
               "posix_tools.cp.overwrite.prompt",
               "path",
               Posix_Tools.Commands.Helpers.Escape_Untrusted (Path),
               "cp: overwrite '" & Posix_Tools.Commands.Helpers.Escape_Untrusted (Path) & "'?"));
         return Posix_Tools.Commands.Helpers.Read_Affirmative_Response (Context);
      end Confirm_Overwrite;
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
                     when 'L' | 'H' =>
                        Preserve_Links := False;
                     when 'P' =>
                        Preserve_Links := True;
                     when 'p' => Preserve_Mode := True;
                     when 'R' | 'r' => Recursive := True;
                     when 'v' => Verbose := True;
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
         if Count = 2 then
            declare
               Destination : constant String :=
                 (if FS.Kind (Target) = FS.Directory
                  then Posix_Tools.Commands.File_Helpers.Join_Path
                    (Target,
                     Posix_Tools.Commands.File_Helpers.Simple_Name (Operands.Element (1)))
                  else Target);
               Confirmed : constant Boolean := Confirm_Overwrite (Destination);
            begin
               if Confirmed then
                  Posix_Tools.Commands.File_Helpers.Copy_Path
                    (Context, Operands.Element (1), Destination, Recursive, Preserve_Mode, Preserve_Links, Ok);
               else
                  Ok := True;
               end if;

               if Verbose and then Ok and then Confirmed then
                  Context.Put_Line ("'" & Operands.Element (1) & "' -> '" & Destination & "'");
               end if;
            end;
         elsif FS.Kind (Target) = FS.Directory
         then
            for I in 1 .. Count - 1 loop
               declare
                  One_Ok : Boolean;
                  Destination : constant String :=
                    Posix_Tools.Commands.File_Helpers.Join_Path
                      (Target,
                       Posix_Tools.Commands.File_Helpers.Simple_Name (Operands.Element (I)));
                  Confirmed : constant Boolean := Confirm_Overwrite (Destination);
               begin
                  if Confirmed then
                     Posix_Tools.Commands.File_Helpers.Copy_Path
                       (Context,
                        Operands.Element (I),
                        Destination,
                        Recursive,
                        Preserve_Mode,
                        Preserve_Links,
                        One_Ok);
                  else
                     One_Ok := True;
                  end if;

                  if Verbose and then One_Ok and then Confirmed then
                     Context.Put_Line
                       ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                  end if;
                  Ok := Ok and One_Ok;
               end;
            end loop;
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         end if;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

end Posix_Tools.Commands.Cp;
