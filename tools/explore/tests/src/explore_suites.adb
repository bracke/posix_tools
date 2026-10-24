with Input_Tests;
with Protocol_Tests;

package body Explore_Suites is
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Protocol_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Input_Tests.Suite);
      return Result;
   end Suite;
end Explore_Suites;
