with Posix_Tools.Commands.Contexts;

package Posix_Tools.Help is
   procedure Render_Command_Help
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String);

   procedure Render_Version
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String);

   procedure Render_Identity
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Command : String);
end Posix_Tools.Help;
