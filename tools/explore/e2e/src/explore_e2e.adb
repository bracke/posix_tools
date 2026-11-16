with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Finalization;
with Ada.Strings.Unbounded;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with E2E_Bootstrap;
with E2E_Processes;
with E2E_Rig.Testing;
with E2E_Suites;
with Hostkit.Fs;

--  Runs explore end to end and exits non-zero when any test failed.
procedure Explore_E2E is
   use type AUnit.Status;

   Child_Argument : constant String := "--posix-tools-e2e-bootstrapped";
   package Run_Directories is
      type Guard is new Ada.Finalization.Limited_Controlled with private;

      procedure Arm (Self : in out Guard; Root : String);
      procedure Delete (Self : in out Guard);

   private
      type Guard is new Ada.Finalization.Limited_Controlled with record
         Root : Ada.Strings.Unbounded.Unbounded_String;
      end record;

      overriding procedure Finalize (Self : in out Guard);
   end Run_Directories;

   --  Prepare a private launcher tree before starting a child whose PTY
   --  backend will snapshot that launcher's path during elaboration.
   function Run_Bootstrapped
     (Argument   : String;
      Timeout_Ms : Positive;
      Group      : E2E_Processes.Group_Policy :=
        E2E_Processes.New_Process_Group) return Integer;

   function Run_Bootstrapped
     (Argument   : String;
      Timeout_Ms : Positive;
      Group      : E2E_Processes.Group_Policy :=
        E2E_Processes.New_Process_Group) return Integer
   is
      Run_Root : constant String :=
        Hostkit.Fs.Create_Temporary_Directory ("posix-tools-e2e");
      Guard : Run_Directories.Guard;
      Status : Integer;
   begin
      if Run_Root = "" then
         raise Program_Error with "could not create the E2E run directory";
      end if;

      Run_Directories.Arm (Guard, Run_Root);
      E2E_Bootstrap.Prepare (Run_Root);
      Ada.Environment_Variables.Set
        ("SHELL", E2E_Bootstrap.Launcher_Path);
      Status :=
        E2E_Processes.Run
          (E2E_Bootstrap.Program_Path, Argument, Timeout_Ms, Group);
      Run_Directories.Delete (Guard);
      return Status;
   end Run_Bootstrapped;

   package body Run_Directories is
      procedure Arm (Self : in out Guard; Root : String) is
      begin
         if Ada.Strings.Unbounded.Length (Self.Root) /= 0 then
            raise Program_Error with
              "the E2E run directory guard is already armed";
         end if;

         Self.Root := Ada.Strings.Unbounded.To_Unbounded_String (Root);
      end Arm;

      procedure Delete (Self : in out Guard) is
         Path : constant String :=
           Ada.Strings.Unbounded.To_String (Self.Root);
      begin
         if Path /= "" and then Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_Tree (Path);
         end if;
         Self.Root := Ada.Strings.Unbounded.Null_Unbounded_String;
      end Delete;

      overriding procedure Finalize (Self : in out Guard) is
      begin
         Delete (Self);
      exception
         when others =>
            --  intentional terminal exception barrier
            --  Finalization must preserve the exception that unwound the scope.
            null;
      end Finalize;
   end Run_Directories;

   function Runner is new AUnit.Run.Test_Runner_With_Status (E2E_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = Child_Argument
   then
      if Runner (Reporter) /= AUnit.Success then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   elsif Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) =
       E2E_Rig.Testing.Launch_Failure_Child_Argument
   then
      if not E2E_Rig.Testing.Launch_Failure_Poisons then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   elsif Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) =
       E2E_Rig.Testing.Timeout_Child_Argument
   then
      delay 60.0;
   elsif Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) =
       E2E_Rig.Testing.Launch_Failure_Argument
   then
      if Run_Bootstrapped
           (E2E_Rig.Testing.Launch_Failure_Child_Argument,
            Timeout_Ms => 15_000,
            Group      => E2E_Processes.Inherit_Process_Group) /= 0
      then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   else
      --  The PTY backend snapshots the environment during elaboration.  Start
      --  a fresh copy with the rig launcher already selected, so this test
      --  executable is hermetic and works outside the aggregate release gate.
      if Run_Bootstrapped (Child_Argument, Timeout_Ms => 120_000) /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end if;
end Explore_E2E;
