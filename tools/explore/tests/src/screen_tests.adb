with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Fixed;
with Explore.Format;
with Explore.Screen;
with Posix_Tools.File_Operations.Listing;

package body Screen_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Screen renames Explore.Screen;

   ESC : constant Character := Character'Val (27);

   --  The characters of a row, continuation cells left out.
   function Row_Text (Grid : Screen.Grid; Row : Positive) return Wide_Wide_String;

   function Row_Text (Grid : Screen.Grid; Row : Positive) return Wide_Wide_String is
      Result : Wide_Wide_String (1 .. Screen.Columns (Grid));
      Last   : Natural := 0;
   begin
      for Column in 1 .. Screen.Columns (Grid) loop
         if not Screen.Cell_At (Grid, Row, Column).Continuation then
            Last := Last + 1;
            Result (Last) := Screen.Cell_At (Grid, Row, Column).Code;
         end if;
      end loop;

      return Result (1 .. Last);
   end Row_Text;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("screen:put and clip", Test_Put_And_Clip'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("screen:wide characters", Test_Wide_Characters'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("screen:render writes only changes", Test_Render_Writes_Only_Changes'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("format:sizes times modes", Test_Format'Access));
      return Result;
   end Suite;

   procedure Test_Format (T : in out Fixture) is
      pragma Unreferenced (T);
      package Listing renames Posix_Tools.File_Operations.Listing;
      Item : Listing.Listed_Entry;
   begin
      AUnit.Assertions.Assert (Explore.Format.Size_Image (0) = "0", "zero");
      AUnit.Assertions.Assert (Explore.Format.Size_Image (1023) = "1023", "bytes below a K");
      AUnit.Assertions.Assert (Explore.Format.Size_Image (1536) = "1.5K", "one and a half K");
      AUnit.Assertions.Assert (Explore.Format.Size_Image (20 * 1024 * 1024) = "20M", "whole units above ten");
      AUnit.Assertions.Assert (Explore.Format.Size_Image (Long_Long_Integer'Last) = "7.9E", "the largest size");
      AUnit.Assertions.Assert (Explore.Format.Time_Image (0)'Length = 16, "a time is YYYY-MM-DD HH:MM");

      Item.Kind := Listing.Directory_Entry;
      Item.Status := (Available => True, Mode => 8#40755#, others => <>);
      AUnit.Assertions.Assert (Explore.Format.Mode_Image (Item) = "drwxr-xr-x", "directory mode");
      Item.Is_Link := True;
      AUnit.Assertions.Assert (Explore.Format.Mode_Image (Item) (1) = 'l', "a link shows as one");
      Item.Status.Available := False;
      AUnit.Assertions.Assert (Explore.Format.Mode_Image (Item) = "l?????????", "unknown permissions");
   end Test_Format;

   procedure Test_Put_And_Clip (T : in out Fixture) is
      pragma Unreferenced (T);
      Grid : Screen.Grid;
      Used : Natural;
   begin
      Screen.Resize (Grid, 2, 10);
      Screen.Put (Grid, 1, 3, "hello world", Screen.Plain, 5, Used);
      AUnit.Assertions.Assert (Used = 5 and then Row_Text (Grid, 1) = "  hello   ", "clipped to its width");

      Screen.Put (Grid, 2, 8, "abcdef", Screen.Plain, 10, Used);
      AUnit.Assertions.Assert (Used = 3 and then Row_Text (Grid, 2) = "       abc", "clipped to the grid");

      Screen.Put (Grid, 2, 1, "a" & Character'Val (9) & "b", Screen.Plain, 3, Used);
      AUnit.Assertions.Assert (Row_Text (Grid, 2) (1 .. 3) = "a?b", "control characters show as '?'");

      Screen.Put (Grid, 3, 1, "off the grid", Screen.Plain, 10, Used);
      AUnit.Assertions.Assert (Used = 0, "rows beyond the grid are not written");

      AUnit.Assertions.Assert (Screen.Width_Of ("caf" & Character'Val (16#C3#) & Character'Val (16#A9#)) = 4, "é");
      AUnit.Assertions.Assert
        (Screen.Clipped ("ab" & Character'Val (16#C3#) & Character'Val (16#A9#) & "cd", 3)
         = "ab" & Character'Val (16#C3#) & Character'Val (16#A9#),
         "clipping never cuts a character");
   end Test_Put_And_Clip;

   procedure Test_Render_Writes_Only_Changes (T : in out Fixture) is
      pragma Unreferenced (T);
      Shown  : Screen.Grid;
      Wanted : Screen.Grid;
      Used   : Natural;
   begin
      Screen.Resize (Wanted, 3, 20);
      Screen.Put (Wanted, 1, 1, "first", Screen.Plain, 20, Used);
      Screen.Put (Wanted, 3, 1, "third", (Bold => True, others => <>), 20, Used);

      declare
         Output : constant String := Screen.Render (Shown, Wanted);
      begin
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (Output, ESC & "[2J") > 0, "a grid of a new size is drawn whole");
         AUnit.Assertions.Assert (Ada.Strings.Fixed.Index (Output, ESC & "[0;1m") > 0, "bold");
      end;

      AUnit.Assertions.Assert (Screen.Render (Shown, Wanted) = "", "nothing changed, nothing written");

      Screen.Put (Wanted, 1, 2, "a", Screen.Plain, 1, Used);

      declare
         Output : constant String := Screen.Render (Shown, Wanted);
      begin
         AUnit.Assertions.Assert
           (Output = ESC & "[1;2H" & ESC & "[0ma" & ESC & "[0m", "one cell changed, one cell written: " & Output);
      end;

      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Screen.Render (Shown, Wanted, Full => True), "third") > 0,
         "a full render writes everything again");
   end Test_Render_Writes_Only_Changes;

   procedure Test_Wide_Characters (T : in out Fixture) is
      pragma Unreferenced (T);
      Grid : Screen.Grid;
      Used : Natural;
      --  U+4E2D, two cells wide.
      Wide : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);
   begin
      Screen.Resize (Grid, 1, 5);
      Screen.Put (Grid, 1, 1, Wide & "x" & Wide, Screen.Plain, 4, Used);
      AUnit.Assertions.Assert (Used = 3, "a wide character that would not fit whole is left out");
      AUnit.Assertions.Assert
        (Screen.Cell_At (Grid, 1, 2).Continuation and then not Screen.Cell_At (Grid, 1, 3).Continuation,
         "a wide character takes its cell and the next");
      AUnit.Assertions.Assert (Screen.Width_Of (Wide & Wide) = 4, "width of wide characters");
   end Test_Wide_Characters;
end Screen_Tests;
