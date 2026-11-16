with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.File_Modes;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;

package body Posix_Tools.Commands.Chmod is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Mode_Helpers renames Posix_Tools.Commands.Text_Helpers.File_Modes;
   package Modes renames Posix_Tools.Text.File_Modes;

   use type FS.File_Kind;
   use type FS.Entry_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First            : Positive := 1;
      Recursive        : Boolean := False;
      Mode_Selection   : Mode_Helpers.Mode_Selection;
      Creation_Mask    : Natural := 0;
      Ok               : Boolean := True;
      Root_Operand     : Ada.Strings.Unbounded.Unbounded_String;

      procedure Apply_One (Path : String);
      function Parse_Mode (Text : String) return Boolean;
      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural;

      procedure Apply_Children is new Posix_Tools.Commands.Helpers.For_Each_Directory_Child
        (Action => Apply_One);

      procedure Apply_One (Path : String) is
         Desired_Mode : Natural;
         Mode_Ok      : Boolean;
      begin
         if Recursive and then FS.Entry_Kind_Of (Path) = FS.Entry_Link then
            return;
         end if;

         if Recursive then
            declare
               Listed : Boolean;
            begin
               Apply_Children (Path, Listed);
               Ok := Ok and Listed;
            end;
         end if;
         if not FS.Exists (Path) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.missing", "no such file or directory");
            return;
         end if;

         Desired_Mode := Selected_Mode_For (Path, Mode_Ok);
         if not Mode_Ok
           or else not
             (if Recursive
              then FS.Set_Permissions_No_Follow
                (Path,
                 Desired_Mode,
                 Ada.Strings.Unbounded.To_String (Root_Operand),
                 Posix_Tools.Commands.Helpers.Relative_Beneath
                   (Ada.Strings.Unbounded.To_String (Root_Operand), Path))
              else FS.Set_Permissions (Path, Desired_Mode))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.mode_failed", "cannot change permissions");
         end if;
      exception
         when others =>
            --  intentional terminal exception barrier
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.mode_failed", "cannot change permissions");
      end Apply_One;

      function Parse_Mode (Text : String) return Boolean is
         Accepted : Boolean;
      begin
         Mode_Helpers.Parse (Text, Mode_Selection, Accepted);
         return Accepted;
      end Parse_Mode;

      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural is
         Available    : Boolean := False;
         Base         : Natural := 0;
         Is_Directory : Boolean;
         Selected     : Mode_Helpers.Selected_Mode;
      begin
         if not Mode_Helpers.Is_Symbolic (Mode_Selection) then
            Selected := Mode_Helpers.Selected (Mode_Selection, 0, 8#10000#);
            Valid := True;
            return Selected.Mode;
         end if;

         declare
            Status    : constant FS.Entry_Status := FS.File_Status_Of (Path);
            Type_Code : constant Modes.File_Type_Code :=
              (if Status.Available then Modes.File_Type (Status.Mode) else 0);
         begin
            if Status.Available then
               Base := Status.Mode mod 8#10000#;
               Is_Directory :=
                 (if Type_Code = 0 then FS.Kind (Path) = FS.Directory
                  else Type_Code = Modes.Type_Directory);
            else
               --  Hosts without a combined status query keep the portable
               --  probes used before this fast path.
               Base := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
               if not Available then
                  Valid := False;
                  return 0;
               end if;
               Is_Directory := FS.Kind (Path) = FS.Directory;
            end if;
         end;
         Selected :=
           Mode_Helpers.Selected
             (Mode_Selection, Base, 8#10000#, Is_Directory, Umask => Creation_Mask);
         Valid := Selected.Valid;
         return Selected.Mode;
      end Selected_Mode_For;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      --  Not Helpers.Parse_Options: a mode such as "-w" looks like an
      --  option, so only "-R", repeated or grouped, is taken as one.
      while First <= Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (First);
         begin
            if Argument = "--" then
               First := First + 1;
               exit;
            elsif Argument'Length > 1
              and then Argument (Argument'First) = '-'
              and then (for all C of Argument (Argument'First + 1 .. Argument'Last) => C = 'R')
            then
               Recursive := True;
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      elsif not Parse_Mode (Context.Argument (First)) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Context.Argument (First));
         return;
      end if;

      if Mode_Helpers.Is_Symbolic (Mode_Selection) then
         --  The command does not change its process-wide creation mask, so
         --  recursive operation needs to query it only once.
         Creation_Mask := FS.Creation_Mask;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Root_Operand := Ada.Strings.Unbounded.To_Unbounded_String
           (Context.Argument (I));
         Apply_One (Context.Argument (I));
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Chmod;
