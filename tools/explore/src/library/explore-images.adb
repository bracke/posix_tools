with Ada.Strings.Unbounded;
with Explore.Protocol;

package body Explore.Images is
   ESC : constant Character := Character'Val (27);

   --  Ordered as Kitty's rowcolumn-diacritics.txt: the position, from zero,
   --  is the row or column a diacritic names.
   Diacritics : constant array (0 .. Diacritic_Count - 1) of Natural :=
     [16#0305#, 16#030D#, 16#030E#, 16#0310#, 16#0312#, 16#033D#, 16#033E#, 16#033F#, 16#0346#, 16#034A#,
      16#034B#, 16#034C#, 16#0350#, 16#0351#, 16#0352#, 16#0357#, 16#035B#, 16#0363#, 16#0364#, 16#0365#,
      16#0366#, 16#0367#, 16#0368#, 16#0369#, 16#036A#, 16#036B#, 16#036C#, 16#036D#, 16#036E#, 16#036F#,
      16#0483#, 16#0484#, 16#0485#, 16#0486#, 16#0487#, 16#0592#, 16#0593#, 16#0594#, 16#0595#, 16#0597#,
      16#0598#, 16#0599#, 16#059C#, 16#059D#, 16#059E#, 16#059F#, 16#05A0#, 16#05A1#, 16#05A8#, 16#05A9#,
      16#05AB#, 16#05AC#, 16#05AF#, 16#05C4#, 16#0610#, 16#0611#, 16#0612#, 16#0613#, 16#0614#, 16#0615#,
      16#0616#, 16#0617#, 16#0657#, 16#0658#, 16#0659#, 16#065A#, 16#065B#, 16#065D#, 16#065E#, 16#06D6#,
      16#06D7#, 16#06D8#, 16#06D9#, 16#06DA#, 16#06DB#, 16#06DC#, 16#06DF#, 16#06E0#, 16#06E1#, 16#06E2#,
      16#06E4#, 16#06E7#, 16#06E8#, 16#06EB#, 16#06EC#, 16#0730#, 16#0732#, 16#0733#, 16#0735#, 16#0736#,
      16#073A#, 16#073D#, 16#073F#, 16#0740#, 16#0741#, 16#0743#, 16#0745#, 16#0747#, 16#0749#, 16#074A#,
      16#07EB#, 16#07EC#, 16#07ED#, 16#07EE#, 16#07EF#, 16#07F0#, 16#07F1#, 16#07F3#, 16#0816#, 16#0817#,
      16#0818#, 16#0819#, 16#081B#, 16#081C#, 16#081D#, 16#081E#, 16#081F#, 16#0820#, 16#0821#, 16#0822#,
      16#0823#, 16#0825#, 16#0826#, 16#0827#, 16#0829#, 16#082A#, 16#082B#, 16#082C#, 16#082D#, 16#0951#,
      16#0953#, 16#0954#, 16#0F82#, 16#0F83#, 16#0F86#, 16#0F87#, 16#135D#, 16#135E#, 16#135F#, 16#17DD#,
      16#193A#, 16#1A17#, 16#1A75#, 16#1A76#, 16#1A77#, 16#1A78#, 16#1A79#, 16#1A7A#, 16#1A7B#, 16#1A7C#,
      16#1B6B#, 16#1B6D#, 16#1B6E#, 16#1B6F#, 16#1B70#, 16#1B71#, 16#1B72#, 16#1B73#, 16#1CD0#, 16#1CD1#,
      16#1CD2#, 16#1CDA#, 16#1CDB#, 16#1CE0#, 16#1DC0#, 16#1DC1#, 16#1DC3#, 16#1DC4#, 16#1DC5#, 16#1DC6#,
      16#1DC7#, 16#1DC8#, 16#1DC9#, 16#1DCB#, 16#1DCC#, 16#1DD1#, 16#1DD2#, 16#1DD3#, 16#1DD4#, 16#1DD5#,
      16#1DD6#, 16#1DD7#, 16#1DD8#, 16#1DD9#, 16#1DDA#, 16#1DDB#, 16#1DDC#, 16#1DDD#, 16#1DDE#, 16#1DDF#,
      16#1DE0#, 16#1DE1#, 16#1DE2#, 16#1DE3#, 16#1DE4#, 16#1DE5#, 16#1DE6#, 16#1DFE#, 16#20D0#, 16#20D1#,
      16#20D4#, 16#20D5#, 16#20D6#, 16#20D7#, 16#20DB#, 16#20DC#, 16#20E1#, 16#20E7#, 16#20E9#, 16#20F0#,
      16#2CEF#, 16#2CF0#, 16#2CF1#, 16#2DE0#, 16#2DE1#, 16#2DE2#, 16#2DE3#, 16#2DE4#, 16#2DE5#, 16#2DE6#,
      16#2DE7#, 16#2DE8#, 16#2DE9#, 16#2DEA#, 16#2DEB#, 16#2DEC#, 16#2DED#, 16#2DEE#, 16#2DEF#, 16#2DF0#,
      16#2DF1#, 16#2DF2#, 16#2DF3#, 16#2DF4#, 16#2DF5#, 16#2DF6#, 16#2DF7#, 16#2DF8#, 16#2DF9#, 16#2DFA#,
      16#2DFB#, 16#2DFC#, 16#2DFD#, 16#2DFE#, 16#2DFF#, 16#A66F#, 16#A67C#, 16#A67D#, 16#A6F0#, 16#A6F1#,
      16#A8E0#, 16#A8E1#, 16#A8E2#, 16#A8E3#, 16#A8E4#, 16#A8E5#, 16#A8E6#, 16#A8E7#, 16#A8E8#, 16#A8E9#,
      16#A8EA#, 16#A8EB#, 16#A8EC#, 16#A8ED#, 16#A8EE#, 16#A8EF#, 16#A8F0#, 16#A8F1#, 16#AAB0#, 16#AAB2#,
      16#AAB3#, 16#AAB7#, 16#AAB8#, 16#AABE#, 16#AABF#, 16#AAC1#, 16#FE20#, 16#FE21#, 16#FE22#, 16#FE23#,
      16#FE24#, 16#FE25#, 16#FE26#, 16#10A0F#, 16#10A38#, 16#1D185#, 16#1D186#, 16#1D187#, 16#1D188#,
      16#1D189#, 16#1D1AA#, 16#1D1AB#, 16#1D1AC#, 16#1D1AD#, 16#1D242#, 16#1D243#, 16#1D244#];

   --  Kitty takes base64 data in chunks of at most this many bytes.
   Chunk_Size : constant := 4096;

   function Image (Value : Natural) return String;

   function Base64 (Data : String) return String is
      Alphabet : constant String := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      Result   : String (1 .. (Data'Length + 2) / 3 * 4);
      Last     : Natural := 0;
      I        : Natural := Data'First;

      function Byte (Index : Natural) return Natural is
        (if Index <= Data'Last then Character'Pos (Data (Index)) else 0);
   begin
      while I <= Data'Last loop
         declare
            Group : constant Natural := Byte (I) * 65536 + Byte (I + 1) * 256 + Byte (I + 2);
            Count : constant Natural := Natural'Min (3, Data'Last - I + 1);
         begin
            Result (Last + 1) := Alphabet (Group / 262144 + 1);
            Result (Last + 2) := Alphabet (Group / 4096 mod 64 + 1);
            Result (Last + 3) := (if Count >= 2 then Alphabet (Group / 64 mod 64 + 1) else '=');
            Result (Last + 4) := (if Count = 3 then Alphabet (Group mod 64 + 1) else '=');
            Last := Last + 4;
            I := I + 3;
         end;
      end loop;

      return Result (1 .. Last);
   end Base64;

   function Delete (Id : Positive; In_Tmux : Boolean) return String is
     (Explore.Protocol.To_Outer_Terminal (ESC & "_Ga=d,d=I,i=" & Image (Id) & ",q=2" & ESC & "\", In_Tmux));

   function Delete_All (In_Tmux : Boolean) return String is
     (Explore.Protocol.To_Outer_Terminal (ESC & "_Ga=d,d=A,q=2" & ESC & "\", In_Tmux));

   function Diacritic (Value : Natural) return Wide_Wide_Character is
     (Wide_Wide_Character'Val (Diacritics (Value)));

   procedure Fit
     (Width, Height           : Positive;
      Cell_Width, Cell_Height : Positive;
      Max_Columns, Max_Rows   : Positive;
      Columns, Rows           : out Positive)
   is
      --  Scale to the pane's pixels, no further than the image's own size.
      Room_Width  : constant Long_Long_Integer := Long_Long_Integer (Max_Columns) * Long_Long_Integer (Cell_Width);
      Room_Height : constant Long_Long_Integer := Long_Long_Integer (Max_Rows) * Long_Long_Integer (Cell_Height);
      Shown_Width : Long_Long_Integer := Long_Long_Integer (Width);
      Shown_Height : Long_Long_Integer := Long_Long_Integer (Height);
   begin
      if Shown_Width > Room_Width then
         Shown_Height := Shown_Height * Room_Width / Shown_Width;
         Shown_Width := Room_Width;
      end if;

      if Shown_Height > Room_Height then
         Shown_Width := Shown_Width * Room_Height / Shown_Height;
         Shown_Height := Room_Height;
      end if;

      Columns := Positive (Long_Long_Integer'Max (1, (Shown_Width + Long_Long_Integer (Cell_Width) - 1)
                                                      / Long_Long_Integer (Cell_Width)));
      Rows := Positive (Long_Long_Integer'Max (1, (Shown_Height + Long_Long_Integer (Cell_Height) - 1)
                                                   / Long_Long_Integer (Cell_Height)));
      Columns := Positive'Min (Columns, Max_Columns);
      Rows := Positive'Min (Rows, Max_Rows);
   end Fit;

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Is_JPEG (Data : String) return Boolean is
     (Data'Length >= 3
      and then Character'Pos (Data (Data'First)) = 16#FF#
      and then Character'Pos (Data (Data'First + 1)) = 16#D8#
      and then Character'Pos (Data (Data'First + 2)) = 16#FF#);

   function Is_PNG (Data : String) return Boolean is
     (Data'Length >= 8
      and then Data (Data'First .. Data'First + 7)
        = Character'Val (16#89#) & "PNG" & Character'Val (13) & Character'Val (10) & Character'Val (26)
          & Character'Val (10));

   function PNG_Size (Data : String; Width, Height : out Natural) return Boolean is
      function Byte (At_Offset : Natural) return Long_Long_Integer is
        (Long_Long_Integer (Character'Pos (Data (Data'First + At_Offset))));

      --  A big-endian 32-bit word; anything past Natural'Last is no size an
      --  image here can have.
      function Word (At_Offset : Natural) return Natural is
        (Natural (Long_Long_Integer'Min
                    (Long_Long_Integer (Natural'Last),
                     Byte (At_Offset) * 2 ** 24 + Byte (At_Offset + 1) * 2 ** 16
                     + Byte (At_Offset + 2) * 2 ** 8 + Byte (At_Offset + 3))));
   begin
      Width := 0;
      Height := 0;

      --  The signature, then the IHDR chunk: length, type, width, height.
      if not Is_PNG (Data) or else Data'Length < 24 or else Data (Data'First + 12 .. Data'First + 15) /= "IHDR" then
         return False;
      end if;

      Width := Word (16);
      Height := Word (20);
      return Width > 0 and then Height > 0;
   end PNG_Size;

   function Transmit_PNG (Id : Positive; Data : String; Columns, Rows : Positive; In_Tmux : Boolean) return String is
      Encoded : constant String := Base64 (Data);
      Result  : Ada.Strings.Unbounded.Unbounded_String;
      First   : Positive := Encoded'First;
   begin
      loop
         declare
            Last  : constant Natural := Natural'Min (Encoded'Last, First + Chunk_Size - 1);
            More  : constant Character := (if Last < Encoded'Last then '1' else '0');
            Keys  : constant String :=
              (if First = Encoded'First
               then "a=T,f=100,t=d,i=" & Image (Id) & ",q=2,U=1,c=" & Image (Columns) & ",r=" & Image (Rows) & ",m="
               else "m=");
         begin
            Ada.Strings.Unbounded.Append (Result, Explore.Protocol.To_Outer_Terminal
                              (ESC & "_G" & Keys & More & ";" & Encoded (First .. Last) & ESC & "\", In_Tmux));
            exit when Last >= Encoded'Last;
            First := Last + 1;
         end;
      end loop;

      return Ada.Strings.Unbounded.To_String (Result);
   end Transmit_PNG;
end Explore.Images;
