--  The tests `posix_tools_tests test` runs. --suite names a test group by
--  its prefix, or one command's tests by its whole name; --category names
--  a set of groups; --list names the tests the selectors choose and runs
--  none of them.
package Test_Selection is
   --  Whether `test --suite Name` and `test --category Name` are known
   --  selectors.
   function Is_Suite (Name : String) return Boolean;
   function Is_Category (Name : String) return Boolean;

   --  Number of categories whose canonical prefixes select Test_Name.
   --  Regression aliases are tags and are deliberately not counted as
   --  additional canonical categories.
   function Canonical_Category_Match_Count (Test_Name : String) return Natural;

   --  Run, or list, the tests the arguments after `test` select, the last
   --  selector winning.  Return 0 for success, 1 for failed tests, or 2 after
   --  reporting invalid selectors.
   function Run return Integer;
end Test_Selection;
