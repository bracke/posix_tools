with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Processes;
with Proof_Targets;
with Tooling_Checks;
with Tooling_Support;

package body Proof_Checks is
   use Tooling_Support;

   function Prove_Args
     (Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
      return Project_Tools.Processes.Argument_Vectors.Vector is
   begin
      return Project_Tools.Processes.Arguments
        ([Project_Tools.Processes.Argument ("-P"),
          Project_Tools.Processes.Argument ("posix_tools_proof.gpr"),
          Project_Tools.Processes.Argument ("-u"),
          Project_Tools.Processes.Argument (Unit_Name),
          Project_Tools.Processes.Argument ("--mode=" & Mode),
          Project_Tools.Processes.Argument ("--level=" & Level),
          Project_Tools.Processes.Argument ("--checks-as-errors=on"),
          Project_Tools.Processes.Argument ("--warnings=error"),
          Project_Tools.Processes.Argument ("--prover=z3")]);
   end Prove_Args;

   procedure Prove_Target
     (Gnatprove : String;
      Label     : String;
      Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
   is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Project_Tools.Files.Join (Root, "common"),
           Program => Gnatprove,
           Args    => Prove_Args (Unit_Name, Mode, Level));
   begin
      if Status /= 0 then
         Tooling_Checks.Fail
           ("proof target " & Unit_Name & " failed in " & Mode & " mode");
      end if;
   end Prove_Target;

   procedure Run is
      procedure Run_Targets is new Proof_Targets (Prove_Target);
      Gnatprove : constant String := Project_Tools.Processes.Locate_Command ("gnatprove");
   begin
      if Gnatprove = "" then
         Tooling_Checks.Fail
           ("gnatprove command not found for proof checks; install it with `alr -n install gnatprove`");
      end if;

      Run_Targets (Gnatprove);
      Ada.Text_IO.Put_Line ("proof checks passed");
   end Run;
end Proof_Checks;
