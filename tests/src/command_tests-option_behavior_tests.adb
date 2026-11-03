with AUnit.Assertions;
with Posix_Tools.Commands.Basename;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Cut;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Fold;
with Posix_Tools.Commands.Getconf;
with Posix_Tools.Commands.Head;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Nice;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.Tty;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;
with Test_Contexts;
with Command_Tests.Support;

package body Command_Tests.Option_Behavior_Tests is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_End_Of_Options (T : in out Fixture) is separate;
   procedure Test_Option_Parsing (T : in out Fixture) is separate;
end Command_Tests.Option_Behavior_Tests;
