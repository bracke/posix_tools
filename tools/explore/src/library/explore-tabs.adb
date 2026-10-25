with Ada.Strings.Unbounded;
with Explore.Paths;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Tabs is
   package Model renames Explore.Model;
   package Unbounded renames Ada.Strings.Unbounded;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  Make Next the browser shown in place of Browser, its generations going
   --  on from Browser's, and read its panes again.
   procedure Take_Over (Browser : in out Model.Browser; Next : Model.Browser);

   procedure Close_Tab (Self : in out Tab_Set; Browser : in out Model.Browser) is
   begin
      if Count (Self) > 1 then
         declare
            Next : constant Positive := Natural'Min (Self.Active, Count (Self) - 1);
         begin
            Self.Browsers.Delete (Self.Active);
            Self.Active := Next;
            Take_Over (Browser, Self.Browsers (Next));
         end;
      end if;
   end Close_Tab;

   function Line (Self : Tab_Set; Browser : Model.Browser) return String is
      Result : Unbounded.Unbounded_String;
   begin
      if Count (Self) > 1 then
         for I in 1 .. Count (Self) loop
            declare
               Path  : constant String :=
                 Unbounded.To_String
                   (if I = Self.Active then Browser.Panes (Model.Current_Pane).Path
                    else Self.Browsers (I).Panes (Model.Current_Pane).Path);
               Name  : constant String := (if Path = "/" then "/" else Explore.Paths.Name_Of (Path));
               Label : constant String := Image (I) & " " & Name;
            begin
               Unbounded.Append (Result, (if I = Self.Active then "[" & Label & "] " else " " & Label & "  "));
            end;
         end loop;
      end if;

      return Unbounded.To_String (Result);
   end Line;

   procedure Open_Tab (Self : in out Tab_Set; Browser : in out Model.Browser) is
      Current : Model.Pane renames Browser.Panes (Model.Current_Pane);
      Fresh   : Model.Browser;
   begin
      Self.Browsers (Self.Active) := Browser;
      Fresh.Last_Generation := Browser.Last_Generation;
      Fresh.Show_Hidden := Browser.Show_Hidden;
      Fresh.Order := Browser.Order;
      Model.Open (Fresh, Unbounded.To_String (Current.Path));
      Fresh.Panes (Model.Current_Pane).Wanted := Unbounded.To_Unbounded_String (Model.Selected_Name (Current));
      Self.Browsers.Insert (Self.Active + 1, Fresh);
      Self.Active := Self.Active + 1;
      Browser := Fresh;
   end Open_Tab;

   procedure Start (Self : in out Tab_Set; Browser : Model.Browser) is
   begin
      Self.Browsers.Clear;
      Self.Browsers.Append (Browser);
      Self.Active := 1;
   end Start;

   procedure Switch_To (Self : in out Tab_Set; Browser : in out Model.Browser; To : Positive) is
   begin
      if To /= Self.Active and then To <= Count (Self) then
         Self.Browsers (Self.Active) := Browser;
         Self.Active := To;
         Take_Over (Browser, Self.Browsers (To));
      end if;
   end Switch_To;

   procedure Take_Over (Browser : in out Model.Browser; Next : Model.Browser) is
      Generation : constant Natural := Browser.Last_Generation;
   begin
      Browser := Next;
      Browser.Last_Generation := Natural'Max (Generation, Browser.Last_Generation);
      Model.Reload_All (Browser);
   end Take_Over;
end Explore.Tabs;
