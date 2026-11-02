with Ada.Containers.Indefinite_Ordered_Sets;
with All_Suites;
with AUnit;
with AUnit.Options;
with AUnit.Reporter;
with AUnit.Run;
with AUnit.Simple_Test_Cases;
with AUnit.Test_Filters;
with AUnit.Test_Results;
with AUnit.Tests;

package body Registered_Tests is
   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   Names  : Name_Sets.Set;
   Loaded : Boolean := False;

   --  Records every test it is asked about and selects none.
   type Recorder is new AUnit.Test_Filters.Test_Filter with null record;

   overriding function Is_Active
     (Item : Recorder;
      T    : AUnit.Tests.Test'Class) return Boolean
   is
      pragma Unreferenced (Item);
      use AUnit.Simple_Test_Cases;
      use type AUnit.Message_String;
   begin
      if T in Test_Case'Class and then Name (Test_Case'Class (T)) /= null then
         Names.Include (Name (Test_Case'Class (T)).all);
      end if;

      return False;
   end Is_Active;

   type Silent is new AUnit.Reporter.Reporter with null record;

   overriding procedure Report
     (Engine  : Silent;
      R       : in out AUnit.Test_Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options) is null;

   procedure Walk is new AUnit.Run.Test_Runner (All_Suites.Suite);

   procedure Load;

   function Is_Registered (Name : String) return Boolean is
   begin
      Load;
      return Names.Contains (Name);
   end Is_Registered;

   function Has_Suite (Suite : String) return Boolean is
   begin
      Load;
      for Name of Names loop
         if Name = Suite
           or else (Name'Length > Suite'Length
                    and then Name (Name'First .. Name'First + Suite'Length) = Suite & ' ')
         then
            return True;
         end if;
      end loop;

      return False;
   end Has_Suite;

   procedure Load is
   begin
      if not Loaded then
         declare
            Filter   : aliased Recorder;
            Reporter : Silent;
         begin
            Walk
              (Reporter,
               (Global_Timer     => False,
                Test_Case_Timer  => False,
                Report_Successes => False,
                Filter           => Filter'Unchecked_Access));
         end;
         Loaded := True;
      end if;
   end Load;
end Registered_Tests;
