with Awk_CLI.Diagnostics;
with Awk_CLI.Options;

package Awk_CLI.Invocation is
   --  Internal parsed-invocation executor for ordinary AWK program runs.

   type Invocation_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            Exit_Status : Exit_Code := 0;
         when False =>
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   --  @param Context Invocation context to execute against.
   --  @param Options Parsed options for a non-help, non-version AWK run.
   --  @return Exit status or structured diagnostic from the execution path.
   function Execute
     (Context : in out Invocation_Context;
      Options : Awk_CLI.Options.Parsed_Options) return Invocation_Result;
end Awk_CLI.Invocation;
