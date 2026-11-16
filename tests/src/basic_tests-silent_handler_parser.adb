with Metadata_Checks.Silent_Handlers.Tests;

package body Basic_Tests.Silent_Handler_Parser is
   procedure Test_Parser (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Silent_Handlers.Tests.Run;
   end Test_Parser;
end Basic_Tests.Silent_Handler_Parser;
