with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Operation_Reports;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Mv is
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.File_Operations.Operation_Outcome;
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

      function Confirm_Overwrite (Path : String) return Boolean;

      function Confirm_Overwrite (Path : String) return Boolean is
      begin
         if not Interactive or else Force or else not (FS.Exists (Path) or else FS.Is_Link (Path)) then
            return True;
         end if;

         return Posix_Tools.Commands.Operation_Reports.Ask
           (Context, "posix_tools.mv.overwrite.prompt", "mv: overwrite '{path}'?", Path);
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
         --  A directory as the last operand is where the others go, two
         --  operands or more, as POSIX has it.
         Into_Directory : constant Boolean := FS.Kind (Target) = FS.Directory;
      begin
         if Count > 2
           and then not Into_Directory
         then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in 1 .. Count - 1 loop
            declare
               Destination : constant String :=
                 (if not Into_Directory
                  then Target
                  else FS.Child_Path
                    (Target,
                     Posix_Tools.Commands.File_Helpers.Simple_Name (Operands.Element (I))));
               --  Each entry that could not be moved is reported for itself,
               --  with why.
               Reports : Posix_Tools.Commands.Operation_Reports.Context_Observer (Context'Access);
               Moved   : Posix_Tools.File_Operations.Operation_Outcome;
            begin
               if Confirm_Overwrite (Destination) then
                  Posix_Tools.File_Operations.Moving.Move_Path (Operands.Element (I), Destination, Reports, Moved);

                  if not Posix_Tools.File_Operations.Succeeded (Moved) then
                     Ok := False;
                  elsif Verbose and then Moved = Posix_Tools.File_Operations.Done then
                     Context.Put_Line ("'" & Operands.Element (I) & "' -> '" & Destination & "'");
                  end if;
               end if;
            end;
         end loop;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

end Posix_Tools.Commands.Mv;
