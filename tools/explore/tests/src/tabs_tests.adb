with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Model;
with Explore.Tabs;

package body Tabs_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Model renames Explore.Model;
   package Tabs renames Explore.Tabs;
   package Unbounded renames Ada.Strings.Unbounded;

   function Current (Browser : Model.Browser) return String is
     (Unbounded.To_String (Browser.Panes (Model.Current_Pane).Path));

   --  Two tabs, the second active: /home/a, then /srv/b.
   procedure Two_Tabs (Set : out Tabs.Tab_Set; Browser : out Model.Browser);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("tabs:open", Test_Open'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("tabs:switch", Test_Switch'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("tabs:close", Test_Close'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("tabs:round", Test_Round'Access));
      return Result;
   end Suite;

   procedure Test_Close (T : in out Fixture) is
      pragma Unreferenced (T);
      Set     : Tabs.Tab_Set;
      Browser : Model.Browser;
   begin
      Two_Tabs (Set, Browser);
      Tabs.Switch_To (Set, Browser, 1);

      declare
         Before : constant Natural := Browser.Last_Generation;
      begin
         Tabs.Close_Tab (Set, Browser);
         AUnit.Assertions.Assert (Tabs.Count (Set) = 1 and then Set.Active = 1, "the first tab is closed");
         AUnit.Assertions.Assert (Current (Browser) = "/srv/b", "the next tab is shown");
         AUnit.Assertions.Assert
           (Browser.Last_Generation > Before, "its generations go on from the closed tab's");
      end;

      Tabs.Close_Tab (Set, Browser);
      AUnit.Assertions.Assert
        (Tabs.Count (Set) = 1 and then Current (Browser) = "/srv/b", "the only tab is not closed");
   end Test_Close;

   procedure Test_Open (T : in out Fixture) is
      pragma Unreferenced (T);
      Set     : Tabs.Tab_Set;
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/home/a");
      Browser.Show_Hidden := True;
      Tabs.Start (Set, Browser);
      AUnit.Assertions.Assert (Tabs.Count (Set) = 1 and then Tabs.Line (Set, Browser) = "", "one tab, no line");

      declare
         Before : constant Natural := Browser.Last_Generation;
      begin
         Tabs.Open_Tab (Set, Browser);
         AUnit.Assertions.Assert (Tabs.Count (Set) = 2 and then Set.Active = 2, "the new tab is active");
         AUnit.Assertions.Assert (Current (Browser) = "/home/a", "on the same directory");
         AUnit.Assertions.Assert (Browser.Show_Hidden, "with the same settings");
         AUnit.Assertions.Assert (Browser.Last_Generation > Before, "its generations go on from the first tab's");
         AUnit.Assertions.Assert
           (Tabs.Line (Set, Browser) = " 1 a  [2 a] ", "the line: " & Tabs.Line (Set, Browser));
      end;
   end Test_Open;

   procedure Test_Round (T : in out Fixture) is
      pragma Unreferenced (T);
      Set     : Tabs.Tab_Set;
      Browser : Model.Browser;
   begin
      Two_Tabs (Set, Browser);
      AUnit.Assertions.Assert (Tabs.Next (Set) = 1, "after the last comes the first");
      AUnit.Assertions.Assert (Tabs.Previous (Set) = 1, "before the second comes the first");
      Tabs.Switch_To (Set, Browser, 1);
      AUnit.Assertions.Assert (Tabs.Previous (Set) = 2, "before the first comes the last");
   end Test_Round;

   procedure Test_Switch (T : in out Fixture) is
      pragma Unreferenced (T);
      Set     : Tabs.Tab_Set;
      Browser : Model.Browser;
   begin
      Two_Tabs (Set, Browser);

      declare
         Before : constant Natural := Browser.Last_Generation;
      begin
         Tabs.Switch_To (Set, Browser, 1);
         AUnit.Assertions.Assert (Set.Active = 1 and then Current (Browser) = "/home/a", "the first tab is shown");
         AUnit.Assertions.Assert
           (Browser.Last_Generation > Before, "its generations go on from the tab left");
         AUnit.Assertions.Assert
           (Browser.Panes (Model.Current_Pane).Pending, "its panes are read again");
         AUnit.Assertions.Assert
           (Tabs.Line (Set, Browser) = "[1 a]  2 b  ", "the line: " & Tabs.Line (Set, Browser));
      end;

      Tabs.Switch_To (Set, Browser, 2);
      AUnit.Assertions.Assert (Current (Browser) = "/srv/b", "the second tab kept its directory");

      declare
         Before : constant Natural := Browser.Last_Generation;
      begin
         Tabs.Switch_To (Set, Browser, 2);
         Tabs.Switch_To (Set, Browser, 3);
         AUnit.Assertions.Assert
           (Set.Active = 2 and then Browser.Last_Generation = Before,
            "switching to the active tab, or to none, changes nothing");
      end;

      --  A search the tab was left in the middle of was stopped; coming back
      --  begins it again, under a generation of its own.
      declare
         Searched : Natural;
      begin
         Model.Begin_Search (Browser, "/srv/b", "x", Contents => False, Generation => Searched);
         Browser.Search_Wanted := False;
         Tabs.Switch_To (Set, Browser, 1);
         Tabs.Switch_To (Set, Browser, 2);
         AUnit.Assertions.Assert
           (Model.Is_Searching (Browser) and then Browser.Search_Wanted
            and then Browser.Panes (Model.Current_Pane).Generation /= Searched,
            "an unfinished search begins again when its tab comes back");
      end;
   end Test_Switch;

   procedure Two_Tabs (Set : out Tabs.Tab_Set; Browser : out Model.Browser) is
   begin
      Browser := (others => <>);
      Model.Open (Browser, "/home/a");
      Tabs.Start (Set, Browser);
      Tabs.Open_Tab (Set, Browser);
      Model.Open (Browser, "/srv/b");
   end Two_Tabs;
end Tabs_Tests;
