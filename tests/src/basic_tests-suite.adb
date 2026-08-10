with AUnit.Test_Caller;
with AUnit.Test_Suites;

package body Basic_Tests.Suite is
   package Caller is new AUnit.Test_Caller (Basic_Tests.Fixture);

   function Test_Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:command inventory", Test_Command_Inventory'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:numbers", Test_Numbers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:option parsing", Test_Option_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:paths", Test_Paths'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:byte counting", Test_Stream_Counting'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:utf-8 counting", Test_Stream_UTF_8_Counting'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:lf segment splitting", Test_Stream_Line_Split'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-CAT-0001 binary fixture", Test_Stream_File_Fixture'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:version", Test_Version'Access));
      return Result;
   end Test_Suite;
end Basic_Tests.Suite;
