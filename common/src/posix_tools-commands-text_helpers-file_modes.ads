with Ada.Strings.Unbounded;

package Posix_Tools.Commands.Text_Helpers.File_Modes is
   type Mode_Selection is private;

   type Selected_Mode is record
      Valid : Boolean := False;
      Mode  : Natural := 0;
   end record;

   function Is_Symbolic (Selection : Mode_Selection) return Boolean;

   function Selected
     (Selection : Mode_Selection;
      Base      : Natural;
      Mask      : Natural) return Selected_Mode;

   procedure Parse
     (Text      : String;
      Selection : out Mode_Selection;
      Accepted  : out Boolean);

private
   type Mode_Kind is (Octal_Mode, Symbolic_Mode);

   type Mode_Selection is record
      Kind : Mode_Kind := Octal_Mode;
      Bits : Natural := 0;
      Text : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Posix_Tools.Commands.Text_Helpers.File_Modes;
