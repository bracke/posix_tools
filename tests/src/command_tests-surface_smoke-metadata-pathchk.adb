with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Hostkit.Metadata;
with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Metadata.Pathchk is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Pathchk (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context        : Test_Contexts.Capturing_Context;
      Result         : Posix_Tools.Commands.Results.Result;
      Long_Component : constant String (1 .. 260) := [others => 'a'];
   begin
      Context.Initialize ("pathchk", One_Arg ("portable/name_1.2"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "pathchk accepts ordinary path without output");

      Context.Initialize ("pathchk", Two_Args ("-p", "portable_1.2"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "pathchk -p accepts portable name");

      Context.Initialize ("pathchk", Two_Args ("-p", "bad@name"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context)
           = "pathchk: 'bad@name': non-portable character" & EOL,
         "pathchk rejects a non-portable character");

      Context.Initialize ("pathchk", One_Arg (""));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context)
           = "pathchk: '': empty pathname" & EOL,
         "pathchk rejects an empty pathname");

      Context.Initialize ("pathchk", One_Arg (Long_Component));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "pathchk rejects a long component");

      declare
         Capacity : constant Hostkit.Metadata.Volume_Capacity :=
           Hostkit.Metadata.Volume_Capacity_Of (".");
      begin
         if Capacity.Available
           and then Capacity.Name_Max_Known
           and then Capacity.Name_Max < 1_024
         then
            declare
               Too_Long : constant String (1 .. Capacity.Name_Max + 1) :=
                 [others => 'b'];
            begin
               Context.Initialize ("pathchk", One_Arg (Too_Long));
               Posix_Tools.Commands.Pathchk.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
                  "pathchk rejects host-reported name_max overflow");
            end;
         end if;
      end;

      Context.Initialize ("pathchk", No_Args);
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "pathchk rejects missing operands");
   end Test_Pathchk;
end Command_Tests.Surface_Smoke.Metadata.Pathchk;
