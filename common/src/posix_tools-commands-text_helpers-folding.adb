with Ada.Strings.Unbounded;

package body Posix_Tools.Commands.Text_Helpers.Folding is
   use Ada.Strings.Unbounded;

   procedure Append_UTF_8 (Output : in out Unbounded_String; Code_Point : Long_Long_Integer) is
   begin
      if Code_Point <= 16#7F# then
         Append (Output, Character'Val (Natural (Code_Point)));
      elsif Code_Point <= 16#7FF# then
         Append (Output, Character'Val (16#C0# + Natural (Code_Point / 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      elsif Code_Point <= 16#FFFF# then
         Append (Output, Character'Val (16#E0# + Natural (Code_Point / 4_096)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      else
         Append (Output, Character'Val (16#F0# + Natural (Code_Point / 262_144)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 4_096) mod 64)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      end if;
   end Append_UTF_8;

   function Folded_Sort_Text (Text : String) return String is
      Output : Unbounded_String;
      I      : Positive := Text'First;

      function Decode_At
        (Index      : Positive;
         Code_Point : out Long_Long_Integer;
         Width      : out Natural) return Boolean
      is
         B1 : constant Natural := Character'Pos (Text (Index));
      begin
         Code_Point := 0;
         Width := 1;

         if B1 <= 16#7F# then
            Code_Point := Long_Long_Integer (B1);
            return True;
         elsif B1 in 16#C2# .. 16#DF# and then Index + 1 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
            begin
               if B2 not in 16#80# .. 16#BF# then
                  return False;
               end if;
               Code_Point := Long_Long_Integer ((B1 mod 32) * 64 + (B2 mod 64));
               Width := 2;
               return True;
            end;
         elsif B1 in 16#E0# .. 16#EF# and then Index + 2 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
               B3 : constant Natural := Character'Pos (Text (Index + 2));
               Value : constant Natural := (B1 mod 16) * 4_096 + (B2 mod 64) * 64 + (B3 mod 64);
            begin
               if B2 not in 16#80# .. 16#BF#
                 or else B3 not in 16#80# .. 16#BF#
                 or else Value < 16#800#
                 or else Value in 16#D800# .. 16#DFFF#
               then
                  return False;
               end if;
               Code_Point := Long_Long_Integer (Value);
               Width := 3;
               return True;
            end;
         elsif B1 in 16#F0# .. 16#F4# and then Index + 3 <= Text'Last then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
               B3 : constant Natural := Character'Pos (Text (Index + 2));
               B4 : constant Natural := Character'Pos (Text (Index + 3));
               Value : constant Natural :=
                 (B1 mod 8) * 262_144 + (B2 mod 64) * 4_096 + (B3 mod 64) * 64 + (B4 mod 64);
            begin
               if B2 not in 16#80# .. 16#BF#
                 or else B3 not in 16#80# .. 16#BF#
                 or else B4 not in 16#80# .. 16#BF#
                 or else Value < 16#10000#
                 or else Value > 16#10FFFF#
               then
                  return False;
               end if;
               Code_Point := Long_Long_Integer (Value);
               Width := 4;
               return True;
            end;
         else
            return False;
         end if;
      end Decode_At;

      procedure Append_Folded_Code_Point (Code_Point : Long_Long_Integer) is
      begin
         if Code_Point in Character'Pos ('A') .. Character'Pos ('Z') then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point in 16#00C0# .. 16#00D6# or else Code_Point in 16#00D8# .. 16#00DE# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point = 16#00DF# or else Code_Point = 16#1E9E# then
            Append (Output, "ss");
         elsif Code_Point in 16#0100# .. 16#0136# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point in 16#0139# .. 16#0147# and then Code_Point mod 2 = 1 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0130# then
            Append (Output, "i");
            Append_UTF_8 (Output, 16#0307#);
         elsif Code_Point = 16#014A# then
            Append_UTF_8 (Output, 16#014B#);
         elsif Code_Point in 16#014C# .. 16#0176# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0178# then
            Append_UTF_8 (Output, 16#00FF#);
         elsif Code_Point in 16#0179# .. 16#017D# and then Code_Point mod 2 = 1 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#017F# then
            Append (Output, "s");
         elsif Code_Point = 16#0181# then
            Append_UTF_8 (Output, 16#0253#);
         elsif Code_Point in 16#0182# .. 16#0184# and then Code_Point mod 2 = 0 then
            Append_UTF_8 (Output, Code_Point + 1);
         elsif Code_Point = 16#0186# then
            Append_UTF_8 (Output, 16#0254#);
         elsif Code_Point = 16#0187# then
            Append_UTF_8 (Output, 16#0188#);
         elsif Code_Point = 16#0189# then
            Append_UTF_8 (Output, 16#0256#);
         elsif Code_Point = 16#018A# then
            Append_UTF_8 (Output, 16#0257#);
         elsif Code_Point = 16#018B# then
            Append_UTF_8 (Output, 16#018C#);
         elsif Code_Point = 16#018E# then
            Append_UTF_8 (Output, 16#01DD#);
         elsif Code_Point = 16#018F# then
            Append_UTF_8 (Output, 16#0259#);
         elsif Code_Point = 16#0190# then
            Append_UTF_8 (Output, 16#025B#);
         elsif Code_Point = 16#0191# then
            Append_UTF_8 (Output, 16#0192#);
         elsif Code_Point = 16#0193# then
            Append_UTF_8 (Output, 16#0260#);
         elsif Code_Point = 16#0194# then
            Append_UTF_8 (Output, 16#0263#);
         elsif Code_Point = 16#0196# then
            Append_UTF_8 (Output, 16#0269#);
         elsif Code_Point = 16#0197# then
            Append_UTF_8 (Output, 16#0268#);
         elsif Code_Point = 16#0198# then
            Append_UTF_8 (Output, 16#0199#);
         elsif Code_Point = 16#019C# then
            Append_UTF_8 (Output, 16#026F#);
         elsif Code_Point = 16#019D# then
            Append_UTF_8 (Output, 16#0272#);
         elsif Code_Point = 16#019F# then
            Append_UTF_8 (Output, 16#0275#);
         elsif Code_Point = 16#0386# then
            Append_UTF_8 (Output, 16#03AC#);
         elsif Code_Point in 16#0388# .. 16#038A# then
            Append_UTF_8 (Output, Code_Point + 37);
         elsif Code_Point = 16#038C# then
            Append_UTF_8 (Output, 16#03CC#);
         elsif Code_Point in 16#038E# .. 16#038F# then
            Append_UTF_8 (Output, Code_Point + 63);
         elsif Code_Point in 16#0391# .. 16#03A1# or else Code_Point in 16#03A3# .. 16#03AB# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point = 16#03C2# then
            Append_UTF_8 (Output, 16#03C3#);
         elsif Code_Point in 16#0400# .. 16#040F# then
            Append_UTF_8 (Output, Code_Point + 80);
         elsif Code_Point in 16#0410# .. 16#042F# then
            Append_UTF_8 (Output, Code_Point + 32);
         elsif Code_Point in 16#0531# .. 16#0556# then
            Append_UTF_8 (Output, Code_Point + 48);
         elsif Code_Point in 16#13A0# .. 16#13EF# then
            Append_UTF_8 (Output, Code_Point + 16#97D0#);
         elsif Code_Point in 16#13F0# .. 16#13F5# then
            Append_UTF_8 (Output, Code_Point + 8);
         elsif Code_Point in 16#10400# .. 16#10427# then
            Append_UTF_8 (Output, Code_Point + 40);
         elsif Code_Point in 16#1C90# .. 16#1CBF# then
            Append_UTF_8 (Output, Code_Point - 16#0BC0#);
         elsif Code_Point = 16#212A# then
            Append (Output, "k");
         elsif Code_Point = 16#212B# then
            Append_UTF_8 (Output, 16#00E5#);
         elsif Code_Point = 16#FB00# then
            Append (Output, "ff");
         elsif Code_Point = 16#FB01# then
            Append (Output, "fi");
         elsif Code_Point = 16#FB02# then
            Append (Output, "fl");
         elsif Code_Point = 16#FB03# then
            Append (Output, "ffi");
         elsif Code_Point = 16#FB04# then
            Append (Output, "ffl");
         elsif Code_Point = 16#FB05# or else Code_Point = 16#FB06# then
            Append (Output, "st");
         elsif Code_Point in 16#FF21# .. 16#FF3A# then
            Append_UTF_8 (Output, Code_Point + 32);
         else
            Append_UTF_8 (Output, Code_Point);
         end if;
      end Append_Folded_Code_Point;
   begin
      while I <= Text'Last loop
         declare
            Code_Point : Long_Long_Integer;
            Width      : Natural;
         begin
            if Decode_At (I, Code_Point, Width) then
               Append_Folded_Code_Point (Code_Point);
               I := I + Width;
            else
               Append (Output, Text (I));
               I := I + 1;
            end if;
         end;
      end loop;

      return To_String (Output);
   end Folded_Sort_Text;
end Posix_Tools.Commands.Text_Helpers.Folding;
