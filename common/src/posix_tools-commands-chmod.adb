with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.File_Modes;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Chmod is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Mode_Helpers renames Posix_Tools.Commands.Text_Helpers.File_Modes;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First            : Positive := 1;
      Recursive        : Boolean := False;
      Mode_Selection   : Mode_Helpers.Mode_Selection;
      Ok               : Boolean := True;

      procedure Apply_One (Path : String);
      function Parse_Mode (Text : String) return Boolean;
      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural;

      procedure Apply_Children is new Posix_Tools.Commands.Helpers.For_Each_Directory_Child
        (Action => Apply_One);

      procedure Apply_One (Path : String) is
         Desired_Mode : Natural;
         Mode_Ok      : Boolean;
      begin
         if Recursive then
            declare
               Listed : Boolean;
            begin
               Apply_Children (Path, Listed);
               Ok := Ok and Listed;
            end;
         end if;
         Desired_Mode := Selected_Mode_For (Path, Mode_Ok);
         if not Mode_Ok or else not FS.Set_Permissions (Path, Desired_Mode) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;

      function Parse_Mode (Text : String) return Boolean is
         Accepted : Boolean;
      begin
         Mode_Helpers.Parse (Text, Mode_Selection, Accepted);
         return Accepted;
      end Parse_Mode;

      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural is
         Available : Boolean := False;
         Base      : Natural := 0;
         Selected  : Mode_Helpers.Selected_Mode;
      begin
         if not Mode_Helpers.Is_Symbolic (Mode_Selection) then
            Selected := Mode_Helpers.Selected (Mode_Selection, 0, 8#10000#);
            Valid := True;
            return Selected.Mode;
         end if;

         Base := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
         if not Available then
            Valid := False;
            return 0;
         end if;
         Selected := Mode_Helpers.Selected (Mode_Selection, Base, 8#10000#);
         Valid := Selected.Valid;
         return Selected.Mode;
      end Selected_Mode_For;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif not Parse_Mode (Context.Argument (First)) then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Chmod;
