with Ada.Strings.Unbounded;

with Awk_CLI.Redirections;

private package Awk_CLI.Live_Context_Callbacks is
   --  Host callback operations that act on an invocation context.
   --
   --  Input stream selection remains in Awk_CLI.Inputs.Live. These helpers
   --  own only the live host effects requested by awklib callbacks.

   package U renames Ada.Strings.Unbounded;

   --  @param Context Invocation context to write through.
   --  @param Content Exact AWK standard output chunk.
   --  @return True when the output write succeeded.
   function Write_Output
     (Context : in out Invocation_Context;
      Content : String) return Boolean;

   --  @param Context Invocation context to write through.
   --  @param Path AWK redirection target path.
   --  @param Content Exact redirected output chunk.
   --  @param Append Whether append semantics are requested.
   --  @return Host redirection write status.
   function Write_Redirection
     (Context : in out Invocation_Context;
      Path    : String;
      Content : String;
      Append  : Boolean) return Awk_CLI.Redirections.Write_Status;

   --  @param Context Invocation context containing deterministic commands.
   --  @param Command Host command text requested by awklib.
   --  @param Output Captured command output.
   --  @return True when command output is available.
   function Read_Command
     (Context : in out Invocation_Context;
      Command : String;
      Output  : out U.Unbounded_String) return Boolean;
end Awk_CLI.Live_Context_Callbacks;
