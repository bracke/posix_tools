with Ada.Strings.Unbounded;
with Explore.Input;

--  Typing a line of text, as a prompt's answer or the filter is typed: keys
--  add their characters, Backspace takes the last character back, and a paste
--  is added whole. The text is UTF-8, so taking a character back takes all of
--  its bytes.
package Explore.Line_Editor is
   type Outcome is
     (Typing,       --  The line is still being typed.
      Accepted,     --  Enter was pressed.
      Escaped,      --  Escape was pressed.
      Interrupted); --  Control-C was pressed.

   --  Edit Text with Item. Enter, Escape and Control-C leave Text as it is
   --  and say which was pressed; a key with Control or Alt adds nothing.
   procedure Edit
     (Text   : in out Ada.Strings.Unbounded.Unbounded_String;
      Item   : Explore.Input.Event;
      Result : out Outcome);

   --  Text without its last character, all of its bytes.
   procedure Drop_Last (Text : in out Ada.Strings.Unbounded.Unbounded_String);
end Explore.Line_Editor;
