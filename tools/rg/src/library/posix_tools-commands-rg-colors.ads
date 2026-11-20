with Ada.Strings.Unbounded;
with Terminal_Styles;

--  Iterative ripgrep color-rule parsing backed by terminal_styles values.
package Posix_Tools.Commands.Rg.Colors is
   type Output_Role is (Path_Role, Line_Role, Column_Role, Match_Role, Highlight_Role);

   type Text_Style is private;
   type Palette is private;

   function Default_Palette return Palette;

   procedure Apply
     (Value      : in out Palette;
      Rule       : String;
      Success    : out Boolean;
      Diagnostic : out Ada.Strings.Unbounded.Unbounded_String);

   function Style (Value : Palette; Role : Output_Role) return Text_Style;
   function Enabled (Value : Text_Style) return Boolean;
   function Prefix (Value : Text_Style) return String;

private
   type Color_Kind is (Default_Color, Basic_Color, Indexed_Color, RGB_Color);

   subtype Color_Component is Natural range 0 .. 255;

   type Color_Value is record
      Kind  : Color_Kind := Default_Color;
      Basic : Terminal_Styles.Terminal_Color := Terminal_Styles.Color_Default;
      Red   : Color_Component := 0;
      Green : Color_Component := 0;
      Blue  : Color_Component := 0;
   end record;

   type Text_Style is record
      Is_Enabled : Boolean := False;
      Foreground_Color : Color_Value;
      Background_Color : Color_Value;
      Is_Bold : Boolean := False;
      Is_Intense : Boolean := False;
      Is_Underlined : Boolean := False;
      Is_Italic : Boolean := False;
   end record;

   type Style_Array is array (Output_Role) of Text_Style;

   type Palette is record
      Styles : Style_Array;
   end record;
end Posix_Tools.Commands.Rg.Colors;
