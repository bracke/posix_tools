with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with All_Suites;
with AUnit;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Results;
with Posix_Tools.Command_Inventory;
with Suite_Filters;
with Test_Support;

package body Test_Selection is
   type Prefix_List is array (Positive range <>) of access constant String;

   Basic        : aliased constant String := "basic:";
   Streams      : aliased constant String := "streams:";
   Regression   : aliased constant String := "regression:";
   Locale       : aliased constant String := "locale:";
   Presentation : aliased constant String := "presentation:";
   Property     : aliased constant String := "property:";
   Command      : aliased constant String := "command:";
   No_Prefixes  : constant Prefix_List (1 .. 0) := [others => null];

   --  The group --suite Name selects by prefix; none for a name that is
   --  not a group.
   function Group (Name : String) return Prefix_List is
     (if Name = "basic" or else Name = "common" then [Basic'Access]
      elsif Name = "streams" then [Streams'Access]
      elsif Name = "regression" then [Regression'Access]
      elsif Name = "locale" then [Locale'Access]
      elsif Name = "presentation" then [Presentation'Access]
      elsif Name = "property" then [Property'Access]
      elsif Name = "command" or else Name = "commands" then [Command'Access]
      else No_Prefixes);

   --  The groups --category Name selects. Every registered test is in
   --  exactly one category: the library's own units, the commands run
   --  through their entry points, and the regression, locale and styling
   --  tests.
   function Category (Name : String) return Prefix_List is
     (if Name = "unit" then [Basic'Access, Streams'Access, Property'Access]
      elsif Name = "integration" then [Command'Access]
      elsif Name = "regression" then [Regression'Access]
      elsif Name = "locale" then [Locale'Access]
      elsif Name = "presentation" then [Presentation'Access]
      else No_Prefixes);

   function Is_Root (Name : String) return Boolean is
     (Name = "root" or else Name = "posix-tools");

   function Is_Suite (Name : String) return Boolean is
     (Group (Name)'Length > 0
      or else Is_Root (Name)
      or else Posix_Tools.Command_Inventory.Contains_Executable (Name));

   function Is_Category (Name : String) return Boolean is
     (Category (Name)'Length > 0);

   procedure Usage_Error (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "posix_tools_tests: " & Message);
      raise Invalid_Usage;
   end Usage_Error;

   procedure Select_Prefixes (Filter : in out Suite_Filters.Filter; Prefixes : Prefix_List) is
   begin
      Suite_Filters.Set (Filter, Prefixes (Prefixes'First).all, Whole_Name => False);
      for Index in Prefixes'First + 1 .. Prefixes'Last loop
         Suite_Filters.Add (Filter, Prefixes (Index).all);
      end loop;
   end Select_Prefixes;

   --  A command's suite is its whole name, so that tr does not also
   --  select true.
   procedure Select_Suite (Filter : in out Suite_Filters.Filter; Name : String) is
   begin
      if Group (Name)'Length > 0 then
         Select_Prefixes (Filter, Group (Name));
      elsif Is_Root (Name) then
         Suite_Filters.Set (Filter, "command:root", Whole_Name => True);
      elsif Posix_Tools.Command_Inventory.Contains_Executable (Name) then
         Suite_Filters.Set (Filter, "command:" & Name, Whole_Name => True);
      else
         Usage_Error ("suite '" & Name & "' has no registered AUnit tests yet");
      end if;
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

   procedure Run is
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
               Select_Suite (Filter, Ada.Command_Line.Argument (Index + 1));
               Index := Index + 2;
            elsif Option = "--category" and then Index < Last then
               if not Is_Category (Ada.Command_Line.Argument (Index + 1)) then
                  Usage_Error
                    ("category '" & Ada.Command_Line.Argument (Index + 1) & "' has no registered AUnit tests yet");
               end if;
               Select_Prefixes (Filter, Category (Ada.Command_Line.Argument (Index + 1)));
               Index := Index + 2;
            else
               Usage_Error ("invalid test option '" & Option & "'");
            end if;
         end;
      end loop;

      Suite_Filters.Set_Listing (Filter, Listing);
      --  The tests make their scratch files here, never under fixtures.
      Ada.Directories.Create_Path (Test_Support.Work_Path (""));

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
         if Outcome /= AUnit.Success then
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      end;
   end Run;
end Test_Selection;
