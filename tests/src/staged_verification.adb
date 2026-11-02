with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Host_Adapters.Processes;
with Project_Tools.Processes;
with Test_Support;
with Tooling_Checks;
with Tooling_Support;

package body Staged_Verification is
   use Tooling_Support;

   --  What Program does when asked who it is, for a failed check to
   --  report: its output, under a deadline so a program that hangs cannot
   --  stall the gate, and a second run with a stopwatch, to tell a program
   --  that hangs from a slow one and either from a crash: on Windows a
   --  crash exits with a large NTSTATUS code.
   function Identity_Diagnostic (Program : String) return String is
      use Ada.Strings.Unbounded;
      Captured       : Project_Tools.Processes.Captured_Process;
      Direct_Started : Boolean;
      Direct_Timeout : Boolean;
   begin
      Run_Within
        (Program,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
         30.0,
         Captured,
         Direct_Started,
         Direct_Timeout,
         Err_To_Out => True);

      declare
         Started     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Exit_Status : Integer;
         Timed_Out   : Boolean;
         Ran         : constant Boolean :=
           Posix_Tools.Host_Adapters.Processes.Run_With_Timeout
             (Program, Test_Support.One_Arg ("--posix-tools-identify"), 30_000, Exit_Status, Timed_Out);
         Elapsed_Ms  : constant Integer :=
           Integer (Ada.Real_Time.To_Duration (Ada.Real_Time."-" (Ada.Real_Time.Clock, Started)) * 1000.0);
      begin
         return
           " path=""" & Program & """"
           & " direct-started=" & Boolean'Image (Direct_Started)
           & " direct-timed-out=" & Boolean'Image (Direct_Timeout)
           & " direct-status=" & Integer'Image (Captured.Status)
           & " direct-output=""" & Display_Output (To_String (Captured.Output)) & """"
           & " rerun-started=" & Boolean'Image (Ran)
           & " rerun-timed-out=" & Boolean'Image (Timed_Out)
           & " rerun-status=" & Integer'Image (Exit_Status)
           & " rerun-ms=" & Integer'Image (Elapsed_Ms);
      end;
   end Identity_Diagnostic;

   --  Program identifies itself as Executable at this version, and is
   --  classified as the wrong version when another one is expected.
   procedure Verify (Executable : String; Program : String) is
      Status : constant String :=
        Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path (Executable, Program);
   begin
      if Status /= "ok" then
         Tooling_Checks.Fail
           ("staged verification failed for " & Executable & ": " & Status
            & Identity_Diagnostic (Program));
      end if;

      declare
         Other_Version : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path (Executable, Program, "0.0.0");
      begin
         if Other_Version /= "wrong version" then
            Tooling_Checks.Fail
              ("staged verification wrong-version classification failed for " & Executable & ": "
               & Other_Version);
         end if;
      end;
   end Verify;

   procedure Run is
   begin
      Verify ("posix-tools", Built_Root_Path);
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Verify
           (Posix_Tools.Command_Inventory.Executable (I),
            Built_Command_Path (Posix_Tools.Command_Inventory.Executable (I)));
      end loop;

      Ada.Text_IO.Put_Line ("staged verification checks passed");
   end Run;
end Staged_Verification;
