with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Ln is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First    : Positive := 1;
      Force    : Boolean := False;
      Symbolic : Boolean := False;
      Verbose  : Boolean := False;

      procedure Create_Link
        (Source      : String;
         Target      : String;
         Ok          : in out Boolean;
         Created_One : out Boolean);

      procedure Create_Link
        (Source      : String;
         Target      : String;
         Ok          : in out Boolean;
         Created_One : out Boolean)
      is
         Created : Boolean;
      begin
         Created_One := False;
         if Force
           and then not Posix_Tools.Commands.File_Helpers.Remove_Non_Directory_Target (Target)
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         end if;

         Created :=
           (if Symbolic
            then FS.Create_Link (Source, Target)
            else FS.Create_Hard_Link (Source, Target));
         if not Created then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         else
            Created_One := True;
         end if;
      exception
         when others =>
            Created_One := False;
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Create_Link;

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
               when 'f' =>
                  Force := True;
               when 's' =>
                  Symbolic := True;
               when 'v' =>
                  Verbose := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First > Context.Argument_Count or else Context.Argument_Count - First + 1 < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Operand_Count : constant Natural := Context.Argument_Count - First + 1;
         Target        : constant String := Context.Argument (Context.Argument_Count);
         Target_Is_Dir : constant Boolean :=
           Posix_Tools.Commands.File_Helpers.Is_Directory (Target);
         Ok            : Boolean := True;
      begin
         if Operand_Count > 2 and then not Target_Is_Dir then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in First .. Context.Argument_Count - 1 loop
            declare
               Destination : constant String :=
                 Posix_Tools.Commands.File_Helpers.Target_Path
                   (Context.Argument (I), Target, Target_Is_Dir);
               Created_One : Boolean;
            begin
               Create_Link (Context.Argument (I), Destination, Ok, Created_One);
               if Verbose and then Created_One then
                  Context.Put_Line ("'" & Context.Argument (I) & "' -> '" & Destination & "'");
               end if;
            end;
         end loop;

         Result.Status :=
           (if Ok and then not Context.Output_Failed
            then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
      end;
   exception
      when others =>
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (Context.Argument_Count),
            "posix_tools.diagnostic.file.open_failed", "cannot open file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
   end Run;
end Posix_Tools.Commands.Ln;
