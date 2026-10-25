with Posix_Tools.Commands.Results;
with Test_Contexts;

--  Runs a command as its executable does: through the Run_Entry its wrapper
--  instantiates via Host_Adapters.Run_Command, bound to the package the
--  command inventory names. Help, version, and identity requests therefore
--  reach Helpers.Intercept_Extension inside the command's own Run, as in
--  production. awk, grep, sed, and explore do not run through a context
--  (or are not linked here); for them only the shared help, version, and
--  identity rendering is reachable.
package Command_Tests.Dispatch is
   procedure Run
     (Name    : String;
      Context : in out Test_Contexts.Capturing_Context;
      Result  : out Posix_Tools.Commands.Results.Result);

   --  The package whose Run the table binds Name to, or "" when Name is not
   --  dispatched through a context.
   function Bound_Package (Name : String) return String;

   --  Whether Name is an inventory command this package cannot run through a
   --  context.
   function Is_Rendering_Only (Name : String) return Boolean;
end Command_Tests.Dispatch;
