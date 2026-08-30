with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Octal_Modes;

package body Posix_Tools.Commands.Text_Helpers.File_Modes is
   use Ada.Strings.Unbounded;

   function Is_Symbolic (Selection : Mode_Selection) return Boolean is
   begin
      return Selection.Kind = Symbolic_Mode;
   end Is_Symbolic;

   procedure Parse
     (Text      : String;
      Selection : out Mode_Selection;
      Accepted  : out Boolean)
   is
      Parsed_Octal : constant Posix_Tools.Text.Octal_Modes.Parsed_Mode :=
        Posix_Tools.Text.Octal_Modes.Parse_Mode (Text);
      Parsed_Symbolic : Posix_Tools.Text.File_Modes.Symbolic_Mode_Result;
   begin
      if Parsed_Octal.Valid then
         Selection :=
           (Kind => Octal_Mode,
            Bits => Parsed_Octal.Value,
            Text => Null_Unbounded_String);
         Accepted := True;
         return;
      end if;

      Parsed_Symbolic := Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode (Text, 0);
      if Parsed_Symbolic.Valid then
         Selection :=
           (Kind => Symbolic_Mode,
            Bits => 0,
            Text => To_Unbounded_String (Text));
         Accepted := True;
      else
         Selection :=
           (Kind => Octal_Mode,
            Bits => 0,
            Text => Null_Unbounded_String);
         Accepted := False;
      end if;
   end Parse;

   function Selected
     (Selection : Mode_Selection;
      Base      : Natural;
      Mask      : Natural) return Selected_Mode
   is
      Parsed : Posix_Tools.Text.File_Modes.Symbolic_Mode_Result;
   begin
      if Selection.Kind = Octal_Mode then
         return (Valid => True, Mode => Selection.Bits);
      end if;

      Parsed :=
        Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode
          (To_String (Selection.Text), Base mod Mask);
      return (Valid => Parsed.Valid, Mode => Parsed.Mode);
   end Selected;
end Posix_Tools.Commands.Text_Helpers.File_Modes;
