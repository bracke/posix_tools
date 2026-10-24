with Performance_Tests;
with Session_Tests;

package body E2E_Suites is
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Session_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Performance_Tests.Suite);
      return Result;
   end Suite;
end E2E_Suites;
