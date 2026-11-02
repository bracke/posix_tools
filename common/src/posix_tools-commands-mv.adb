with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Operation_Reports;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Mv is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
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
      First    : Positive;
      Valid    : Boolean;

      function Confirm_Overwrite (Path : String) return Boolean;

      function Confirm_Overwrite (Path : String) return Boolean is
      begin
         if not Interactive or else Force or else not (FS.Exists (Path) or else FS.Is_Link (Path)) then
            return True;
         end if;

         return Posix_Tools.Commands.Operation_Reports.Ask
           (Context, "posix_tools.mv.overwrite.prompt", "mv: overwrite '{path}'?", Path);
      end Confirm_Overwrite;

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
         case Name is
            when 'f' =>
               Force := True;
               Interactive := False;
            when 'i' =>
               Force := False;
               Interactive := True;
            when others =>
               --  -v
               Verbose := True;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "fiv", "", First, Valid);
      if not Valid then
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         Operands.Append (Context.Argument (I));
      end loop;

      if Operands.Length < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
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
                     Posix_Tools.Paths.Basename (Operands.Element (I))));
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
                     Context.Put_Line
                       ("'" & Posix_Tools.Commands.Helpers.Escape_Untrusted (Operands.Element (I)) & "' -> '"
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Destination) & "'");
                  end if;
               end if;
            end;
         end loop;
      end;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;

end Posix_Tools.Commands.Mv;
