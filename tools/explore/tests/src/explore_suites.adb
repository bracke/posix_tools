with Input_Tests;
with Jobs_Tests;
with Model_Tests;
with Preview_Tests;
with Protocol_Tests;
with Screen_Tests;
with Search_Tests;

package body Explore_Suites is
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Protocol_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Input_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Screen_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Model_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Jobs_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Preview_Tests.Suite);
      AUnit.Test_Suites.Add_Test (Result, Search_Tests.Suite);
      return Result;
   end Suite;
end Explore_Suites;
