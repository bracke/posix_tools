with AUnit.Assertions;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Command_Tests.Support;

package body Command_Tests.Xargs_Tests is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_Xargs_Continues_After_Failure (T : in out Fixture) is separate;
end Command_Tests.Xargs_Tests;
