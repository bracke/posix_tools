with Ada.Directories;
with AUnit.Assertions;
with Hostkit.Fs;
with Posix_Tools.Commands.Basename;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Echo;
with Posix_Tools.Commands.File;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Command_Tests.Support;

package body Command_Tests.Output_Failure_Tests is
   use type Ada.Directories.File_Kind;
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_Command_Verbose_Output_Failures (T : in out Fixture) is separate;
   procedure Test_Simple_Output_Failures (T : in out Fixture) is separate;
   procedure Test_Standard_Input_Read_Failures (T : in out Fixture) is separate;
end Command_Tests.Output_Failure_Tests;
