with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Explore.Model;
with Explore.Render;
with Explore.Screen;
with Posix_Tools.File_Operations.Listing;

package body Render_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Render renames Explore.Render;
   package Screen renames Explore.Screen;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Render.Area;
   use type Render.Pane_Place;

   --  An ellipsis, as UTF-8.
   Ellipsis : constant String := Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#A6#);

   --  A browser showing Path, its current pane holding one file whose
   --  status is known.
   function Browsing (Path : String) return Model.Browser;

   --  Draw Browser with Context on a screen of Rows by Columns, and give back
   --  the row Row as UTF-8, trailing blanks dropped.
   function Drawn_Row
     (Browser : Model.Browser;
      Context : Render.Frame_Context;
      Rows    : Positive;
      Columns : Positive;
      Row     : Positive) return String;

   --  The labels a frame needs, as in English.
   function Context return Render.Frame_Context;

   function Ends_With (Text, Suffix : String) return Boolean is
     (Text'Length >= Suffix'Length and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

   function Browsing (Path : String) return Model.Browser is
      Result  : Model.Browser;
      Entries : Listing.Entry_Vectors.Vector;
   begin
      Model.Open (Result, Path);
      Entries.Append
        (Listing.Listed_Entry'
           (Name   => Unbounded.To_Unbounded_String ("file"),
            Kind   => Listing.Regular_Entry,
            Status => (Available => True, Size => 1234, Modified_Seconds => 0, Mode => 8#100644#, others => 0),
            others => <>));
      Model.Deliver (Result, Model.Current_Pane, Result.Panes (Model.Current_Pane).Generation, Entries, True);
      return Result;
   end Browsing;

   function Context return Render.Frame_Context is
      Result : Render.Frame_Context;
   begin
      Result.Text.Quit_Hint := Unbounded.To_Unbounded_String ("q quit");
      Result.Owner := Unbounded.To_Unbounded_String ("someone:staff");
      return Result;
   end Context;

   function Drawn_Row
     (Browser : Model.Browser;
      Context : Render.Frame_Context;
      Rows    : Positive;
      Columns : Positive;
      Row     : Positive) return String
   is
      Grid  : Screen.Grid;
      Text  : Wide_Wide_String (1 .. Columns);
      Last  : Natural := 0;
   begin
      Screen.Resize (Grid, Rows, Columns);
      Render.Draw (Grid, Browser, Context);

      for Column in 1 .. Columns loop
         if not Screen.Cell_At (Grid, Row, Column).Continuation then
            Last := Last + 1;
            Text (Last) := Screen.Cell_At (Grid, Row, Column).Code;
         end if;
      end loop;

      return Ada.Strings.Fixed.Trim
        (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text (1 .. Last)), Ada.Strings.Right);
   end Drawn_Row;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("render:layout", Test_Layout'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("render:header", Test_Header'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("render:status gives way", Test_Status_Gives_Way'Access));
      return Result;
   end Suite;

   procedure Test_Header (T : in out Fixture) is
      pragma Unreferenced (T);
      Long : constant String := "/home/someone/projects/a-rather-long-name/and/deeper/still/target";
   begin
      AUnit.Assertions.Assert
        (Drawn_Row (Browsing ("/home/u"), Context, 10, 60, 1) = " /home/u", "a path that fits is shown whole");

      declare
         Header : constant String := Drawn_Row (Browsing (Long), Context, 10, 30, 1);
      begin
         AUnit.Assertions.Assert
           (Header'Length > 1 + Ellipsis'Length
            and then Header (Header'First .. Header'First + Ellipsis'Length) = " " & Ellipsis
            and then Ends_With (Long, Header (Header'First + 1 + Ellipsis'Length .. Header'Last))
            and then Ends_With (Header, "/still/target"),
            "a path too long keeps its end, after an ellipsis: " & Header);
         AUnit.Assertions.Assert
           (Header'Length - Ellipsis'Length + 1 = 30, "and fills the row after the margin: " & Header);
      end;
   end Test_Header;

   procedure Test_Layout (T : in out Fixture) is
      pragma Unreferenced (T);
      Wide   : constant Render.Layout := Render.Layout_For (24, 100);
      Middle : constant Render.Layout := Render.Layout_For (24, 60);
      Narrow : constant Render.Layout := Render.Layout_For (24, 40);
   begin
      AUnit.Assertions.Assert
        (Wide.First_Row = 2 and then Wide.Height = 22, "the panes between the title and the status line");
      AUnit.Assertions.Assert
        (Wide.Places (Model.Parent_Pane) = (True, 1, 12)
         and then Wide.Places (Model.Current_Pane) = (True, 14, 50)
         and then Wide.Places (Model.Preview_Pane) = (True, 65, 36),
         "three panes from 80 columns, a column apart, filling the width");
      AUnit.Assertions.Assert
        (not Middle.Places (Model.Parent_Pane).Shown
         and then Middle.Places (Model.Current_Pane) = (True, 1, 29)
         and then Middle.Places (Model.Preview_Pane) = (True, 31, 30),
         "the current and the preview from 50");
      AUnit.Assertions.Assert
        (not Narrow.Places (Model.Parent_Pane).Shown and then not Narrow.Places (Model.Preview_Pane).Shown
         and then Narrow.Places (Model.Current_Pane) = (True, 1, 40),
         "the current alone below that");
      AUnit.Assertions.Assert (Render.Layout_For (2, 100).Height = 0, "no room for panes on two rows");
      AUnit.Assertions.Assert
        (Render.Content_Area (Wide) = (Row => 3, Column => 66, Rows => 21, Columns => 34),
         "a file's content below its description, inside the preview's margin");
      AUnit.Assertions.Assert
        (Render.Content_Area (Narrow) = (others => <>), "and nowhere without a preview");
   end Test_Layout;

   procedure Test_Status_Gives_Way (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : constant Model.Browser := Browsing ("/d");
      Said    : Render.Frame_Context := Context;
   begin
      --  The selected entry's details give way to the position and the hint.
      declare
         Status : constant String := Drawn_Row (Browser, Context, 5, 30, 5);
      begin
         AUnit.Assertions.Assert
           (Ends_With (Status, "1/1  q quit") and then Status (Status'First .. Status'First + 4) = " -rw-",
            "details cut short beside the position: " & Status);
      end;

      --  A message keeps all the room it needs, and the right side gives way.
      Said.Message := Unbounded.To_Unbounded_String ("a message far too long to leave room");
      declare
         Status : constant String := Drawn_Row (Browser, Said, 5, 30, 5);
      begin
         AUnit.Assertions.Assert
           (Status = " a message far too long to lea" and then Ada.Strings.Fixed.Index (Status, "q quit") = 0,
            "a long message takes the whole line: " & Status);
      end;

      Said.Message := Unbounded.To_Unbounded_String ("done");
      declare
         Status : constant String := Drawn_Row (Browser, Said, 5, 30, 5);
      begin
         AUnit.Assertions.Assert
           (Status (Status'First .. Status'First + 4) = " done" and then Ends_With (Status, "1/1  q quit"),
            "a short one leaves room for the right side: " & Status);
      end;

      --  A question is shown in place of everything on the left.
      Said.Message := Unbounded.Null_Unbounded_String;
      Said.Question := Unbounded.To_Unbounded_String ("delete 1? y/n");
      AUnit.Assertions.Assert
        (Drawn_Row (Browser, Said, 5, 30, 5) (1 .. 14) = " delete 1? y/n", "a question on the left");
   end Test_Status_Gives_Way;
end Render_Tests;
