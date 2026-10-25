with Ada.Strings.Fixed;
with Posix_Tools.Text.UTF_8;

package body Explore.Input is

   package Unbounded renames Ada.Strings.Unbounded;
   package UTF_8 renames Posix_Tools.Text.UTF_8;

   ESC : constant Character := Character'Val (27);
   BEL : constant Character := Character'Val (7);

   Paste_End : constant String := ESC & "[201~";

   --  A sequence longer than this is not one the terminal sends; its
   --  introducer is dropped so that what follows is decoded afresh.
   Sequence_Limit : constant := 4096;

   type Scan_Status is
     (Complete,     --  Item holds an event and Length bytes were used.
      Skip,         --  Length bytes were used and mean nothing to explore.
      Incomplete);  --  More bytes are needed.

   function Key
     (Kind   : Key_Kind;
      Mods   : Modifiers := No_Modifiers;
      Code   : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      Number : Natural := 0) return Event is
     (Kind => Key_Event, Key => Kind, Code => Code, Number => Number, Mods => Mods);

   function Character_Key (Code : Natural; Mods : Modifiers := No_Modifiers) return Event is
     (Key (Character_Key, Mods, Wide_Wide_Character'Val (Code)));

   function Starts_With (Text, Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Has_Pending (Self : Decoder) return Boolean is (Unbounded.Length (Self.Buffer) > 0);

   function Decode_Modifiers (Value : Natural) return Modifiers;

   --  The event an ordinary CSI sequence stands for, by its parameters and
   --  final byte: a key, a focus change, or the size of the window.
   procedure Decode_CSI (Params : String; Last_Byte : Character; Item : out Event; Status : out Scan_Status);

   procedure Decode_Mouse (Params : String; Final : Character; Item : out Event; Found : out Boolean);

   --  A CSI sequence whose parameters start with one of "<=>?": a mouse
   --  report, or the terminal's reply to a question about its attributes.
   procedure Decode_Private_CSI
     (Params    : String;
      Last_Byte : Character;
      Item      : out Event;
      Status    : out Scan_Status)
     with Pre => Params'Length > 0;

   function Kitty_Key (Code : Natural; Mods : Modifiers; Item : out Event) return Boolean;

   function Parameter (Params : String; Index : Positive; Default : Natural := 0) return Natural;

   procedure Scan
     (Text    : String;
      Flushed : Boolean;
      Item    : out Event;
      Length  : out Natural;
      Status  : out Scan_Status);

   procedure Scan_CSI
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status);

   --  A bracketed paste, Text starting with the CSI 200~ that ends at Final:
   --  whatever comes before the CSI 201~ that closes it.
   procedure Scan_Paste
     (Text   : String;
      Final  : Positive;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status);

   procedure Scan_Plain
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status);

   procedure Scan_String
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status);

   procedure Scan_UTF_8
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status);

   function Tilde_Key (Number : Natural; Mods : Modifiers; Item : out Event) return Boolean;

   procedure Decode_CSI (Params : String; Last_Byte : Character; Item : out Event; Status : out Scan_Status) is
      Mods : constant Modifiers := Decode_Modifiers (Parameter (Params, 2, 1));
   begin
      Item := Key (Character_Key);
      Status := Complete;

      case Last_Byte is
         when 'A' =>
            Item := Key (Up, Mods);
         when 'B' =>
            Item := Key (Down, Mods);
         when 'C' =>
            Item := Key (Right, Mods);
         when 'D' =>
            Item := Key (Left, Mods);
         when 'H' =>
            Item := Key (Home, Mods);
         when 'F' =>
            Item := Key (End_Key, Mods);
         when 'P' .. 'S' =>
            Item := Key (Function_Key, Mods, Number => Character'Pos (Last_Byte) - Character'Pos ('P') + 1);
         when 'Z' =>
            Item := Key (Tab, (Shift => True, others => False));
         when 'I' | 'O' =>
            if Params'Length = 0 then
               Item := (Kind => Focus_Event, Focused => Last_Byte = 'I');
            else
               Status := Skip;
            end if;
         when '~' =>
            if not Tilde_Key (Parameter (Params, 1), Mods, Item) then
               Status := Skip;
            end if;
         when 'u' =>
            if not Kitty_Key (Parameter (Params, 1), Mods, Item) then
               Status := Skip;
            end if;
         when 't' =>
            if Parameter (Params, 1) = 48 then
               Item :=
                 (Kind         => Resize_Event,
                  Rows         => Parameter (Params, 2),
                  Columns      => Parameter (Params, 3),
                  Pixel_Height => Parameter (Params, 4),
                  Pixel_Width  => Parameter (Params, 5));
            else
               Status := Skip;
            end if;
         when others =>
            Status := Skip;
      end case;
   end Decode_CSI;

   --  The modifiers an xterm-style parameter encodes: one more than a bit set
   --  of shift, alt and control.
   function Decode_Modifiers (Value : Natural) return Modifiers is
      Bits : constant Natural := (if Value > 0 then Value - 1 else 0);
   begin
      return (Shift => Bits mod 2 = 1, Alt => (Bits / 2) mod 2 = 1, Control => (Bits / 4) mod 2 = 1);
   end Decode_Modifiers;

   procedure Decode_Mouse (Params : String; Final : Character; Item : out Event; Found : out Boolean) is
      Code   : constant Natural := Parameter (Params, 1);
      Column : constant Natural := Parameter (Params, 2);
      Row    : constant Natural := Parameter (Params, 3);
      Mods   : constant Modifiers :=
        (Shift => (Code / 4) mod 2 = 1, Alt => (Code / 8) mod 2 = 1, Control => (Code / 16) mod 2 = 1);
      Button : Mouse_Button;
      Action : Mouse_Action;
   begin
      Found := Row >= 1 and then Column >= 1;

      if Code >= 64 then
         Button := (if Code mod 2 = 0 then Wheel_Up else Wheel_Down);
      else
         Button :=
           (case Code mod 4 is
              when 0 => Left_Button,
              when 1 => Middle_Button,
              when 2 => Right_Button,
              when others => No_Button);
      end if;

      if Final = 'm' then
         Action := Release;
      elsif (Code / 32) mod 2 = 1 and then Code < 64 then
         Action := Drag;
      else
         Action := Press;
      end if;

      Item :=
        (Kind       => Mouse_Event,
         Button     => Button,
         Action     => Action,
         Row        => Positive'Max (Row, 1),
         Column     => Positive'Max (Column, 1),
         Mouse_Mods => Mods);
   end Decode_Mouse;

   procedure Decode_Private_CSI
     (Params    : String;
      Last_Byte : Character;
      Item      : out Event;
      Status    : out Scan_Status)
   is
   begin
      Item := Key (Character_Key);
      Status := Complete;

      if Params (Params'First) = '<' and then Last_Byte in 'M' | 'm' then
         declare
            Found : Boolean;
         begin
            Decode_Mouse (Params (Params'First + 1 .. Params'Last), Last_Byte, Item, Found);
            Status := (if Found then Complete else Skip);
         end;
      elsif Params (Params'First) = '?' and then Last_Byte = 'c' then
         Item :=
           (Kind    => Reply_Event,
            Reply   => Device_Attributes_Reply,
            Payload => Unbounded.To_Unbounded_String (Params (Params'First + 1 .. Params'Last)));
      else
         Status := Skip;
      end if;
   end Decode_Private_CSI;

   procedure Feed (Self : in out Decoder; Data : String) is
   begin
      Unbounded.Append (Self.Buffer, Data);
      Self.Flushed := False;
   end Feed;

   procedure Flush (Self : in out Decoder) is
   begin
      Self.Flushed := True;
   end Flush;

   --  A key in the progressive keyboard protocol: CSI code ; modifiers u.
   function Kitty_Key (Code : Natural; Mods : Modifiers; Item : out Event) return Boolean is
   begin
      case Code is
         when 13 =>
            Item := Key (Enter, Mods);
         when 9 =>
            Item := Key (Tab, Mods);
         when 127 | 8 =>
            Item := Key (Backspace, Mods);
         when 27 =>
            Item := Key (Escape, Mods);
         when 32 .. 126 | 160 .. 16#D7FF# | 16#F900# .. 16#10_FFFF# =>
            --  The protocol's own functional keys sit in the private use area
            --  below U+F900; explore has no use for them and leaves them out.
            Item := Character_Key (Code, Mods);
         when others =>
            Item := Key (Character_Key);
            return False;
      end case;

      return True;
   end Kitty_Key;

   procedure Next (Self : in out Decoder; Item : out Event; Found : out Boolean) is
      Length : Natural;
      Status : Scan_Status;
   begin
      Found := False;
      Item := Key (Character_Key);

      while Unbounded.Length (Self.Buffer) > 0 loop
         declare
            Text : constant String := Unbounded.To_String (Self.Buffer);
         begin
            Scan (Text, Self.Flushed, Item, Length, Status);
         end;

         case Status is
            when Complete =>
               Unbounded.Delete (Self.Buffer, 1, Length);
               Found := True;
               return;
            when Skip =>
               Unbounded.Delete (Self.Buffer, 1, Positive'Max (Length, 1));
            when Incomplete =>
               if not Self.Flushed then
                  return;
               end if;

               declare
                  Text : constant String := Unbounded.To_String (Self.Buffer);
               begin
                  if Starts_With (Text, ESC & "[200~") then
                     --  A paste is never cut short; the rest is still coming.
                     return;
                  end if;
               end;

               --  An unfinished sequence after a pause: the ESC was a key.
               Unbounded.Delete (Self.Buffer, 1, 1);
               Item := Key (Escape);
               Found := True;
               return;
         end case;
      end loop;
   end Next;

   --  The Index'th ';'-separated parameter's leading number, ignoring any ':'
   --  sub-parameters after it; Default when it is absent or empty.
   function Parameter (Params : String; Index : Positive; Default : Natural := 0) return Natural is
      Current : Positive := 1;
      Value   : Natural := 0;
      Seen    : Boolean := False;
      In_Sub  : Boolean := False;
   begin
      for C of Params loop
         if C = ';' then
            if Current = Index then
               return (if Seen then Value else Default);
            end if;

            Current := Current + 1;
            In_Sub := False;
         elsif Current = Index and then not In_Sub then
            if C = ':' then
               In_Sub := True;
            elsif C in '0' .. '9' and then Value < 100_000_000 then
               Value := Value * 10 + (Character'Pos (C) - Character'Pos ('0'));
               Seen := True;
            end if;
         end if;
      end loop;

      return (if Current = Index and then Seen then Value else Default);
   end Parameter;

   procedure Scan
     (Text    : String;
      Flushed : Boolean;
      Item    : out Event;
      Length  : out Natural;
      Status  : out Scan_Status)
   is
   begin
      if Text (Text'First) /= ESC then
         Scan_Plain (Text, Item, Length, Status);
         return;
      end if;

      if Text'Length = 1 then
         Item := Key (Escape);
         Length := 1;
         Status := (if Flushed then Complete else Incomplete);
         return;
      end if;

      case Text (Text'First + 1) is
         when '[' =>
            Scan_CSI (Text, Item, Length, Status);
         when ']' | 'P' =>
            Scan_String (Text, Item, Length, Status);
         when 'O' =>
            if Text'Length < 3 then
               Item := Key (Character_Key);
               Length := 0;
               Status := Incomplete;
            else
               Length := 3;
               Status := Complete;

               case Text (Text'First + 2) is
                  when 'A' => Item := Key (Up);
                  when 'B' => Item := Key (Down);
                  when 'C' => Item := Key (Right);
                  when 'D' => Item := Key (Left);
                  when 'H' => Item := Key (Home);
                  when 'F' => Item := Key (End_Key);
                  when 'P' .. 'S' =>
                     Item :=
                       Key (Function_Key,
                            Number => Character'Pos (Text (Text'First + 2)) - Character'Pos ('P') + 1);
                  when others =>
                     Item := Key (Character_Key);
                     Status := Skip;
               end case;
            end if;
         when ESC =>
            Item := Key (Escape);
            Length := 1;
            Status := Complete;
         when others =>
            --  Alt held with an ordinary key.
            Scan_Plain (Text (Text'First + 1 .. Text'Last), Item, Length, Status);

            if Status = Complete then
               Length := Length + 1;

               if Item.Kind = Key_Event then
                  Item.Mods.Alt := True;
               end if;
            elsif Status = Skip then
               Length := Length + 1;
            end if;
      end case;

      --  Past the limit an unfinished sequence is taken for noise -- unless
      --  it is a paste, which is as long as what was pasted.
      if Status = Incomplete and then Text'Length > Sequence_Limit and then not Starts_With (Text, ESC & "[200~") then
         Length := 1;
         Status := Skip;
      end if;
   end Scan;

   --  CSI, from the byte after "ESC [".
   procedure Scan_CSI
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status)
   is
      First : constant Positive := Text'First + 2;
      Final : Natural := 0;
   begin
      Item := Key (Character_Key);
      Length := 0;

      for I in First .. Text'Last loop
         if Character'Pos (Text (I)) in 16#40# .. 16#7E# then
            Final := I;
            exit;
         elsif Character'Pos (Text (I)) not in 16#20# .. 16#3F# then
            --  Not a sequence after all; let the introducer go and decode the
            --  rest on its own.
            Length := 2;
            Status := Skip;
            return;
         end if;
      end loop;

      if Final = 0 then
         Status := Incomplete;
         return;
      end if;

      Length := Final - Text'First + 1;

      declare
         Params    : constant String := Text (First .. Final - 1);
         Last_Byte : constant Character := Text (Final);
      begin
         if Last_Byte = '~' and then Params = "200" then
            Scan_Paste (Text, Final, Item, Length, Status);
         elsif Params'Length > 0 and then Params (Params'First) in '<' .. '?' then
            Decode_Private_CSI (Params, Last_Byte, Item, Status);
         else
            Decode_CSI (Params, Last_Byte, Item, Status);
         end if;
      end;
   end Scan_CSI;

   procedure Scan_Paste
     (Text   : String;
      Final  : Positive;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status)
   is
      Rest     : constant String := Text (Final + 1 .. Text'Last);
      Paste_At : constant Natural := Ada.Strings.Fixed.Index (Rest, Paste_End);
   begin
      Item := Key (Character_Key);

      if Paste_At = 0 then
         Length := 0;
         Status := Incomplete;
      else
         Item := (Kind => Paste_Event, Text => Unbounded.To_Unbounded_String (Rest (Rest'First .. Paste_At - 1)));
         Length := Paste_At + Paste_End'Length - Text'First;
         Status := Complete;
      end if;
   end Scan_Paste;

   --  A key typed without a sequence: a control byte, DEL, or a character.
   procedure Scan_Plain
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status)
   is
      Byte : constant Natural := Character'Pos (Text (Text'First));
   begin
      Length := 1;
      Status := Complete;

      case Byte is
         when 13 | 10 =>
            Item := Key (Enter);
         when 9 =>
            Item := Key (Tab);
         when 8 | 127 =>
            Item := Key (Backspace);
         when 0 =>
            Item := Character_Key (Character'Pos (' '), (Control => True, others => False));
         when 1 .. 7 | 11 .. 12 | 14 .. 26 =>
            Item := Character_Key (Character'Pos ('a') + Byte - 1, (Control => True, others => False));
         when 27 .. 31 =>
            Item := Key (Character_Key);
            Status := Skip;
         when others =>
            Scan_UTF_8 (Text, Item, Length, Status);
      end case;
   end Scan_Plain;

   --  OSC or DCS, from the byte after "ESC ]" or "ESC P", up to BEL or ST.
   procedure Scan_String
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status)
   is
      Is_OSC : constant Boolean := Text (Text'First + 1) = ']';
      First  : constant Positive := Text'First + 2;
      Last   : Natural := 0;
      After  : Natural := 0;
   begin
      Item := Key (Character_Key);
      Length := 0;
      Status := Incomplete;

      for I in First .. Text'Last loop
         if Text (I) = BEL then
            Last := I - 1;
            After := I;
            exit;
         elsif Text (I) = ESC then
            if I = Text'Last then
               return;
            elsif Text (I + 1) = '\' then
               Last := I - 1;
               After := I + 1;
               exit;
            end if;
         end if;
      end loop;

      if After = 0 then
         return;
      end if;

      Length := After - Text'First + 1;
      Status := Skip;

      declare
         Payload : constant String := Text (First .. Last);
         OSC_Key : constant String := "7701;";
      begin
         if Is_OSC and then Starts_With (Payload, OSC_Key) then
            Item :=
              (Kind    => Reply_Event,
               Reply   => Identity_Reply,
               Payload => Unbounded.To_Unbounded_String (Payload (Payload'First + OSC_Key'Length .. Payload'Last)));
            Status := Complete;
         elsif not Is_OSC and then Starts_With (Payload, ">|") then
            Item :=
              (Kind    => Reply_Event,
               Reply   => Version_Reply,
               Payload => Unbounded.To_Unbounded_String (Payload (Payload'First + 2 .. Payload'Last)));
            Status := Complete;
         end if;
      end;
   end Scan_String;

   procedure Scan_UTF_8
     (Text   : String;
      Item   : out Event;
      Length : out Natural;
      Status : out Scan_Status)
   is
      Decoder : UTF_8.Decoder;
      Decoded : UTF_8.Decode_Status;
      Code    : Long_Long_Integer;
   begin
      Item := Key (Character_Key);

      for I in Text'Range loop
         UTF_8.Decode (Decoder, Character'Pos (Text (I)), Decoded, Code);

         case Decoded is
            when UTF_8.Complete =>
               Item := Character_Key (Natural (Code));
               Length := I - Text'First + 1;
               Status := Complete;
               return;
            when UTF_8.Invalid =>
               --  A sequence whole but for what it encodes -- an overlong
               --  form, a surrogate, or beyond U+10FFFF -- is skipped as a
               --  whole. Otherwise only its first byte is, and the byte that
               --  broke it is read again, as the start of what comes next.
               Length :=
                 (if I > Text'First and then Character'Pos (Text (I)) in 16#80# .. 16#BF# then I - Text'First + 1
                  else 1);
               Status := Skip;
               return;
            when UTF_8.Need_More =>
               null;
         end case;
      end loop;

      --  The rest of the sequence has not arrived yet.
      Length := 0;
      Status := Incomplete;
   end Scan_UTF_8;

   function Tilde_Key (Number : Natural; Mods : Modifiers; Item : out Event) return Boolean is
   begin
      case Number is
         when 1 | 7 =>
            Item := Key (Home, Mods);
         when 2 =>
            Item := Key (Insert, Mods);
         when 3 =>
            Item := Key (Delete, Mods);
         when 4 | 8 =>
            Item := Key (End_Key, Mods);
         when 5 =>
            Item := Key (Page_Up, Mods);
         when 6 =>
            Item := Key (Page_Down, Mods);
         when 11 .. 15 =>
            Item := Key (Function_Key, Mods, Number => Number - 10);
         when 17 .. 21 =>
            Item := Key (Function_Key, Mods, Number => Number - 11);
         when 23 .. 24 =>
            Item := Key (Function_Key, Mods, Number => Number - 12);
         when others =>
            Item := Key (Character_Key);
            return False;
      end case;

      return True;
   end Tilde_Key;

end Explore.Input;
