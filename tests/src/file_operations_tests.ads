with AUnit.Test_Fixtures;

--  Tests of the shared filesystem operations and the text helpers they use.
package File_Operations_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Natural_Order (T : in out Fixture);
   procedure Test_Permission_Image (T : in out Fixture);
   procedure Test_Directory_Listing (T : in out Fixture);
   procedure Test_Listing_Sort (T : in out Fixture);
end File_Operations_Tests;
