with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Input;

package body Input_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Input renames Explore.Input;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Input.Event_Kind;
   use type Input.Key_Kind;
   use type Input.Modifiers;
   use type Input.Mouse_Action;
   use type Input.Mouse_Button;
   use type Input.Reply_Kind;
   use type Unbounded.Unbounded_String;

   ESC : constant Character := Character'Val (27);
   CSI : constant String := ESC & "[";

   Control : constant Input.Modifiers := (Control => True, others => False);
   Alt     : constant Input.Modifiers := (Alt => True, others => False);

   --  The one event Text decodes to; it must decode to exactly one.
   function Only (Text : String; Label : String) return Input.Event;

   procedure Expect_Key
     (Text   : String;
      Key    : Input.Key_Kind;
      Label  : String;
      Mods   : Input.Modifiers := Input.No_Modifiers;
      Number : Natural := 0);

   procedure Expect_Character
     (Text  : String;
      Code  : Wide_Wide_Character;
      Label : String;
      Mods  : Input.Modifiers := Input.No_Modifiers);

   procedure Expect_Nothing (Decoder : in out Input.Decoder; Label : String);

   procedure Expect_Character
     (Text  : String;
      Code  : Wide_Wide_Character;
      Label : String;
      Mods  : Input.Modifiers := Input.No_Modifiers)
   is
      Item : constant Input.Event := Only (Text, Label);
   begin
      AUnit.Assertions.Assert
        (Item.Kind = Input.Key_Event
         and then Item.Key = Input.Character_Key
         and then Item.Code = Code
         and then Item.Mods = Mods,
         Label);
   end Expect_Character;

   procedure Expect_Key
     (Text   : String;
      Key    : Input.Key_Kind;
      Label  : String;
      Mods   : Input.Modifiers := Input.No_Modifiers;
      Number : Natural := 0)
   is
      Item : constant Input.Event := Only (Text, Label);
   begin
      AUnit.Assertions.Assert
        (Item.Kind = Input.Key_Event
         and then Item.Key = Key
         and then Item.Mods = Mods
         and then Item.Number = Number,
         Label);
   end Expect_Key;

   procedure Expect_Nothing (Decoder : in out Input.Decoder; Label : String) is
      Item  : Input.Event;
      Found : Boolean;
   begin
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert (not Found, Label);
   end Expect_Nothing;

   function Only (Text : String; Label : String) return Input.Event is
      Decoder : Input.Decoder;
      Item    : Input.Event;
      Found   : Boolean;
   begin
      Input.Feed (Decoder, Text);
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert (Found, Label & ": decodes");
      Expect_Nothing (Decoder, Label & ": nothing after it");
      AUnit.Assertions.Assert (not Input.Has_Pending (Decoder), Label & ": every byte used");
      return Item;
   end Only;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:plain keys", Test_Plain_Keys'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:legacy sequences", Test_Legacy_Sequences'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:progressive keys", Test_Progressive_Keys'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:escape ambiguity", Test_Escape_Ambiguity'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:split sequences", Test_Split_Sequences'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:mouse", Test_Mouse'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:resize", Test_Resize'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:paste", Test_Paste'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:replies", Test_Replies'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("input:unknown sequences", Test_Unknown_Sequences'Access));
      return Result;
   end Suite;

   procedure Test_Escape_Ambiguity (T : in out Fixture) is
      pragma Unreferenced (T);
      Decoder : Input.Decoder;
      Item    : Input.Event;
      Found   : Boolean;
   begin
      Input.Feed (Decoder, [1 => ESC]);
      Expect_Nothing (Decoder, "a lone ESC waits for what may follow");
      Input.Flush (Decoder);
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Key_Event and then Item.Key = Input.Escape,
         "after a pause it is the Escape key");

      Input.Feed (Decoder, CSI & "1;");
      Input.Flush (Decoder);
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Key_Event and then Item.Key = Input.Escape,
         "an unfinished sequence after a pause starts with an Escape key");

      for Rest of String'("[1;") loop
         Input.Next (Decoder, Item, Found);
         AUnit.Assertions.Assert
           (Found and then Input.Is_Character (Item, Wide_Wide_Character'Val (Character'Pos (Rest))),
            "the rest of it is what was typed after Escape");
      end loop;

      Input.Feed (Decoder, ESC & ESC & "j");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Key_Event and then Item.Key = Input.Escape,
         "ESC ESC is an Escape key first");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Key_Event and then Item.Code = 'j' and then Item.Mods = Alt,
         "and then Alt with what follows");
   end Test_Escape_Ambiguity;

   procedure Test_Legacy_Sequences (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Expect_Key (CSI & "A", Input.Up, "CSI A");
      Expect_Key (ESC & "OB", Input.Down, "SS3 B");
      Expect_Key (CSI & "1;5C", Input.Right, "Ctrl+Right", Control);
      Expect_Key (CSI & "1;3D", Input.Left, "Alt+Left", Alt);
      Expect_Key (CSI & "H", Input.Home, "CSI H");
      Expect_Key (CSI & "4~", Input.End_Key, "CSI 4 ~");
      Expect_Key (CSI & "5~", Input.Page_Up, "CSI 5 ~");
      Expect_Key (CSI & "6~", Input.Page_Down, "CSI 6 ~");
      Expect_Key (CSI & "3;5~", Input.Delete, "Ctrl+Delete", Control);
      Expect_Key (ESC & "OP", Input.Function_Key, "F1", Number => 1);
      Expect_Key (CSI & "15~", Input.Function_Key, "F5", Number => 5);
      Expect_Key (CSI & "24~", Input.Function_Key, "F12", Number => 12);
      Expect_Key (CSI & "Z", Input.Tab, "Shift+Tab", (Shift => True, others => False));
   end Test_Legacy_Sequences;

   procedure Test_Mouse (T : in out Fixture) is
      pragma Unreferenced (T);
      Item : Input.Event;
   begin
      Item := Only (CSI & "<0;10;5M", "left press");
      AUnit.Assertions.Assert
        (Item.Kind = Input.Mouse_Event
         and then Item.Button = Input.Left_Button
         and then Item.Action = Input.Press
         and then Item.Row = 5
         and then Item.Column = 10,
         "left press at row 5 column 10");

      Item := Only (CSI & "<2;1;1m", "right release");
      AUnit.Assertions.Assert
        (Item.Button = Input.Right_Button and then Item.Action = Input.Release, "right release");

      Item := Only (CSI & "<32;3;4M", "drag");
      AUnit.Assertions.Assert
        (Item.Button = Input.Left_Button and then Item.Action = Input.Drag, "left drag");

      Item := Only (CSI & "<64;1;1M", "wheel up");
      AUnit.Assertions.Assert (Item.Button = Input.Wheel_Up, "wheel up");

      Item := Only (CSI & "<81;1;1M", "ctrl wheel down");
      AUnit.Assertions.Assert
        (Item.Button = Input.Wheel_Down and then Item.Mouse_Mods = Control, "ctrl wheel down");
   end Test_Mouse;

   procedure Test_Paste (T : in out Fixture) is
      pragma Unreferenced (T);
      Decoder : Input.Decoder;
      Item    : Input.Event;
      Found   : Boolean;
   begin
      Item := Only (CSI & "200~hello " & CSI & "A world" & CSI & "201~", "paste");
      AUnit.Assertions.Assert
        (Item.Kind = Input.Paste_Event and then Item.Text = "hello " & CSI & "A world",
         "pasted text is taken as is, sequences and all");

      Input.Feed (Decoder, CSI & "200~part");
      Input.Flush (Decoder);
      Expect_Nothing (Decoder, "a paste is never cut short by a pause");
      Input.Feed (Decoder, " two" & CSI & "201~q");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Paste_Event and then Item.Text = "part two", "paste completes");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert (Found and then Input.Is_Character (Item, 'q'), "the key after it");

      --  Longer than any escape sequence, and read in more than one piece.
      declare
         Long : constant String (1 .. 10_000) := (others => 'd');
      begin
         Input.Feed (Decoder, CSI & "200~" & Long (1 .. 5_000));
         Input.Next (Decoder, Item, Found);
         AUnit.Assertions.Assert (not Found, "a long paste waits for its end, its text not taken for keys");
         Input.Feed (Decoder, Long (5_001 .. Long'Last) & CSI & "201~");
         Input.Next (Decoder, Item, Found);
         AUnit.Assertions.Assert
           (Found and then Item.Kind = Input.Paste_Event and then Item.Text = Long, "a long paste arrives whole");
      end;
   end Test_Paste;

   procedure Test_Plain_Keys (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Expect_Character ("q", 'q', "q");
      Expect_Character ("Q", 'Q', "Q");
      Expect_Character (Character'Val (16#C3#) & Character'Val (16#A6#), Wide_Wide_Character'Val (16#E6#), "ae");
      Expect_Character
        (Character'Val (16#F0#) & Character'Val (16#9F#) & Character'Val (16#98#) & Character'Val (16#80#),
         Wide_Wide_Character'Val (16#1F600#),
         "four-byte character");
      Expect_Character ([1 => Character'Val (3)], 'c', "Ctrl+C is a key in raw mode", Control);
      Expect_Character (ESC & "x", 'x', "Alt+x", Alt);
      Expect_Key ([1 => Character'Val (13)], Input.Enter, "CR");
      Expect_Key ([1 => Character'Val (9)], Input.Tab, "HT");
      Expect_Key ([1 => Character'Val (127)], Input.Backspace, "DEL");
   end Test_Plain_Keys;

   procedure Test_Progressive_Keys (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Expect_Key (CSI & "27u", Input.Escape, "Escape without ambiguity");
      Expect_Key (CSI & "13u", Input.Enter, "Enter");
      Expect_Key (CSI & "9;2u", Input.Tab, "Shift+Tab", (Shift => True, others => False));
      Expect_Character (CSI & "97;5u", 'a', "Ctrl+a", Control);
      Expect_Character (CSI & "105;5u", 'i', "Ctrl+i is not Tab", Control);
      Expect_Character (CSI & "97:65;2u", 'a', "alternate keys are sub-parameters", (Shift => True, others => False));
   end Test_Progressive_Keys;

   procedure Test_Replies (T : in out Fixture) is
      pragma Unreferenced (T);
      Item : Input.Event;
   begin
      Item := Only (ESC & "]7701;v=1;caps=kgfx" & ESC & "\", "identity reply");
      AUnit.Assertions.Assert
        (Item.Kind = Input.Reply_Event
         and then Item.Reply = Input.Identity_Reply
         and then Item.Payload = "v=1;caps=kgfx",
         "identity reply body");

      Item := Only (ESC & "]7701;v=1" & Character'Val (7), "identity reply ended by BEL");
      AUnit.Assertions.Assert (Item.Reply = Input.Identity_Reply and then Item.Payload = "v=1", "BEL ends it too");

      Item := Only (ESC & "P>|bracke-terminal 0.1.0" & ESC & "\", "version reply");
      AUnit.Assertions.Assert
        (Item.Reply = Input.Version_Reply and then Item.Payload = "bracke-terminal 0.1.0", "version reply body");

      Item := Only (CSI & "?62;4;22c", "device attributes");
      AUnit.Assertions.Assert
        (Item.Reply = Input.Device_Attributes_Reply and then Item.Payload = "62;4;22", "device attributes body");
   end Test_Replies;

   procedure Test_Resize (T : in out Fixture) is
      pragma Unreferenced (T);
      Item : constant Input.Event := Only (CSI & "48;30;100;600;1000t", "in-band resize");
   begin
      AUnit.Assertions.Assert
        (Item.Kind = Input.Resize_Event
         and then Item.Rows = 30
         and then Item.Columns = 100
         and then Item.Pixel_Height = 600
         and then Item.Pixel_Width = 1000,
         "rows, columns, and pixels");
   end Test_Resize;

   procedure Test_Split_Sequences (T : in out Fixture) is
      pragma Unreferenced (T);
      Decoder : Input.Decoder;
      Item    : Input.Event;
      Found   : Boolean;
   begin
      Input.Feed (Decoder, ESC & "[");
      Expect_Nothing (Decoder, "half a sequence");
      Input.Feed (Decoder, "1;5");
      Expect_Nothing (Decoder, "still half");
      Input.Feed (Decoder, "Aj");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Key = Input.Up and then Item.Mods = Control, "completed by the next read");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert (Found and then Input.Is_Character (Item, 'j'), "and what followed it");

      Input.Feed (Decoder, [1 => Character'Val (16#C3#)]);
      Expect_Nothing (Decoder, "half a character");
      Input.Feed (Decoder, [1 => Character'Val (16#B8#)]);
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Code = Wide_Wide_Character'Val (16#F8#), "a character split across reads");

      Input.Feed (Decoder, ESC & "]7701;v=1");
      Input.Flush (Decoder);
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Item.Kind = Input.Key_Event and then Item.Key = Input.Escape,
         "an unterminated reply after a pause is given up on");
   end Test_Split_Sequences;

   procedure Test_Unknown_Sequences (T : in out Fixture) is
      pragma Unreferenced (T);
      Decoder : Input.Decoder;
      Item    : Input.Event;
      Found   : Boolean;
   begin
      Input.Feed
        (Decoder,
         CSI & "?1;2$y"                      --  a mode report explore never asked for
         & ESC & "]11;rgb:0/0/0" & ESC & "\" --  an OSC it has no use for
         & Character'Val (16#FF#)            --  a byte UTF-8 never uses
         & CSI & "57399u"                    --  a functional key it ignores
         & "a");
      Input.Next (Decoder, Item, Found);
      AUnit.Assertions.Assert
        (Found and then Input.Is_Character (Item, 'a'), "what explore cannot use is skipped, not misread");
      AUnit.Assertions.Assert (not Input.Has_Pending (Decoder), "and consumed");
   end Test_Unknown_Sequences;
end Input_Tests;
