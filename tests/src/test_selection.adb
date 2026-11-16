with Ada.Command_Line;
with Ada.Text_IO;
with All_Suites;
with AUnit;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Results;
with Posix_Tools.Command_Inventory;
with Registered_Tests;
with Suite_Filters;
with Test_Taxonomy;

package body Test_Selection is
   function Is_Root (Name : String) return Boolean is
     (Name = "root" or else Name = "posix-tools");

   function Has_Registered_Group (Name : String) return Boolean is
      Found : Boolean := False;

      procedure Check_Name (Test_Name : String) is
         procedure Check_Prefix (Prefix : String) is
         begin
            Found := Found
              or else Suite_Filters.Selects
                (Prefix, Whole_Name => False, Test_Name => Test_Name)
              or else Suite_Filters.Selects_Alias
                (Prefix, Whole_Name => False, Test_Name => Test_Name);
         end Check_Prefix;
      begin
         if not Found then
            Test_Taxonomy.For_Each_Group_Prefix
              (Name, Check_Prefix'Access);
         end if;
      end Check_Name;
   begin
      if not Test_Taxonomy.Is_Group (Name) then
         return False;
      end if;
      Registered_Tests.For_Each_Name (Check_Name'Access);
      return Found;
   end Has_Registered_Group;

   function Has_Registered_Category (Name : String) return Boolean is
      Found : Boolean := False;

      procedure Check_Name (Test_Name : String) is
         procedure Check_Prefix (Prefix : String) is
         begin
            Found := Found
              or else Suite_Filters.Selects
                (Prefix, Whole_Name => False, Test_Name => Test_Name)
              or else Suite_Filters.Selects_Alias
                (Prefix, Whole_Name => False, Test_Name => Test_Name);
         end Check_Prefix;
      begin
         if not Found then
            Test_Taxonomy.For_Each_Category_Prefix
              (Name, Check_Prefix'Access);
         end if;
      end Check_Name;
   begin
      if not Test_Taxonomy.Is_Category (Name) then
         return False;
      end if;
      Registered_Tests.For_Each_Name (Check_Name'Access);
      return Found;
   end Has_Registered_Category;

   function Is_Suite (Name : String) return Boolean is
     (Has_Registered_Group (Name)
      or else (Is_Root (Name) and then Registered_Tests.Has_Suite ("command:root"))
      or else
        (Posix_Tools.Command_Inventory.Contains_Executable (Name)
         and then Registered_Tests.Has_Suite ("command:" & Name)));

   function Is_Category (Name : String) return Boolean is
     (Has_Registered_Category (Name));

   function Canonical_Category_Match_Count (Test_Name : String) return Natural is
     (Test_Taxonomy.Canonical_Category_Match_Count (Test_Name));

   procedure Report_Usage_Error (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "posix_tools_tests: " & Message);
   end Report_Usage_Error;

   procedure Select_Group
     (Filter : in out Suite_Filters.Filter;
      Name   : String)
   is
      First : Boolean := True;

      procedure Select_Prefix (Prefix : String) is
      begin
         if First then
            Suite_Filters.Set (Filter, Prefix, Whole_Name => False);
            First := False;
         else
            Suite_Filters.Add (Filter, Prefix);
         end if;
      end Select_Prefix;
   begin
      Test_Taxonomy.For_Each_Group_Prefix
        (Name, Select_Prefix'Access);
   end Select_Group;

   procedure Select_Category
     (Filter : in out Suite_Filters.Filter;
      Name   : String)
   is
      First : Boolean := True;

      procedure Select_Prefix (Prefix : String) is
      begin
         if First then
            Suite_Filters.Set (Filter, Prefix, Whole_Name => False);
            First := False;
         else
            Suite_Filters.Add (Filter, Prefix);
         end if;
      end Select_Prefix;
   begin
      Test_Taxonomy.For_Each_Category_Prefix
        (Name, Select_Prefix'Access);
   end Select_Category;

   --  A command's suite is its whole name, so that tr does not also
   --  select true.
   function Select_Suite
     (Filter : in out Suite_Filters.Filter;
      Name   : String) return Boolean
   is
   begin
      if Has_Registered_Group (Name) then
         Select_Group (Filter, Name);
      elsif Is_Root (Name) and then Registered_Tests.Has_Suite ("command:root") then
         Suite_Filters.Set (Filter, "command:root", Whole_Name => True);
      elsif Posix_Tools.Command_Inventory.Contains_Executable (Name)
        and then Registered_Tests.Has_Suite ("command:" & Name)
      then
         Suite_Filters.Set (Filter, "command:" & Name, Whole_Name => True);
      else
         Report_Usage_Error
           ("suite '" & Name & "' has no registered AUnit tests yet");
         return False;
      end if;
      return True;
   end Select_Suite;

   --  Test_Runner exits 0 however many assertions failed; Run takes the
   --  status and fails the process on anything but success.
   function Runner is new AUnit.Run.Test_Runner_With_Status (All_Suites.Suite);

   --  A listing reports nothing but the names the filter prints.
   type Silent is new AUnit.Reporter.Reporter with null record;

   overriding procedure Report
     (Engine  : Silent;
      R       : in out AUnit.Test_Results.Result'Class;
      Options : AUnit.Options.AUnit_Options := AUnit.Options.Default_Options) is null;

   function Run return Integer is
      use type AUnit.Status;
      Filter   : aliased Suite_Filters.Filter;
      Listing  : Boolean := False;
      Index    : Positive := 2;
      --  Only the test subcommand takes selectors; the gates that end by
      --  running the tests run them all.
      Last     : constant Natural :=
        (if Ada.Command_Line.Argument_Count >= 1 and then Ada.Command_Line.Argument (1) = "test"
         then Ada.Command_Line.Argument_Count
         else 0);
   begin
      while Index <= Last loop
         declare
            Option : constant String := Ada.Command_Line.Argument (Index);
         begin
            if Option = "--list" then
               Listing := True;
               Index := Index + 1;
            elsif Option = "--suite" and then Index < Last then
               if not Select_Suite
                 (Filter, Ada.Command_Line.Argument (Index + 1))
               then
                  return 2;
               end if;
               Index := Index + 2;
            elsif Option = "--category" and then Index < Last then
               if not Is_Category (Ada.Command_Line.Argument (Index + 1)) then
                  Report_Usage_Error
                    ("category '" & Ada.Command_Line.Argument (Index + 1) & "' has no registered AUnit tests yet");
                  return 2;
               end if;
               Select_Category
                 (Filter, Ada.Command_Line.Argument (Index + 1));
               Index := Index + 2;
            else
               Report_Usage_Error ("invalid test option '" & Option & "'");
               return 2;
            end if;
         end;
      end loop;

      Suite_Filters.Set_Listing (Filter, Listing);
      declare
         Options : constant AUnit.Options.AUnit_Options :=
           (Global_Timer     => False,
            Test_Case_Timer  => False,
            Report_Successes => True,
            Filter           => Filter'Unchecked_Access);
         Text_Reporter : AUnit.Reporter.Text.Text_Reporter;
         Quiet         : Silent;
         Outcome       : constant AUnit.Status :=
           (if Listing then Runner (Quiet, Options) else Runner (Text_Reporter, Options));
      begin
         return (if Outcome = AUnit.Success then 0 else 1);
      end;
   end Run;
end Test_Selection;
