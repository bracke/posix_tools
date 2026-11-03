with Ada.Directories;
with AUnit.Assertions;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;
with Command_Tests.Support;
with Posix_Tools.Commands.Head;

package body Command_Tests.Head_Tests is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_Head_Counts (T : in out Fixture) is separate;
   procedure Test_Head_Default_Limits (T : in out Fixture) is separate;
   procedure Test_Head_Invalid_Count (T : in out Fixture) is separate;
   procedure Test_Head_Missing_Count (T : in out Fixture) is separate;
   procedure Test_Head_Multiple_File_Headers (T : in out Fixture) is separate;
   procedure Test_Head_Output_Failure (T : in out Fixture) is separate;
   procedure Test_Head_Prefix_Property (T : in out Fixture) is separate;
   procedure Test_Head_Standard_Input (T : in out Fixture) is separate;
   procedure Test_Head_Standard_Input_Property (T : in out Fixture) is separate;
end Command_Tests.Head_Tests;
