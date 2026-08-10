with Posix_Tools.Exit_Status;
with Posix_Tools.Help;
with Posix_Tools.Localization;

package body Posix_Tools.Commands.Helpers is
   function Localized_Usage_Message
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Message : String) return String
   is
      Prefix : constant String := "extra operand '";
      Missing_Option_Prefix : constant String := "missing option argument '";
      Invalid_Operand_Prefix : constant String := "invalid operand '";
      Unknown_Option_Prefix : constant String := "unknown option '";
      Unknown_Command_Prefix : constant String := "unknown command '";
      Unknown_Subcommand_Prefix : constant String := "unknown subcommand '";
      Invalid_Line_Count_Prefix : constant String := "invalid line count '";
      Invalid_Count_Prefix : constant String := "invalid count '";
   begin
      if Message = "missing operand" then
         return Posix_Tools.Localization.Text
           (Context.Effective_Locale,
            "posix_tools.diagnostic.missing_operand",
            Message);
      elsif Message'Length > Missing_Option_Prefix'Length
        and then Message (Message'First .. Message'First + Missing_Option_Prefix'Length - 1)
          = Missing_Option_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.missing_option_argument",
            "option",
            Message (Message'First + Missing_Option_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Prefix'Length
        and then Message (Message'First .. Message'First + Prefix'Length - 1) = Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.extra_operand",
            "operand",
            Message (Message'First + Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Invalid_Operand_Prefix'Length
        and then Message (Message'First .. Message'First + Invalid_Operand_Prefix'Length - 1)
          = Invalid_Operand_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.operand.invalid",
            "operand",
            Message (Message'First + Invalid_Operand_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Unknown_Option_Prefix'Length
        and then Message (Message'First .. Message'First + Unknown_Option_Prefix'Length - 1)
          = Unknown_Option_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.option.unknown",
            "option",
            Message (Message'First + Unknown_Option_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Unknown_Command_Prefix'Length
        and then Message (Message'First .. Message'First + Unknown_Command_Prefix'Length - 1)
          = Unknown_Command_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.command.unknown",
            "command",
            Message (Message'First + Unknown_Command_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Unknown_Subcommand_Prefix'Length
        and then Message (Message'First .. Message'First + Unknown_Subcommand_Prefix'Length - 1)
          = Unknown_Subcommand_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.subcommand.unknown",
            "subcommand",
            Message (Message'First + Unknown_Subcommand_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Invalid_Line_Count_Prefix'Length
        and then Message (Message'First .. Message'First + Invalid_Line_Count_Prefix'Length - 1)
          = Invalid_Line_Count_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.line_count.invalid",
            "count",
            Message (Message'First + Invalid_Line_Count_Prefix'Length .. Message'Last - 1),
            Message);
      elsif Message'Length > Invalid_Count_Prefix'Length
        and then Message (Message'First .. Message'First + Invalid_Count_Prefix'Length - 1)
          = Invalid_Count_Prefix
        and then Message (Message'Last) = '''
      then
         return Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.diagnostic.count.invalid",
            "count",
            Message (Message'First + Invalid_Count_Prefix'Length .. Message'Last - 1),
            Message);
      else
         return Message;
      end if;
   end Localized_Usage_Message;

   function Intercept_Extension
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Conventional : Boolean := True) return Boolean
   is
      Count : constant Natural := Context.Argument_Count;
   begin
      if Count = 0 then
         return False;
      end if;

      if Conventional or else Count = 1 then
         if Context.Argument (1) = "--help" then
            Posix_Tools.Help.Render_Command_Help (Context, Context.Command_Name);
            Result.Status := Posix_Tools.Exit_Status.Success;
            return True;
         elsif Context.Argument (1) = "--version" then
            Posix_Tools.Help.Render_Version (Context, Context.Command_Name);
            Result.Status := Posix_Tools.Exit_Status.Success;
            return True;
         elsif Context.Argument (1) = "--posix-tools-identify" and then Count = 1 then
            Posix_Tools.Help.Render_Identity (Context, Context.Command_Name);
            Result.Status := Posix_Tools.Exit_Status.Success;
            return True;
         end if;
      end if;

      return False;
   end Intercept_Extension;

   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : String)
   is
   begin
      Context.Put_Error_Line (Context.Command_Name & ": " & Localized_Usage_Message (Context, Message));
      Result.Status := Posix_Tools.Exit_Status.Invalid_Usage;
   end Usage_Error;

   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Default     : String)
   is
   begin
      Context.Put_Error_Line
        (Context.Command_Name & ": "
         & Posix_Tools.Localization.Text (Context.Effective_Locale, Message_Key, Default));
   end Operational_Error;

   procedure Subject_Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Subject     : String;
      Message_Key : String;
      Default     : String)
   is
   begin
      Context.Put_Error_Line
        (Context.Command_Name & ": '" & Subject & "': "
         & Posix_Tools.Localization.Text (Context.Effective_Locale, Message_Key, Default));
   end Subject_Operational_Error;
end Posix_Tools.Commands.Helpers;
