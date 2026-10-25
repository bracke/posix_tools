with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;

package body Explore.Line_Editor is
   package Unbounded renames Ada.Strings.Unbounded;
   package Input renames Explore.Input;

   procedure Drop_Last (Text : in out Unbounded.Unbounded_String) is
   begin
      --  The bytes 16#80# .. 16#BF# continue a character: they go until the
      --  byte that starts it has gone too.
      while Unbounded.Length (Text) > 0 loop
         declare
            Last : constant Character := Unbounded.Element (Text, Unbounded.Length (Text));
         begin
            Unbounded.Delete (Text, Unbounded.Length (Text), Unbounded.Length (Text));
            exit when Character'Pos (Last) not in 16#80# .. 16#BF#;
         end;
      end loop;
   end Drop_Last;

   procedure Edit
     (Text   : in out Unbounded.Unbounded_String;
      Item   : Input.Event;
      Result : out Outcome)
   is
   begin
      Result := Typing;

      case Item.Kind is
         when Input.Key_Event =>
            case Item.Key is
               when Input.Enter =>
                  Result := Accepted;
               when Input.Escape =>
                  Result := Escaped;
               when Input.Backspace =>
                  Drop_Last (Text);
               when Input.Character_Key =>
                  if Item.Mods.Control and then Item.Code = 'c' then
                     Result := Interrupted;
                  elsif not Item.Mods.Control and then not Item.Mods.Alt then
                     Unbounded.Append (Text, Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ([1 => Item.Code]));
                  end if;
               when others =>
                  null;
            end case;
         when Input.Paste_Event =>
            Unbounded.Append (Text, Item.Text);
         when others =>
            null;
      end case;
   end Edit;
end Explore.Line_Editor;
