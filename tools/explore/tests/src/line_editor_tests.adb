with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Input;
with Explore.Line_Editor;

package body Line_Editor_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Editor renames Explore.Line_Editor;
   package Input renames Explore.Input;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Editor.Outcome;

   Control : constant Input.Modifiers := (Control => True, others => False);
   Alt     : constant Input.Modifiers := (Alt => True, others => False);

   function Character_Of (Code : Wide_Wide_Character; Mods : Input.Modifiers := Input.No_Modifiers) return Input.Event
   is ((Kind => Input.Key_Event, Key => Input.Character_Key, Code => Code, Mods => Mods, others => <>));

   function Key_Of (Key : Input.Key_Kind) return Input.Event is
     ((Kind => Input.Key_Event, Key => Key, others => <>));

   --  Edit Text with Item, expecting Expected, and give back what Text became.
   function Edited (Text : String; Item : Input.Event; Expected : Editor.Outcome; Label : String) return String;

   function Edited (Text : String; Item : Input.Event; Expected : Editor.Outcome; Label : String) return String is
      Line   : Unbounded.Unbounded_String := Unbounded.To_Unbounded_String (Text);
      Result : Editor.Outcome;
   begin
      Editor.Edit (Line, Item, Result);
      AUnit.Assertions.Assert (Result = Expected, Label & ": outcome " & Editor.Outcome'Image (Result));
      return Unbounded.To_String (Line);
   end Edited;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("line editor:typing", Test_Typing'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("line editor:backspace", Test_Backspace'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("line editor:ending keys", Test_Ending_Keys'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("line editor:paste", Test_Paste'Access));
      return Result;
   end Suite;

   procedure Test_Backspace (T : in out Fixture) is
      pragma Unreferenced (T);
      Accent : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Snow   : constant String := Character'Val (16#E2#) & Character'Val (16#98#) & Character'Val (16#83#);
   begin
      AUnit.Assertions.Assert
        (Edited ("ab", Key_Of (Input.Backspace), Editor.Typing, "ascii") = "a", "Backspace drops one byte of ASCII");
      AUnit.Assertions.Assert
        (Edited ("a" & Accent, Key_Of (Input.Backspace), Editor.Typing, "two bytes") = "a",
         "Backspace drops both bytes of a two-byte character");
      AUnit.Assertions.Assert
        (Edited (Accent & Snow, Key_Of (Input.Backspace), Editor.Typing, "three bytes") = Accent,
         "Backspace drops all three bytes, and only them");
      AUnit.Assertions.Assert
        (Edited ("", Key_Of (Input.Backspace), Editor.Typing, "empty") = "", "Backspace on nothing leaves nothing");
   end Test_Backspace;

   procedure Test_Ending_Keys (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Edited ("name", Key_Of (Input.Enter), Editor.Accepted, "enter") = "name", "Enter keeps the text");
      AUnit.Assertions.Assert
        (Edited ("name", Key_Of (Input.Escape), Editor.Escaped, "escape") = "name", "Escape keeps the text");
      AUnit.Assertions.Assert
        (Edited ("name", Character_Of ('c', Control), Editor.Interrupted, "control-c") = "name",
         "Control-C adds no c");
      AUnit.Assertions.Assert
        (Edited ("name", Key_Of (Input.Up), Editor.Typing, "up") = "name", "a key that types nothing changes nothing");
   end Test_Ending_Keys;

   procedure Test_Paste (T : in out Fixture) is
      pragma Unreferenced (T);
      Paste : constant Input.Event :=
        (Kind => Input.Paste_Event, Text => Unbounded.To_Unbounded_String ("two" & Character'Val (10) & "lines"));
   begin
      AUnit.Assertions.Assert
        (Edited ("x", Paste, Editor.Typing, "paste") = "xtwo" & Character'Val (10) & "lines",
         "a paste is added whole");
      AUnit.Assertions.Assert
        (Edited ("x", (Kind => Input.Focus_Event, Focused => True), Editor.Typing, "focus") = "x",
         "an event that is no key leaves the text alone");
   end Test_Paste;

   procedure Test_Typing (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Edited ("", Character_Of ('a'), Editor.Typing, "a") = "a", "a key adds its character");
      AUnit.Assertions.Assert
        (Edited ("a", Character_Of (Wide_Wide_Character'Val (16#E9#)), Editor.Typing, "e acute")
         = "a" & Character'Val (16#C3#) & Character'Val (16#A9#),
         "a character is added in UTF-8");
      AUnit.Assertions.Assert
        (Edited ("a", Character_Of ('x', Alt), Editor.Typing, "alt") = "a", "a key with Alt adds nothing");
      AUnit.Assertions.Assert
        (Edited ("a", Character_Of ('u', Control), Editor.Typing, "control") = "a", "a key with Control adds nothing");
   end Test_Typing;
end Line_Editor_Tests;
