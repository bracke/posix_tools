package E2E_Rig.Testing is
   Launch_Failure_Argument : constant String :=
     "--posix-tools-e2e-launch-failure";
   Launch_Failure_Child_Argument : constant String :=
     "--posix-tools-e2e-launch-failure-child";
   Timeout_Child_Argument : constant String :=
     "--posix-tools-e2e-timeout-child";

   --  Exercise destructive launcher-failure recovery in this process.  The
   --  caller must isolate the process because success poisons its coordinator.
   function Launch_Failure_Poisons return Boolean;

   --  Start after Synchronize has coordinated private preparation with peers.
   procedure Start_Synchronized
     (Self        : in out Rig;
      Directory   : String;
      Synchronize : not null access procedure);

end E2E_Rig.Testing;
