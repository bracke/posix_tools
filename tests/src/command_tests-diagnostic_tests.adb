with AUnit.Assertions;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Dd;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Nl;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Root;
with Posix_Tools.Commands.Seq;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Command_Tests.Support;

package body Command_Tests.Diagnostic_Tests is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_Usage_Errors (T : in out Fixture) is separate;
end Command_Tests.Diagnostic_Tests;
