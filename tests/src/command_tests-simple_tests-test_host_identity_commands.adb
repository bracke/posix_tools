separate (Command_Tests.Simple_Tests)

   procedure Test_Host_Identity_Commands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("arch", No_Args);
      Posix_Tools.Commands.Arch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-machine" & LF,
         "arch uses context machine identity");

      Context.Initialize ("whoami", No_Args);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-user" & LF,
         "whoami uses context user identity");

      Context.Initialize ("whoami", No_Args);
      Test_Contexts.Set_Current_User_Available (Context, False);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Contains (Test_Contexts.Error_Output (Context), "unsupported platform capability"),
         "whoami reports unavailable user identity");

      Context.Initialize ("logname", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LOGNAME", "login-user");
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "login-user" & LF,
         "logname prefers the command environment login name");

      Context.Initialize ("logname", No_Args);
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "session-user" & LF,
         "logname falls back to the context session login name");

      Context.Initialize ("id", No_Args);
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "uid=50000(test-user) gid=60000(test-primary) groups=60000(test-primary),60001(test-extra)" & LF,
         "id default output is decorated with context names");

      Context.Initialize ("id", One_Arg ("-u"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "50000" & LF,
         "id -u prints the numeric user id");

      Context.Initialize ("id", Two_Args ("-u", "-n"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-user" & LF,
         "id -un prints the user name");

      Context.Initialize ("id", One_Arg ("-G"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "60000 60001" & LF,
         "id -G prints numeric group ids");

      Context.Initialize ("id", Two_Args ("-G", "-n"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & LF,
         "id -Gn prints named group ids");

      Context.Initialize ("id", No_Args);
      Test_Contexts.Set_Current_Group_Available (Context, False);
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "unsupported platform capability"),
         "id reports unavailable group identity");

      Context.Initialize ("groups", No_Args);
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & LF,
         "groups prints current context group names");

      Context.Initialize ("groups", One_Arg ("named-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "named-user : named-extra test-primary" & LF,
         "groups prints named user group names");

      Context.Initialize ("groups", One_Arg ("missing-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "missing-user"),
         "groups reports unknown user group lookup failures");

      Context.Initialize ("hostname", No_Args);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-node" & LF,
         "hostname prints context node name");

      Context.Initialize ("hostname", One_Arg ("new-node"));
      Test_Contexts.Set_Node_Name_Allowed (Context, True);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Node_Name_Set_Called (Context)
         and then Test_Contexts.Captured_Node_Name (Context) = "new-node",
         "hostname delegates node-name updates through the context");

      Context.Initialize ("uname", Two_Args ("-s", "-n"));
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "test-node"),
         "uname -n includes the context node name");
   end Test_Host_Identity_Commands;
