with Ada.Strings.Unbounded;
with AUnit.Test_Filters;
with AUnit.Tests;

--  The test selection behind --suite and --category. AUnit's Name_Filter
--  selects by prefix, so "command:tr" would also run command:true; a
--  filter that names one suite here selects only the tests whose name is
--  that suite, or that suite followed by a space.
package Suite_Filters is
   type Filter is new AUnit.Test_Filters.Test_Filter with private;

   --  Select the tests whose name starts with Prefix. With Whole_Name, the
   --  prefix must also end where the test name does or at a space, so it
   --  names a whole suite rather than the start of one.
   procedure Set (Item : in out Filter; Prefix : String; Whole_Name : Boolean);

   overriding function Is_Active
     (Item : Filter;
      T    : AUnit.Tests.Test'Class) return Boolean;

   --  The rule Is_Active applies to one test name.
   function Selects (Prefix : String; Whole_Name : Boolean; Test_Name : String) return Boolean;
private
   type Filter is new AUnit.Test_Filters.Test_Filter with record
      Prefix     : Ada.Strings.Unbounded.Unbounded_String;
      Whole_Name : Boolean := False;
   end record;
end Suite_Filters;
