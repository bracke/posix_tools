with AUnit.Test_Suites;
with Basic_Tests.Suite;
with Command_Tests.Suite;

package body All_Suites is
   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Basic_Tests.Suite.Test_Suite);
      AUnit.Test_Suites.Add_Test (Result, Command_Tests.Suite.Test_Suite);
      return Result;
   end Suite;
end All_Suites;
