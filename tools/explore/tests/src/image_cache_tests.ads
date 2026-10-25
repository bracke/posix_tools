with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Image_Cache_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Reuse (T : in out Fixture);
   procedure Test_Resize (T : in out Fixture);
   procedure Test_Changed_File (T : in out Fixture);
   procedure Test_Evict_By_Count (T : in out Fixture);
   procedure Test_Evict_By_Bytes (T : in out Fixture);
   procedure Test_Clear (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Image_Cache_Tests;
