with Ada.Exceptions;
with Ada.Strings.Fixed;
with E2E_Bootstrap;
with E2E_Files;
with GNAT.OS_Lib;

package body E2E_Rig.Testing is
   LF : constant Character := Character'Val (10);

   function Launch_Failure_Poisons return Boolean is
      Root : constant String := Fixture ("launch-failure-isolated");
      First, Second : Rig;
      Claim_Failed  : Boolean := False;
      Was_Poisoned  : Boolean := False;
   begin
      E2E_Files.Write
        (E2E_Bootstrap.Launcher_Path,
         "#!/bin/sh" & LF & "exit 0" & LF);
      GNAT.OS_Lib.Set_Executable (E2E_Bootstrap.Launcher_Path);

      begin
         Start_With_Hook (First, Root, Claim_Attempts => 1);
      exception
         when Failure : Program_Error =>
            Claim_Failed :=
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Failure),
                 "did not claim") > 0;
      end;
      if not Claim_Failed then
         Stop (First);
      end if;

      begin
         Start (Second, Root);
      exception
         when Failure : Program_Error =>
            Was_Poisoned :=
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Failure),
                 "unavailable after an uncertain failure") > 0;
      end;
      if not Was_Poisoned then
         Stop (Second);
      end if;

      return Claim_Failed and then Was_Poisoned;
   end Launch_Failure_Poisons;

   procedure Start_Synchronized
     (Self        : in out Rig;
      Directory   : String;
      Synchronize : not null access procedure) is
   begin
      Start_With_Hook
        (Self, Directory, On_Ready_To_Launch => Synchronize);
   end Start_Synchronized;

end E2E_Rig.Testing;
