package body Explore.Protocol is
   ESC : constant Character := Character'Val (27);
   CSI : constant String := ESC & "[";
   ST  : constant String := ESC & "\";

   function Image (Value : Natural) return String;

   function Begin_Frame return String is (CSI & "?2026h");

   function Clear_Screen return String is (CSI & "2J");

   function End_Frame return String is (CSI & "?2026l");

   function Enter_Screen return String is
     (CSI & "?1049h"     --  alternate screen
      & CSI & "?25l"     --  hide the cursor
      & CSI & "?1002h"   --  button and drag mouse reports
      & CSI & "?1006h"   --  in SGR encoding
      & CSI & "?1004h"   --  focus reports
      & CSI & "?2004h"   --  bracketed paste
      & CSI & "?2048h"   --  in-band resize reports
      & CSI & ">1u");    --  disambiguated keys

   function Identity_Query (In_Tmux : Boolean) return String is
     (To_Outer_Terminal (ESC & "]" & Identity_OSC & ";q" & ST, In_Tmux)
      & To_Outer_Terminal (CSI & "c", In_Tmux));

   function Leave_Screen return String is
     (CSI & "<u"
      & CSI & "?2048l"
      & CSI & "?2004l"
      & CSI & "?1004l"
      & CSI & "?1006l"
      & CSI & "?1002l"
      & CSI & "0m"
      & CSI & "?25h"
      & CSI & "?1049l");

   function Move_To (Row, Column : Positive) return String is
     (CSI & Image (Row) & ";" & Image (Column) & "H");

   function Reset_Style return String is (CSI & "0m");

   function Reverse_Video return String is (CSI & "7m");

   function To_Outer_Terminal (Sequence : String; In_Tmux : Boolean) return String is
     (if In_Tmux then Passthrough (Sequence) else Sequence);

   function Capability_Name (Item : Capability) return String is
   begin
      case Item is
         when Kitty_Graphics =>
            return "kgfx";
         when Kitty_Graphics_Shared_Memory =>
            return "kgfx-shm";
         when Kitty_Graphics_JPEG =>
            return "kgfx-jpeg";
         when Kitty_Graphics_GIF =>
            return "kgfx-gif";
         when Kitty_Keyboard =>
            return "kbd";
         when Resize_Reports =>
            return "resize2048";
         when Clipboard =>
            return "osc52";
      end case;
   end Capability_Name;

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   procedure Parse_Identity
     (Body_Text : String;
      Result    : out Identity;
      Valid     : out Boolean)
   is
      Has_Version : Boolean := False;

      procedure Parse_Capabilities (Text : String);

      procedure Parse_Field (Field : String);

      procedure Parse_Version (Text : String);

      First : Positive := Body_Text'First;

      procedure Parse_Capabilities (Text : String) is
         First : Positive := Text'First;
      begin
         for I in Text'First .. Text'Last + 1 loop
            if I > Text'Last or else Text (I) = ',' then
               for Item in Capability loop
                  if Text (First .. I - 1) = Capability_Name (Item) then
                     Result.Capabilities (Item) := True;
                  end if;
               end loop;

               First := I + 1;
            end if;
         end loop;
      end Parse_Capabilities;

      procedure Parse_Field (Field : String) is
      begin
         for I in Field'Range loop
            if Field (I) = '=' then
               declare
                  Key   : constant String := Field (Field'First .. I - 1);
                  Value : constant String := Field (I + 1 .. Field'Last);
               begin
                  if Key = "v" then
                     Parse_Version (Value);
                  elsif Key = "caps" then
                     Parse_Capabilities (Value);
                  end if;
               end;

               return;
            end if;
         end loop;
      end Parse_Field;

      procedure Parse_Version (Text : String) is
         Value : Natural := 0;
      begin
         if Text'Length = 0 or else Text'Length > 4 then
            return;
         end if;

         for C of Text loop
            if C not in '0' .. '9' then
               return;
            end if;

            Value := Value * 10 + (Character'Pos (C) - Character'Pos ('0'));
         end loop;

         Result.Version := Value;
         Has_Version := True;
      end Parse_Version;

   begin
      Result := (Version => 0, Capabilities => No_Capabilities);

      for I in Body_Text'First .. Body_Text'Last + 1 loop
         if I > Body_Text'Last or else Body_Text (I) = ';' then
            Parse_Field (Body_Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;

      Valid := Has_Version and then Result.Version >= 1;
   end Parse_Identity;

   function Passthrough (Sequence : String) return String is
      Escapes : Natural := 0;
   begin
      for C of Sequence loop
         if C = ESC then
            Escapes := Escapes + 1;
         end if;
      end loop;

      declare
         Doubled : String (1 .. Sequence'Length + Escapes);
         Last    : Natural := 0;
      begin
         for C of Sequence loop
            Last := Last + 1;
            Doubled (Last) := C;

            if C = ESC then
               Last := Last + 1;
               Doubled (Last) := ESC;
            end if;
         end loop;

         return ESC & "Ptmux;" & Doubled & ST;
      end;
   end Passthrough;

end Explore.Protocol;
