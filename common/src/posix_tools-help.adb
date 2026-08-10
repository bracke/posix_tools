with Posix_Tools.Localization;
with Posix_Tools.Presentation;
with Posix_Tools.Version;

package body Posix_Tools.Help is
   procedure Render_Command_Help
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String)
   is
      Locale  : constant String := Context.Effective_Locale;
      Usage   : constant String :=
        Posix_Tools.Localization.Text (Locale, "posix_tools.help.usage", "Usage");
      Summary : constant String :=
        Posix_Tools.Localization.Text
          (Locale, "posix_tools.help.summary", "Ada implementation in the posix-tools package.");
      Options : constant String :=
        Posix_Tools.Localization.Text (Locale, "posix_tools.help.options", "Options");
      Help_Option : constant String :=
        Posix_Tools.Localization.Text
          (Locale, "posix_tools.common.option.help", "display this help and exit");
      Version_Option : constant String :=
        Posix_Tools.Localization.Text
          (Locale, "posix_tools.common.option.version", "display version information and exit");
      Usage_Heading : constant String :=
        Posix_Tools.Presentation.Header (Usage, Context.Standard_Output_Is_Terminal);
      Options_Heading : constant String :=
        Posix_Tools.Presentation.Header (Options, Context.Standard_Output_Is_Terminal);
   begin
      Context.Put
        (Usage_Heading & ": " & Command & " [OPTION]... [OPERAND]..." & Character'Val (10)
         & Summary & Character'Val (10)
         & Options_Heading & ":" & Character'Val (10)
         & "  --help     " & Help_Option & Character'Val (10)
         & "  --version  " & Version_Option & Character'Val (10));
   end Render_Command_Help;

   procedure Render_Version
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String)
   is
   begin
      if Command = Posix_Tools.Version.Project_Name then
         Context.Put (Command & " " & Posix_Tools.Version.Version_String & Character'Val (10));
      else
         Context.Put
           (Command & " (posix-tools) " & Posix_Tools.Version.Version_String & Character'Val (10));
      end if;
   end Render_Version;

   procedure Render_Identity
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String)
   is
   begin
      Context.Put
        ("schema=1" & Character'Val (10)
         & "project=posix-tools" & Character'Val (10)
         & "command=" & Command & Character'Val (10)
         & "version=" & Posix_Tools.Version.Version_String & Character'Val (10));
   end Render_Identity;
end Posix_Tools.Help;
