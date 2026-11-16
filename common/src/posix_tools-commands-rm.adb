with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Operation_Reports;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Localization;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Rm is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.Entry_Kind;
   use type Posix_Tools.File_Operations.Operation_Outcome;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Recursive   : Boolean := False;
      Force       : Boolean := False;
      Interactive : Boolean := False;
      Directory   : Boolean := False;
      Verbose     : Boolean := False;
      First       : Positive;
      Valid       : Boolean;
      Ok          : Boolean := True;
      Output      : Posix_Tools.Commands.Helpers.Output_Buffer;

      --  Whether Path is to be left alone before anything is done to it, and
      --  said so: POSIX rm refuses an operand whose last component is . or
      --  .., and one that is the root directory.
      function Refused (Path : String; Kind : FS.Entry_Kind) return Boolean;

      --  Remove the operand Path, writing a diagnostic for each entry that
      --  could not go.
      procedure Remove (Path : String);

      function Refused (Path : String; Kind : FS.Entry_Kind) return Boolean is
         Last_Component : constant String := Posix_Tools.Paths.Basename (Path);
      begin
         if Last_Component in "." | ".." then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.rm.dot_operand", "refusing to remove '.' or '..'");
            return True;
         elsif Posix_Tools.Paths.Is_All_Slashes (Path)
           or else
             (Kind not in FS.Entry_Missing | FS.Entry_Link
              and then FS.Real_Path (Path) = "/")
         then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.rm.root_operand", "refusing to remove the root directory");
            return True;
         end if;

         return False;
      end Refused;

      procedure Remove (Path : String) is
         Kind    : constant FS.Entry_Kind := FS.Entry_Kind_Of (Path);
         Reports : Posix_Tools.Commands.Operation_Reports.Context_Observer (Context'Access);
         Removed : Posix_Tools.File_Operations.Operation_Outcome;
      begin
         --  -f is quiet only about what is not there to remove.
         if Force and then Kind = FS.Entry_Missing then
            return;
         elsif Refused (Path, Kind) then
            Ok := False;
            return;
         end if;

         if Interactive then
            Reports.Prompt := Posix_Tools.Commands.Operation_Reports.Removal;
         end if;

         Posix_Tools.File_Operations.Removing.Remove_Path
           (Path, (Recursive => Recursive, Empty_Directories => Directory), Reports, Removed);

         if not Posix_Tools.File_Operations.Succeeded (Removed) then
            Ok := False;
         elsif Verbose and then Removed = Posix_Tools.File_Operations.Done then
            Posix_Tools.Commands.Helpers.Buffered_Put_Line
              (Output, Context,
               Posix_Tools.Localization.Text_1
                 (Context.Effective_Locale,
                  "posix_tools.rm.removed",
                  "path",
                  Posix_Tools.Commands.Helpers.Escape_Untrusted (Path),
                  "removed '" & Posix_Tools.Commands.Helpers.Escape_Untrusted (Path) & "'"));
         end if;
      end Remove;

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
            when 'r' | 'R' =>
               Recursive := True;
            when 'f' =>
               Force := True;
               Interactive := False;
            when 'i' =>
               Force := False;
               Interactive := True;
            when 'd' =>
               Directory := True;
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

      Parse (Context, Result, "dfiRrv", "", First, Valid);
      if not Valid then
         return;
      end if;

      if First > Context.Argument_Count and then not Force then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         Remove (Context.Argument (I));
      end loop;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Rm;
