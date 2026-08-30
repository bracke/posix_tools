with AUnit.Test_Suites;
with Command_Tests.Suite_Entries;

package body Command_Tests.Suite is
   function Test_Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Command_Tests.Suite_Entries.Register (Result);
      return Result;
   end Test_Suite;
end Command_Tests.Suite;
