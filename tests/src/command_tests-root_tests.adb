with AUnit.Assertions;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;
with Posix_Tools.Version;
with Test_Contexts;
with Command_Tests.Dispatch;
with Command_Tests.Support;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Root;

package body Command_Tests.Root_Tests is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Support;

   procedure Test_Root_Command_Help_Inventory_Property (T : in out Fixture) is separate;
   procedure Test_Root_Command_Help_Uses_Command_Metadata (T : in out Fixture) is separate;
   procedure Test_Root_List (T : in out Fixture) is separate;
   procedure Test_Root_List_Inventory_Property (T : in out Fixture) is separate;
   procedure Test_Root_List_Locale_Invariance (T : in out Fixture) is separate;
   procedure Test_Root_Localized_Help (T : in out Fixture) is separate;
   procedure Test_Root_Output_Failure (T : in out Fixture) is separate;
   procedure Test_Root_Paths (T : in out Fixture) is separate;
   procedure Test_Root_Paths_Verify_Inventory_Property (T : in out Fixture) is separate;
   procedure Test_Root_Usage_Edges (T : in out Fixture) is separate;
   procedure Test_Root_Verify (T : in out Fixture) is separate;
   procedure Test_Root_Verify_Status_Locales (T : in out Fixture) is separate;
   procedure Test_Root_Version_And_Help (T : in out Fixture) is separate;
end Command_Tests.Root_Tests;
