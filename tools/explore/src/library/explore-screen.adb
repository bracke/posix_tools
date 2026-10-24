with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Text.UTF_8;

package body Explore.Screen is
   package Unbounded renames Ada.Strings.Unbounded;

   use type Posix_Tools.Text.UTF_8.Decode_Status;

   ESC : constant Character := Character'Val (27);

   Replacement : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#FFFD#);

   --  Call Action with each character of the UTF-8 Text as it is shown and
   --  the cells it takes, until Action sets Stop.
   generic
      with procedure Action (Code : Wide_Wide_Character; Cells : Natural; Stop : in out Boolean);
   procedure For_Each_Shown (Text : String);

   function Image (Value : Natural) return String;

   function Index (Self : Grid; Row, Column : Positive) return Positive is
     ((Row - 1) * Self.Width + Column);

   function SGR (Item : Style) return String;

   function Cell_At (Self : Grid; Row, Column : Positive) return Cell is
     (Self.Cells (Index (Self, Row, Column)));

   procedure Clear (Self : in out Grid) is
   begin
      for Item of Self.Cells loop
         Item := (others => <>);
      end loop;
   end Clear;

   function Clipped (Text : String; Width : Natural) return String is
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Status  : Posix_Tools.Text.UTF_8.Decode_Status;
      Code    : Long_Long_Integer;
      Taken   : Natural := 0;
      Last    : Natural := Text'First - 1;
   begin
      for I in Text'Range loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code);

         if Status /= Posix_Tools.Text.UTF_8.Need_More then
            declare
               Cells : constant Natural :=
                 (if Status = Posix_Tools.Text.UTF_8.Invalid or else Code < 32 or else Code in 127 .. 159 then 1
                  else Posix_Tools.Commands.Text_Helpers.Display.Display_Width (Code));
            begin
               exit when Taken + Cells > Width;
               Taken := Taken + Cells;
               Last := I;
            end;
         end if;
      end loop;

      return Text (Text'First .. Last);
   end Clipped;

   function Columns (Self : Grid) return Natural is (Self.Width);

   procedure Fill
     (Self       : in out Grid;
      Row        : Positive;
      Column     : Positive;
      Width      : Natural;
      Item_Style : Style)
   is
   begin
      if Row > Self.Height then
         return;
      end if;

      for C in Column .. Natural'Min (Self.Width, Column + Width - 1) loop
         Self.Cells (Index (Self, Row, C)) := (Code => ' ', Item_Style => Item_Style, Continuation => False);
      end loop;
   end Fill;

   procedure For_Each_Shown (Text : String) is
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Status  : Posix_Tools.Text.UTF_8.Decode_Status;
      Code    : Long_Long_Integer;
      Stop    : Boolean := False;
   begin
      for C of Text loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (C), Status, Code);

         case Status is
            when Posix_Tools.Text.UTF_8.Complete =>
               if Code < 32 or else Code in 127 .. 159 then
                  Action ('?', 1, Stop);
               else
                  declare
                     Cells : constant Natural := Posix_Tools.Commands.Text_Helpers.Display.Display_Width (Code);
                  begin
                     if Cells > 0 then
                        Action (Wide_Wide_Character'Val (Code), Cells, Stop);
                     end if;
                  end;
               end if;
            when Posix_Tools.Text.UTF_8.Invalid =>
               Action (Replacement, 1, Stop);
            when Posix_Tools.Text.UTF_8.Need_More =>
               null;
         end case;

         exit when Stop;
      end loop;
   end For_Each_Shown;

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   procedure Put
     (Self       : in out Grid;
      Row        : Positive;
      Column     : Positive;
      Text       : String;
      Item_Style : Style;
      Width      : Natural;
      Used       : out Natural)
   is
      Limit : constant Natural :=
        (if Row > Self.Height or else Column > Self.Width then 0
         else Natural'Min (Width, Self.Width - Column + 1));
      At_Column : Positive := Column;

      procedure Place (Code : Wide_Wide_Character; Cells : Natural; Stop : in out Boolean);

      procedure Place (Code : Wide_Wide_Character; Cells : Natural; Stop : in out Boolean) is
      begin
         if At_Column - Column + Cells > Limit then
            Stop := True;
            return;
         end if;

         Self.Cells (Index (Self, Row, At_Column)) := (Code => Code, Item_Style => Item_Style, Continuation => False);

         if Cells = 2 then
            Self.Cells (Index (Self, Row, At_Column + 1)) :=
              (Code => ' ', Item_Style => Item_Style, Continuation => True);
         end if;

         At_Column := At_Column + Cells;
      end Place;

      procedure Each is new For_Each_Shown (Place);
   begin
      if Limit > 0 then
         Each (Text);
      end if;

      Used := At_Column - Column;
   end Put;

   function Render (Shown : in out Grid; Wanted : Grid; Full : Boolean := False) return String is
      Output      : Unbounded.Unbounded_String;
      Everything  : constant Boolean := Full or else Shown.Height /= Wanted.Height or else Shown.Width /= Wanted.Width;
      Cursor_Row  : Natural := 0;
      Cursor_Col  : Natural := 0;
      Style_Known : Boolean := False;
      Current     : Style := Plain;
   begin
      if Everything then
         Unbounded.Append (Output, ESC & "[0m" & ESC & "[2J");
      end if;

      for Row in 1 .. Wanted.Height loop
         declare
            Column : Positive := 1;
         begin
            while Column <= Wanted.Width loop
               declare
                  Want : constant Cell := Cell_At (Wanted, Row, Column);
                  Wide : constant Boolean :=
                    Column < Wanted.Width and then Cell_At (Wanted, Row, Column + 1).Continuation;
                  Changed : Boolean :=
                    Everything
                    or else Cell_At (Shown, Row, Column) /= Want
                    or else (Wide and then Cell_At (Shown, Row, Column + 1) /= Cell_At (Wanted, Row, Column + 1));
               begin
                  --  A stray continuation, its wide character overwritten, is a blank.
                  if Want.Continuation and then not Changed then
                     Column := Column + 1;
                  else
                     if Want.Continuation then
                        Changed := True;
                     end if;

                     if Changed then
                        if Cursor_Row /= Row or else Cursor_Col /= Column then
                           Unbounded.Append (Output, ESC & "[" & Image (Row) & ";" & Image (Column) & "H");
                        end if;

                        if not Style_Known or else Current /= Want.Item_Style then
                           Unbounded.Append (Output, SGR (Want.Item_Style));
                           Current := Want.Item_Style;
                           Style_Known := True;
                        end if;

                        if Want.Continuation then
                           Unbounded.Append (Output, ' ');
                        else
                           Unbounded.Append
                             (Output, Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ([1 => Want.Code]));
                        end if;

                        Cursor_Row := Row;
                        Cursor_Col := Column + (if Wide then 2 else 1);
                     end if;

                     Column := Column + (if Wide then 2 else 1);
                  end if;
               end;
            end loop;
         end;
      end loop;

      if Style_Known then
         Unbounded.Append (Output, ESC & "[0m");
      end if;

      Shown := Wanted;
      return Unbounded.To_String (Output);
   end Render;

   procedure Resize (Self : in out Grid; Rows, Columns : Natural) is
   begin
      Self.Height := Rows;
      Self.Width := Columns;
      Self.Cells := Cell_Vectors.To_Vector ((others => <>), Ada.Containers.Count_Type (Rows * Columns));
   end Resize;

   function Rows (Self : Grid) return Natural is (Self.Height);

   function SGR (Item : Style) return String is
      Codes : Unbounded.Unbounded_String := Unbounded.To_Unbounded_String ("0");

      function Color_Code (Value : Color; Base : Natural) return String is
        (if Value in 0 .. 7 then Image (Base + Natural (Value))
         elsif Value in 8 .. 15 then Image (Base + 60 + Natural (Value) - 8)
         else Image (Base + 8) & ";5;" & Image (Natural (Value)));
   begin
      if Item.Bold then
         Unbounded.Append (Codes, ";1");
      end if;

      if Item.Dim then
         Unbounded.Append (Codes, ";2");
      end if;

      if Item.Underline then
         Unbounded.Append (Codes, ";4");
      end if;

      if Item.Inverse then
         Unbounded.Append (Codes, ";7");
      end if;

      if Item.Foreground /= Default_Color then
         Unbounded.Append (Codes, ";" & Color_Code (Item.Foreground, 30));
      end if;

      if Item.Background /= Default_Color then
         Unbounded.Append (Codes, ";" & Color_Code (Item.Background, 40));
      end if;

      return ESC & "[" & Unbounded.To_String (Codes) & "m";
   end SGR;

   function Width_Of (Text : String) return Natural is
      Total : Natural := 0;

      procedure Count (Code : Wide_Wide_Character; Cells : Natural; Stop : in out Boolean);

      procedure Count (Code : Wide_Wide_Character; Cells : Natural; Stop : in out Boolean) is
         pragma Unreferenced (Code, Stop);
      begin
         Total := Total + Cells;
      end Count;

      procedure Each is new For_Each_Shown (Count);
   begin
      Each (Text);
      return Total;
   end Width_Of;
end Explore.Screen;
