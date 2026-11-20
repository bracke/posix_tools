with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Diagnostic_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;
   function Run_Rg_Danish (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   function Run_Rg_Danish (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg_Danish;

   procedure Test_Diagnostics (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-diagnostics");
      Visible : constant String := Root & "/visible.adb";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (Root & "/.gitignore", "*.gen" & LF);
      Test_Support.Write_File (Visible, "needle visible" & LF);
      Test_Support.Write_File (Root & "/drop.gen", "needle ignored" & LF);
      Test_Support.Write_File (Root & "/.hidden.adb", "needle hidden" & LF);

      declare
         Plain       : constant Run_Outcome := Run_Rg (["needle", Root]);
         Debug       : constant Run_Outcome := Run_Rg (["--debug", "needle", Root]);
         Trace       : constant Run_Outcome := Run_Rg (["--trace", "needle", Root]);
         Lowered     : constant Run_Outcome := Run_Rg (["--trace", "--debug", "needle", Root]);
         Raised      : constant Run_Outcome := Run_Rg (["--debug", "--trace", "needle", Root]);
         Listed      : constant Run_Outcome := Run_Rg (["--debug", "--files", Root]);
         Debug_Error : constant String := To_String (Debug.Errors);
         Trace_Error : constant String := To_String (Trace.Errors);
      begin
         AUnit.Assertions.Assert
           (Plain.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Plain.Errors) = ""
            and then To_String (Plain.Output) = To_String (Debug.Output),
            "debug logging is isolated to standard error");
         AUnit.Assertions.Assert
           (Debug.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (Debug_Error, "rg: DEBUG|rg::config|")
            and then Test_Support.Contains (Debug_Error, "rg: DEBUG|rg::regexp|")
            and then Test_Support.Contains (Debug_Error, "loaded 1 ignore source")
            and then Test_Support.Contains (Debug_Error, "drop.gen: matched *.gen")
            and then Test_Support.Contains (Debug_Error, ".hidden.adb: hidden path")
            and then not Test_Support.Contains (Debug_Error, "TRACE|"),
            "--debug reports configuration and every traversal exclusion reason");
         AUnit.Assertions.Assert
           (Trace.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (Trace_Error, "rg: DEBUG|")
            and then Test_Support.Contains (Trace_Error, "rg: TRACE|rg::regexp|")
            and then Test_Support.Contains (Trace_Error, "rg: TRACE|rg::walk|selected")
            and then Test_Support.Contains (Trace_Error, "rg: TRACE|rg::search|searching")
            and then Test_Support.Contains (Trace_Error, "rg: TRACE|rg::search|finished"),
            "--trace includes debug messages and detailed search events");
         AUnit.Assertions.Assert
           (not Test_Support.Contains (To_String (Lowered.Errors), "TRACE|")
            and then Test_Support.Contains (To_String (Raised.Errors), "TRACE|"),
            "the last diagnostic verbosity option wins");
         AUnit.Assertions.Assert
           (Listed.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Listed.Errors), "drop.gen: matched *.gen"),
            "file listing shares traversal diagnostics");
      end;

      declare
         Bad_Type : constant Run_Outcome := Run_Rg_Danish (["-t", "ukendt", "needle", Root]);
         Bad_Regex : constant Run_Outcome := Run_Rg_Danish (["(", Visible]);
         Missing : constant Run_Outcome := Run_Rg_Danish (["needle", Root & "/missing.adb"]);
      begin
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Bad_Type.Errors), "ukendt filtype"),
            "file-type parser diagnostics use the Danish catalog");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Bad_Regex.Errors), "ugyldigt mønster"),
            "regex diagnostics use the Danish catalog");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Missing.Errors), "kan ikke læse"),
            "runtime file diagnostics use the Danish catalog");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_Diagnostics;
end Rg_Diagnostic_Tests;
