with Ada.Strings.Fixed;

package body Posix_Tools.Commands.Rg.Colors is
   use Ada.Strings.Unbounded;

   Escape : constant String := Character'Val (16#1B#) & "[";

   function Basic_Color (Text : String; Found : out Boolean) return Terminal_Styles.Terminal_Color;
   function Parse_Color (Text : String; Value : out Color_Value) return Boolean;
   function Role_Value (Text : String; Found : out Boolean) return Output_Role;

   function Basic_Color (Text : String; Found : out Boolean) return Terminal_Styles.Terminal_Color is
   begin
      Found := True;
      if Text = "black" then
         return Terminal_Styles.Color_Black;
      elsif Text = "red" then
         return Terminal_Styles.Color_Red;
      elsif Text = "green" then
         return Terminal_Styles.Color_Green;
      elsif Text = "yellow" then
         return Terminal_Styles.Color_Yellow;
      elsif Text = "blue" then
         return Terminal_Styles.Color_Blue;
      elsif Text = "magenta" then
         return Terminal_Styles.Color_Magenta;
      elsif Text = "cyan" then
         return Terminal_Styles.Color_Cyan;
      elsif Text = "white" then
         return Terminal_Styles.Color_White;
      else
         Found := False;
         return Terminal_Styles.Color_Default;
      end if;
   end Basic_Color;

   function Parse_Component (Text : String; Value : out Color_Component) return Boolean is
      Result : Natural := 0;
      Digit  : Natural;
   begin
      Value := 0;
      if Text'Length = 0 then
         return False;
      end if;
      for Item of Text loop
         if Item not in '0' .. '9' then
            return False;
         end if;
         Digit := Character'Pos (Item) - Character'Pos ('0');
         if Result > (Color_Component'Last - Digit) / 10 then
            return False;
         end if;
         Result := Result * 10 + Digit;
      end loop;
      Value := Result;
      return True;
   end Parse_Component;

   function Parse_Color (Text : String; Value : out Color_Value) return Boolean is
      Found : Boolean;
      Basic : constant Terminal_Styles.Terminal_Color := Basic_Color (Text, Found);
      First_Comma : Natural;
      Second_Comma : Natural;
      Red, Green, Blue : Color_Component;
   begin
      Value := (others => <>);
      if Found then
         Value.Kind := Basic_Color;
         Value.Basic := Basic;
         return True;
      end if;

      First_Comma := Ada.Strings.Fixed.Index (Text, ",");
      if First_Comma = 0 then
         if Parse_Component (Text, Red) then
            Value.Kind := Indexed_Color;
            Value.Red := Red;
            return True;
         end if;
         return False;
      end if;

      Second_Comma := Ada.Strings.Fixed.Index (Text (First_Comma + 1 .. Text'Last), ",");
      if First_Comma = Text'First
        or else Second_Comma = 0
        or else Second_Comma = First_Comma + 1
        or else Second_Comma = Text'Last
        or else Ada.Strings.Fixed.Index (Text (Second_Comma + 1 .. Text'Last), ",") /= 0
      then
         return False;
      end if;
      if not Parse_Component (Text (Text'First .. First_Comma - 1), Red)
        or else not Parse_Component (Text (First_Comma + 1 .. Second_Comma - 1), Green)
        or else not Parse_Component (Text (Second_Comma + 1 .. Text'Last), Blue)
      then
         return False;
      end if;
      Value := (Kind => RGB_Color, Red => Red, Green => Green, Blue => Blue, others => <>);
      return True;
   end Parse_Color;

   function Role_Value (Text : String; Found : out Boolean) return Output_Role is
   begin
      Found := True;
      if Text = "path" then
         return Path_Role;
      elsif Text = "line" then
         return Line_Role;
      elsif Text = "column" then
         return Column_Role;
      elsif Text = "match" then
         return Match_Role;
      elsif Text = "highlight" then
         return Highlight_Role;
      else
         Found := False;
         return Path_Role;
      end if;
   end Role_Value;

   function Default_Palette return Palette is
      Result : Palette;
   begin
      Result.Styles (Path_Role) :=
        (Is_Enabled => True,
         Foreground_Color => (Kind => Basic_Color, Basic => Terminal_Styles.Color_Magenta, others => <>),
         others => <>);
      Result.Styles (Line_Role) :=
        (Is_Enabled => True,
         Foreground_Color => (Kind => Basic_Color, Basic => Terminal_Styles.Color_Green, others => <>),
         others => <>);
      Result.Styles (Column_Role) := Result.Styles (Line_Role);
      Result.Styles (Match_Role) :=
        (Is_Enabled => True,
         Foreground_Color => (Kind => Basic_Color, Basic => Terminal_Styles.Color_Red, others => <>),
         Is_Bold => True,
         others => <>);
      return Result;
   end Default_Palette;

   procedure Apply
     (Value      : in out Palette;
      Rule       : String;
      Success    : out Boolean;
      Diagnostic : out Unbounded_String)
   is
      First_Colon  : constant Natural := Ada.Strings.Fixed.Index (Rule, ":");
      Second_Colon : Natural := 0;
      Role_Found   : Boolean;
      Role         : Output_Role;

      procedure Fail (Text : String);

      procedure Fail (Text : String) is
      begin
         Success := False;
         Diagnostic := To_Unbounded_String (Text);
      end Fail;
   begin
      Success := False;
      Diagnostic := Null_Unbounded_String;
      if First_Colon = 0
        or else First_Colon = Rule'First
        or else First_Colon = Rule'Last
      then
         Fail ("invalid color specification: " & Rule);
         return;
      end if;

      Role := Role_Value (Rule (Rule'First .. First_Colon - 1), Role_Found);
      if not Role_Found then
         Fail ("unrecognized color output type: " & Rule (Rule'First .. First_Colon - 1));
         return;
      end if;

      if Rule (First_Colon + 1 .. Rule'Last) = "none" then
         Value.Styles (Role) := (others => <>);
         Success := True;
         return;
      end if;

      Second_Colon := Ada.Strings.Fixed.Index (Rule (First_Colon + 1 .. Rule'Last), ":");
      if Second_Colon = 0
        or else Second_Colon = First_Colon + 1
        or else Second_Colon = Rule'Last
      then
         Fail ("invalid color specification: " & Rule);
         return;
      end if;

      declare
         Attribute : constant String := Rule (First_Colon + 1 .. Second_Colon - 1);
         Item      : constant String := Rule (Second_Colon + 1 .. Rule'Last);
         Color     : Color_Value;
      begin
         if Attribute in "fg" | "bg" then
            if not Parse_Color (Item, Color) then
               Fail ("unrecognized color value: " & Item);
               return;
            end if;
            Value.Styles (Role).Is_Enabled := True;
            if Attribute = "fg" then
               Value.Styles (Role).Foreground_Color := Color;
            else
               Value.Styles (Role).Background_Color := Color;
            end if;
         elsif Attribute = "style" then
            Value.Styles (Role).Is_Enabled := True;
            if Item = "bold" then
               Value.Styles (Role).Is_Bold := True;
            elsif Item = "nobold" then
               Value.Styles (Role).Is_Bold := False;
            elsif Item = "intense" then
               Value.Styles (Role).Is_Intense := True;
            elsif Item = "nointense" then
               Value.Styles (Role).Is_Intense := False;
            elsif Item = "underline" then
               Value.Styles (Role).Is_Underlined := True;
            elsif Item = "nounderline" then
               Value.Styles (Role).Is_Underlined := False;
            elsif Item = "italic" then
               Value.Styles (Role).Is_Italic := True;
            elsif Item = "noitalic" then
               Value.Styles (Role).Is_Italic := False;
            else
               Fail ("unrecognized color style: " & Item);
               return;
            end if;
         else
            Fail ("unrecognized color attribute: " & Attribute);
            return;
         end if;
      end;
      Success := True;
   end Apply;

   function Style (Value : Palette; Role : Output_Role) return Text_Style is
   begin
      return Value.Styles (Role);
   end Style;

   function Enabled (Value : Text_Style) return Boolean is (Value.Is_Enabled);

   function Number_Image (Value : Natural) return String is
      Result : constant String := Natural'Image (Value);
   begin
      return Result (Result'First + 1 .. Result'Last);
   end Number_Image;

   function Basic_Index (Value : Terminal_Styles.Terminal_Color) return Natural is
   begin
      return
        (case Value is
           when Terminal_Styles.Color_Black          => 0,
           when Terminal_Styles.Color_Red            => 1,
           when Terminal_Styles.Color_Green          => 2,
           when Terminal_Styles.Color_Yellow         => 3,
           when Terminal_Styles.Color_Blue           => 4,
           when Terminal_Styles.Color_Magenta        => 5,
           when Terminal_Styles.Color_Cyan           => 6,
           when Terminal_Styles.Color_White          => 7,
           when Terminal_Styles.Color_Bright_Black   => 8,
           when Terminal_Styles.Color_Bright_Red     => 9,
           when Terminal_Styles.Color_Bright_Green   => 10,
           when Terminal_Styles.Color_Bright_Yellow  => 11,
           when Terminal_Styles.Color_Bright_Blue    => 12,
           when Terminal_Styles.Color_Bright_Magenta => 13,
           when Terminal_Styles.Color_Bright_Cyan    => 14,
           when Terminal_Styles.Color_Bright_White   => 15,
           when Terminal_Styles.Color_Default        => 0);
   end Basic_Index;

   function Color_Prefix
     (Value      : Color_Value;
      Foreground : Boolean;
      Intense    : Boolean) return String
   is
      Selector : constant String := (if Foreground then "38" else "48");
   begin
      case Value.Kind is
         when Default_Color =>
            return "";
         when Basic_Color =>
            declare
               Index : constant Natural := Basic_Index (Value.Basic);
            begin
               if Intense then
                  return Escape & Selector & ";5;" & Number_Image (Index mod 8 + 8) & "m";
               elsif Index < 8 then
                  return Escape
                    & Number_Image ((if Foreground then 30 else 40) + Index) & "m";
               else
                  return Escape
                    & Number_Image ((if Foreground then 90 else 100) + Index - 8) & "m";
               end if;
            end;
         when Indexed_Color =>
            return Escape & Selector & ";5;" & Number_Image (Value.Red) & "m";
         when RGB_Color =>
            return Escape & Selector & ";2;"
              & Number_Image (Value.Red) & ";"
              & Number_Image (Value.Green) & ";"
              & Number_Image (Value.Blue) & "m";
      end case;
   end Color_Prefix;

   function Prefix (Value : Text_Style) return String is
      Result : Unbounded_String := To_Unbounded_String (Escape & "0m");
   begin
      if Value.Is_Bold then
         Append (Result, Escape & "1m");
      end if;
      if Value.Is_Italic then
         Append (Result, Escape & "3m");
      end if;
      if Value.Is_Underlined then
         Append (Result, Escape & "4m");
      end if;
      Append (Result, Color_Prefix (Value.Foreground_Color, True, Value.Is_Intense));
      Append (Result, Color_Prefix (Value.Background_Color, False, Value.Is_Intense));
      return To_String (Result);
   end Prefix;
end Posix_Tools.Commands.Rg.Colors;
