with Ada.Containers.Vectors;
with Explore.Model;

--  Tabs: several browsers, one of them shown. The shown one, the active tab's,
--  is the caller's to keep and change; the set holds every other tab's, and
--  takes the active one's in when another tab is made active.
--
--  Every tab draws its generations from one sequence: the tab made active
--  goes on from the last generation the one left had handed out, so that
--  nothing still being read for the tab left can pass for what the tab made
--  active asks for.
package Explore.Tabs is
   package Browser_Vectors is new Ada.Containers.Vectors (Positive, Explore.Model.Browser, Explore.Model."=");

   type Tab_Set is record
      --  Every tab's browser, in order. The active tab's slot holds what it
      --  was when it was last left; the caller holds what it is now.
      Browsers : Browser_Vectors.Vector;
      Active   : Positive := 1;
   end record;

   --  Make Browser the first and only tab.
   procedure Start (Self : in out Tab_Set; Browser : Explore.Model.Browser);

   function Count (Self : Tab_Set) return Natural is (Natural (Self.Browsers.Length));

   --  Open a tab after the active one, on the same directory with the cursor
   --  on the same entry, and make it active.
   procedure Open_Tab (Self : in out Tab_Set; Browser : in out Explore.Model.Browser);

   --  Close the active tab, making the next one active, or the one before it
   --  when it was the last. The only tab is not closed.
   procedure Close_Tab (Self : in out Tab_Set; Browser : in out Explore.Model.Browser);

   --  Make tab To the active one, reading its panes again. Nothing happens
   --  when it already is, or when there is no such tab.
   procedure Switch_To (Self : in out Tab_Set; Browser : in out Explore.Model.Browser; To : Positive);

   --  The tab before the active one, and the one after, going round.
   function Previous (Self : Tab_Set) return Positive is (if Self.Active = 1 then Count (Self) else Self.Active - 1)
     with Pre => Count (Self) > 0;

   function Next (Self : Tab_Set) return Positive is (if Self.Active = Count (Self) then 1 else Self.Active + 1)
     with Pre => Count (Self) > 0;

   --  The tabs as the heading shows them, each its number and directory's
   --  name, the active one bracketed; empty when there is only one.
   function Line (Self : Tab_Set; Browser : Explore.Model.Browser) return String;
end Explore.Tabs;
