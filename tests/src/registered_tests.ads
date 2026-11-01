--  The names of the AUnit tests All_Suites registers, found by walking
--  the suite with a filter that records each test and runs none, so a
--  reference to a test is checked against the suite rather than against
--  a string in a registration file.
package Registered_Tests is
   function Is_Registered (Name : String) return Boolean;
end Registered_Tests;
