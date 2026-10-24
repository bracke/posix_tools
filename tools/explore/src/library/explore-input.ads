with Ada.Strings.Unbounded;

--  Turning the bytes the terminal sends into events.
--
--  The decoder keeps whatever it has been fed and has not yet decoded, so a
--  sequence split across two reads decodes once its second half arrives. A
--  lone ESC is ambiguous between the Escape key and the start of a sequence;
--  it stays pending until Flush says no more is coming, which the caller does
--  when a read times out. With disambiguated keys on, the terminal sends the
--  Escape key as a sequence of its own and the question does not arise.
package Explore.Input is
   type Key_Kind is
     (Character_Key,
      Enter,
      Tab,
      Backspace,
      Escape,
      Up,
      Down,
      Left,
      Right,
      Home,
      End_Key,
      Page_Up,
      Page_Down,
      Insert,
      Delete,
      Function_Key);

   type Modifiers is record
      Shift   : Boolean := False;
      Alt     : Boolean := False;
      Control : Boolean := False;
   end record;

   No_Modifiers : constant Modifiers := (others => False);

   type Mouse_Button is (Left_Button, Middle_Button, Right_Button, Wheel_Up, Wheel_Down, No_Button);

   type Mouse_Action is (Press, Release, Drag);

   type Reply_Kind is (Identity_Reply, Version_Reply, Device_Attributes_Reply);

   type Event_Kind is (Key_Event, Mouse_Event, Resize_Event, Paste_Event, Focus_Event, Reply_Event);

   type Event (Kind : Event_Kind := Key_Event) is record
      case Kind is
         when Key_Event =>
            Key    : Key_Kind := Character_Key;
            --  The character for a Character_Key, unshifted by Control.
            Code   : Wide_Wide_Character := Wide_Wide_Character'Val (0);
            --  The number of a Function_Key.
            Number : Natural := 0;
            Mods   : Modifiers := No_Modifiers;
         when Mouse_Event =>
            Button     : Mouse_Button := No_Button;
            Action     : Mouse_Action := Press;
            Row        : Positive := 1;
            Column     : Positive := 1;
            Mouse_Mods : Modifiers := No_Modifiers;
         when Resize_Event =>
            Rows         : Natural := 0;
            Columns      : Natural := 0;
            Pixel_Height : Natural := 0;
            Pixel_Width  : Natural := 0;
         when Paste_Event =>
            Text : Ada.Strings.Unbounded.Unbounded_String;
         when Focus_Event =>
            Focused : Boolean := True;
         when Reply_Event =>
            Reply   : Reply_Kind := Device_Attributes_Reply;
            --  The reply's body, without its introducer and terminator.
            Payload : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   function Is_Character (Item : Event; Code : Wide_Wide_Character) return Boolean is
     (Item.Kind = Key_Event
      and then Item.Key = Character_Key
      and then Item.Code = Code
      and then not Item.Mods.Alt
      and then not Item.Mods.Control);

   type Decoder is private;

   procedure Feed (Self : in out Decoder; Data : String);

   --  Decode the next complete event, if there is one.
   procedure Next (Self : in out Decoder; Item : out Event; Found : out Boolean);

   --  Treat what is pending as complete: a lone ESC becomes the Escape key and
   --  an unfinished sequence other than a paste is dropped. Applies to the
   --  following calls of Next until Feed is called again.
   procedure Flush (Self : in out Decoder);

   function Has_Pending (Self : Decoder) return Boolean;

private
   type Decoder is record
      Buffer  : Ada.Strings.Unbounded.Unbounded_String;
      Flushed : Boolean := False;
   end record;
end Explore.Input;
