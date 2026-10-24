with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Fixed;
with E2E_Rig;
with Terminal.Core;

package body Session_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);

   use type Ada.Directories.File_Size;

   CR : constant Character := Character'Val (13);

   subtype Terminal_Modes is Terminal.Core.Mode_Snapshot;

   type Natural_Array is array (Positive range <>) of Natural;

   --  A PNG of one pixel.
   function Tiny_PNG return String is
     ([for Code of Natural_Array'
         [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#, 16#00#, 16#00#, 16#00#, 16#0D#, 16#49#,
          16#48#, 16#44#, 16#52#, 16#00#, 16#00#, 16#00#, 16#01#, 16#00#, 16#00#, 16#00#, 16#01#, 16#08#, 16#06#,
          16#00#, 16#00#, 16#00#, 16#1F#, 16#15#, 16#C4#, 16#89#, 16#00#, 16#00#, 16#00#, 16#0D#, 16#49#, 16#44#,
          16#41#, 16#54#, 16#78#, 16#9C#, 16#63#, 16#F8#, 16#CF#, 16#C0#, 16#F0#, 16#1F#, 16#00#, 16#05#, 16#00#,
          16#01#, 16#FF#, 16#89#, 16#99#, 16#3D#, 16#1D#, 16#00#, 16#00#, 16#00#, 16#00#, 16#49#, 16#45#, 16#4E#,
          16#44#, 16#AE#, 16#42#, 16#60#, 16#82#]
       => Character'Val (Code)]);

   --  Start explore on Directory and wait for its first full frame.
   procedure Open (Session : in out E2E_Rig.Rig; Directory : String; Columns : Positive := 100);

   --  Quit, and check that the terminal was handed back as it was found.
   procedure Quit (Session : in out E2E_Rig.Rig);

   procedure Open (Session : in out E2E_Rig.Rig; Directory : String; Columns : Positive := 100) is
   begin
      E2E_Rig.Start (Session, Directory, Columns => Columns);
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For (Session, "q quit"), "explore drew its screen:" & E2E_Rig.Screen (Session));
   end Open;

   procedure Quit (Session : in out E2E_Rig.Rig) is
      Ended : Boolean;
      Code  : Integer;
   begin
      E2E_Rig.Send (Session, "q");
      E2E_Rig.Wait_Exit (Session, Ended, Code);
      E2E_Rig.Stop (Session);
      AUnit.Assertions.Assert (Ended and then Code = 0, "explore quit with status 0, not" & Integer'Image (Code));
   end Quit;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:start and quit", Test_Start_And_Quit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:browse and preview", Test_Browse_And_Preview'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:copy", Test_Copy'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:resize", Test_Resize'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:clipboard", Test_Clipboard'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:image", Test_Image'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:shell command", Test_Shell_Command'Access));
      return Result;
   end Suite;

   procedure Test_Browse_And_Preview (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("browse");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/beta/inner");
      E2E_Rig.Write_File (Root & "/alpha.txt", "the first line" & Character'Val (10) & "the second");
      Open (Session, Root);

      --  Directories come first: beta is selected, and its listing previewed.
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "inner/"), "beta's listing:" & E2E_Rig.Screen (Session));

      E2E_Rig.Send (Session, "j");
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For (Session, "the first line") and then E2E_Rig.Wait_For (Session, "the second"),
         "the text file previewed:" & E2E_Rig.Screen (Session));

      E2E_Rig.Send (Session, "k" & "l");
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For_Row (Session, 1, Root & "/beta"), "into beta:" & E2E_Rig.Screen (Session));

      E2E_Rig.Send (Session, "h");
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For_Row (Session, 1, Root) and then E2E_Rig.Wait_For (Session, "alpha.txt"),
         "and back:" & E2E_Rig.Screen (Session));
      Quit (Session);
   end Test_Browse_And_Preview;

   procedure Test_Clipboard (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("clipboard");
      Session : E2E_Rig.Rig;
   begin
      E2E_Rig.Write_File (Root & "/item", "");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "item"), "listed");

      E2E_Rig.Send (Session, "cc");
      E2E_Rig.Pump (Session, 200);
      AUnit.Assertions.Assert
        (E2E_Rig.Clipboard (Session) = Root & "/item",
         "the terminal put the selected path on the clipboard: " & E2E_Rig.Clipboard (Session));
      Quit (Session);
   end Test_Clipboard;

   procedure Test_Copy (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("copy");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/target");
      E2E_Rig.Write_File (Root & "/source.txt", "copied text");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "source.txt"), "listed:" & E2E_Rig.Screen (Session));

      --  Yank the file, go into target, and paste.
      E2E_Rig.Send (Session, "j");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "y");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "k");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "l");
      AUnit.Assertions.Assert (E2E_Rig.Wait_For_Row (Session, 1, Root & "/target"), "into target");
      E2E_Rig.Send (Session, "p");

      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For (Session, "source.txt") and then E2E_Rig.Wait_For (Session, "copied"),
         "the copy listed, and reported done:" & E2E_Rig.Screen (Session));
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Root & "/target/source.txt")
         and then Ada.Directories.Size (Root & "/target/source.txt") = 11,
         "and on disk, whole");
      Quit (Session);
   end Test_Copy;

   procedure Test_Image (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("image");
      Session : E2E_Rig.Rig;
   begin
      E2E_Rig.Write_File (Root & "/dot.png", Tiny_PNG);
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "dot.png"), "listed");

      for Step in 1 .. 300 loop
         exit when E2E_Rig.Placeholder_Cells (Session) > 0;
         E2E_Rig.Pump (Session, 10);
      end loop;

      AUnit.Assertions.Assert (E2E_Rig.Graphics_Count (Session) > 0, "the image was sent as Kitty graphics");
      AUnit.Assertions.Assert
        (E2E_Rig.Placeholder_Cells (Session) > 0, "and placed in the preview pane with placeholders");
      Quit (Session);
   end Test_Image;

   procedure Test_Resize (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("resize");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/only");
      Open (Session, Root);

      E2E_Rig.Resize (Session, 30, 60);
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For_Row (Session, 30, "q quit"), "the status line moved to the new last row:"
         & E2E_Rig.Screen (Session));
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (E2E_Rig.Row (Session, 2), "only/") in 1 .. 4,
         "below 80 columns the current pane is the first:" & E2E_Rig.Screen (Session));
      Quit (Session);
   end Test_Resize;

   procedure Test_Shell_Command (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("shell");
      Session : E2E_Rig.Rig;
   begin
      E2E_Rig.Write_File (Root & "/one", "");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "one"), "listed");

      --  The command runs with the terminal handed to it, and explore waits
      --  for Enter before taking it back.
      E2E_Rig.Send (Session, "!");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "echo ran; touch made" & CR);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "press Enter"), "waits:" & E2E_Rig.Screen (Session));
      AUnit.Assertions.Assert
        (not E2E_Rig.Modes (Session).Alternate_Screen and then E2E_Rig.Wait_For (Session, "ran"),
         "on the main screen, with the command's output");
      E2E_Rig.Send (Session, "" & CR);
      AUnit.Assertions.Assert
        (E2E_Rig.Wait_For (Session, "made") and then E2E_Rig.Modes (Session).Alternate_Screen,
         "back, with what the command made listed:" & E2E_Rig.Screen (Session));
      AUnit.Assertions.Assert (Ada.Directories.Exists (Root & "/made"), "made in the directory shown");
      Quit (Session);
   end Test_Shell_Command;

   procedure Test_Start_And_Quit (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("start");
      Session : E2E_Rig.Rig;
      Ended   : Boolean;
      Code    : Integer;
   begin
      E2E_Rig.Write_File (Root & "/file", "");
      Open (Session, Root);

      declare
         Now : constant Terminal_Modes := E2E_Rig.Modes (Session);
      begin
         AUnit.Assertions.Assert
           (Now.Alternate_Screen and then Now.Mouse_SGR and then Now.Bracketed_Paste and then Now.Focus_Reporting
            and then Now.In_Band_Resize and then Now.Keyboard_Flags = 1,
            "the alternate screen, mouse, paste, focus, resize reports, and disambiguated keys");
      end;

      AUnit.Assertions.Assert (E2E_Rig.Row (Session, 1) = " " & Root, "the directory on the first line");

      E2E_Rig.Send (Session, "q");
      E2E_Rig.Wait_Exit (Session, Ended, Code);

      declare
         After : constant Terminal_Modes := E2E_Rig.Modes (Session);
      begin
         AUnit.Assertions.Assert (Ended and then Code = 0, "quit with status 0");
         AUnit.Assertions.Assert
           (not After.Alternate_Screen and then not After.Mouse_SGR and then not After.Mouse_Button
            and then not After.Bracketed_Paste and then not After.Focus_Reporting and then not After.In_Band_Resize
            and then After.Keyboard_Flags = 0 and then After.Cursor_Visible,
            "every mode turned off again, and the cursor shown");
      end;

      E2E_Rig.Stop (Session);
   end Test_Start_And_Quit;
end Session_Tests;
