with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Rm is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Recursive   : Boolean := False;
      Force       : Boolean := False;
      Interactive : Boolean := False;
      Directory   : Boolean := False;
      Verbose     : Boolean := False;
      First       : Positive := 1;
      Ok          : Boolean := True;

      function Confirm_Removal (Path : String) return Boolean;

      function Confirm_Removal (Path : String) return Boolean is
      begin
         if not Interactive then
            return True;
         end if;

         Context.Put_Error_Line ("rm: remove '" & Path & "'?");
         return Posix_Tools.Commands.Helpers.Read_Affirmative_Response (Context);
      end Confirm_Removal;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;
         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
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
               when 'v' =>
                  Verbose := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;

      if First > Context.Argument_Count and then not Force then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         begin
            if Confirm_Removal (Context.Argument (I)) then
               if Recursive and then FS.Kind (Context.Argument (I)) = FS.Directory then
                  FS.Delete_Tree (Context.Argument (I));
               elsif Directory and then FS.Kind (Context.Argument (I)) = FS.Directory then
                  FS.Delete_Directory (Context.Argument (I));
               else
                  FS.Delete_File (Context.Argument (I));
               end if;
               if Verbose then
                  Context.Put_Line ("removed '" & Context.Argument (I) & "'");
               end if;
            end if;
         exception
            when others =>
               if not Force then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     Context.Argument (I),
                     "posix_tools.diagnostic.file.open_failed",
                     "cannot open file");
               end if;
         end;
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Rm;
