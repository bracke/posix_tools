with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Help;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Localization;
with Posix_Tools.Presentation;
with Posix_Tools.Version;

package body Posix_Tools.Commands.Root is
   function Local_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Key     : String;
      Default : String) return String
   is
   begin
      return Posix_Tools.Localization.Text (Context.Effective_Locale, Key, Default);
   end Local_Text;

   function Root_Status
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return Posix_Tools.Exit_Status.Code
   is
   begin
      if Context.Output_Failed then
         return Posix_Tools.Exit_Status.Operational_Failure;
      else
         return Posix_Tools.Exit_Status.Success;
      end if;
   end Root_Status;

   function Status_Label
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Status  : String) return String
   is
   begin
      if Status = "missing" then
         return Local_Text (Context, "posix_tools.root.status.missing", Status);
      elsif Status = "not executable" then
         return Local_Text (Context, "posix_tools.root.status.not_executable", Status);
      elsif Status = "ok" then
         return Local_Text (Context, "posix_tools.root.status.ok", Status);
      elsif Status = "shadowed" then
         return Local_Text (Context, "posix_tools.root.status.shadowed", Status);
      elsif Status = "unverifiable" then
         return Local_Text (Context, "posix_tools.root.status.unverifiable", Status);
      elsif Status = "wrong project" then
         return Local_Text (Context, "posix_tools.root.status.wrong_project", Status);
      elsif Status = "wrong version" then
         return Local_Text (Context, "posix_tools.root.status.wrong_version", Status);
      else
         return Status;
      end if;
   end Status_Label;

   procedure Root_Help (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
      Usage : constant String :=
        Local_Text (Context, "posix_tools.root.usage", "Usage");
      Commands : constant String :=
        Local_Text (Context, "posix_tools.root.commands", "Commands");
   begin
      Context.Put_Line
        (Posix_Tools.Presentation.Header (Usage, Context.Standard_Output_Is_Terminal)
         & ": posix-tools <command> [operand]");
      Context.Put_Line
        (Posix_Tools.Presentation.Header (Commands, Context.Standard_Output_Is_Terminal)
         & ": "
         & Local_Text
           (Context,
            "posix_tools.root.command_list",
            "help, version, list, paths, verify"));
   end Root_Help;

   function Reject_Extra_Operands
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Maximum : Natural) return Boolean
   is
   begin
      if Context.Argument_Count > Maximum then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (Maximum + 1) & "'");
         return True;
      end if;

      return False;
   end Reject_Extra_Operands;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Root_Help (Context);
         Result.Status := Root_Status (Context);
      elsif Context.Argument (1) = "version" then
         if Reject_Extra_Operands (Context, Result, 1) then
            return;
         end if;
         Posix_Tools.Help.Render_Version (Context, Posix_Tools.Version.Project_Name);
         Result.Status := Root_Status (Context);
      elsif Context.Argument (1) = "list" then
         if Reject_Extra_Operands (Context, Result, 1) then
            return;
         end if;
         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Context.Put_Line (Posix_Tools.Command_Inventory.Executable (I));
            exit when Context.Output_Failed;
         end loop;
         Result.Status := Root_Status (Context);
      elsif Context.Argument (1) = "paths" then
         if Reject_Extra_Operands (Context, Result, 1) then
            return;
         end if;
         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
               Located    : constant String := Posix_Tools.Host_Adapters.Executables.Locate (Executable);
            begin
               Context.Put_Line
                 (Executable & ": "
                  & (if Located = "" then Status_Label (Context, "missing") else Located));
               exit when Context.Output_Failed;
            end;
         end loop;
         Result.Status := Root_Status (Context);
      elsif Context.Argument (1) = "verify" then
         if Reject_Extra_Operands (Context, Result, 1) then
            return;
         end if;
         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
            begin
               Context.Put_Line
                 (Executable & ": "
                  & Status_Label
                    (Context,
                     Posix_Tools.Host_Adapters.Executables.Verify_Identity (Executable)));
               exit when Context.Output_Failed;
            end;
         end loop;
         Result.Status := Root_Status (Context);
      elsif Context.Argument (1) = "help" then
         if Reject_Extra_Operands (Context, Result, 2) then
            return;
         end if;
         if Context.Argument_Count = 1 then
            Root_Help (Context);
         elsif not Posix_Tools.Command_Inventory.Contains_Executable (Context.Argument (2)) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "unknown command '" & Context.Argument (2) & "'");
            return;
         else
            Posix_Tools.Help.Render_Command_Help (Context, Context.Argument (2));
         end if;
         Result.Status := Root_Status (Context);
      else
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "unknown subcommand '" & Context.Argument (1) & "'");
      end if;
   end Run;
end Posix_Tools.Commands.Root;
