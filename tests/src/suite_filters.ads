with Ada.Containers.Indefinite_Vectors;
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
   --  Select the tests whose name starts with Prefix as well.
   procedure Add (Item : in out Filter; Prefix : String);

   --  With Listing, Is_Active prints the name of each test it selects on
   --  standard output and selects none, so a run names its tests and runs
   --  nothing.
   procedure Set_Listing (Item : in out Filter; Listing : Boolean);

   overriding function Is_Active
     (Item : Filter;
      T    : AUnit.Tests.Test'Class) return Boolean;

   --  The rule Is_Active applies to one test name and one prefix.
   function Selects (Prefix : String; Whole_Name : Boolean; Test_Name : String) return Boolean;
private
   package Prefix_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  No prefixes selects every test.
   type Filter is new AUnit.Test_Filters.Test_Filter with record
      Prefixes   : Prefix_Vectors.Vector;
      Whole_Name : Boolean := False;
      Listing    : Boolean := False;
   end record;
end Suite_Filters;
