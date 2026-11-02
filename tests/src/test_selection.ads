--  The tests `posix_tools_tests test` runs. --suite names a test group by
--  its prefix, or one command's tests by its whole name; --category names
--  a set of groups; --list names the tests the selectors choose and runs
--  none of them.
package Test_Selection is
   Invalid_Usage : exception;

   --  Whether `test --suite Name` and `test --category Name` are known
   --  selectors.
   function Is_Suite (Name : String) return Boolean;
   function Is_Category (Name : String) return Boolean;

   --  Run, or list, the tests the arguments after `test` select, the last
   --  selector winning; Invalid_Usage, said why on standard error, for
   --  arguments that are not selectors.
   procedure Run;
end Test_Selection;
