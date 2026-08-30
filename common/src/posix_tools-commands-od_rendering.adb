with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Conversion;
with Interfaces;

package body Posix_Tools.Commands.Od_Rendering is
   use Ada.Strings.Unbounded;
   use type Interfaces.Unsigned_64;
   use type Posix_Tools.Text.OD_Formats.Address_Base;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   function Floating_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String;

   function To_Dump_Kind (Kind : Posix_Tools.Text.OD_Formats.Dump_Format_Kind) return Dump_Kind;

   function Unit_Field (Spec : Dump_Spec; Text : String; First : Positive) return String;

   procedure Append_Dump_Format
     (Formats : in out Dump_Spec_Vectors.Vector;
      Parsed  : Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item)
   is
   begin
      Formats.Append
        (Dump_Spec'(Kind => To_Dump_Kind (Parsed.Kind), Size => Parsed.Size));
   end Append_Dump_Format;

   function Append_Shorthand_Format
     (Formats : in out Dump_Spec_Vectors.Vector;
      Option  : Character) return Boolean
   is
      Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
        Posix_Tools.Text.OD_Formats.Shorthand_Format_Item (Option);
   begin
      if not Parsed.Valid then
         return False;
      end if;
      Append_Dump_Format (Formats, Parsed);
      return True;
   end Append_Shorthand_Format;

   function Append_Shorthand_Formats
     (Formats : in out Dump_Spec_Vectors.Vector;
      Option  : String) return Boolean
   is
   begin
      if Option'Length <= 1 then
         return False;
      end if;

      for I in Option'First + 1 .. Option'Last loop
         if not Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option (Option (I)) then
            return False;
         end if;
      end loop;

      for I in Option'First + 1 .. Option'Last loop
         if not Append_Shorthand_Format (Formats, Option (I)) then
            return False;
         end if;
      end loop;
      return True;
   end Append_Shorthand_Formats;

   function Floating_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String is
      subtype U32 is Interfaces.Unsigned_32;
      subtype U64 is Interfaces.Unsigned_64;
      function To_Float_32 is new Ada.Unchecked_Conversion (U32, Interfaces.IEEE_Float_32);
      function To_Float_64 is new Ada.Unchecked_Conversion (U64, Interfaces.IEEE_Float_64);
   begin
      if Size = 4 then
         return Interfaces.IEEE_Float_32'Image (To_Float_32 (U32 (Value)));
      else
         return Interfaces.IEEE_Float_64'Image (To_Float_64 (Value));
      end if;
   end Floating_Image;

   procedure Render
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text        : String;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean)
   is
      Offset         : Natural := 0;
      Previous_Block : String_Vectors.Vector;
      Have_Previous  : Boolean := False;
      Suppressed     : Boolean := False;
   begin
      while Offset < Text'Length loop
         declare
            Line_Last     : constant Natural := Natural'Min (Text'Length, Offset + 16);
            Current_Block : String_Vectors.Vector;
         begin
            for Format_Index in Formats.First_Index .. Formats.Last_Index loop
               declare
                  Spec   : constant Dump_Spec := Formats.Element (Format_Index);
                  Output : Unbounded_String;
               begin
                  declare
                     I : Natural := Text'First + Offset;
                  begin
                     while I <= Text'First + Line_Last - 1 loop
                        Append (Output, Unit_Field (Spec, Text, I));
                        I := I + Spec.Size;
                     end loop;
                  end;
                  Current_Block.Append (To_String (Output));
               end;
            end loop;

            if not Verbose and then Have_Previous and then String_Vectors."=" (Current_Block, Previous_Block) then
               if not Suppressed then
                  Context.Put_Line ("*");
                  Suppressed := True;
               end if;
            else
               for Format_Index in Current_Block.First_Index .. Current_Block.Last_Index loop
                  Context.Put_Line
                    ((if Address = Posix_Tools.Text.OD_Formats.No_Address
                      or else Format_Index /= Current_Block.First_Index
                      then ""
                      else Posix_Tools.Text.OD_Formats.Address_Image (Address, Actual_Skip + Offset))
                     & Current_Block.Element (Format_Index));
               end loop;
               Previous_Block := Current_Block;
               Have_Previous := True;
               Suppressed := False;
            end if;
            Offset := Line_Last;
         end;
      end loop;
      if Address /= Posix_Tools.Text.OD_Formats.No_Address then
         Context.Put_Line
           (Posix_Tools.Text.OD_Formats.Address_Image (Address, Actual_Skip + Text'Length));
      end if;
   end Render;

   function To_Dump_Kind (Kind : Posix_Tools.Text.OD_Formats.Dump_Format_Kind) return Dump_Kind is
   begin
      case Kind is
         when Posix_Tools.Text.OD_Formats.Named_Byte =>
            return Named_Byte;
         when Posix_Tools.Text.OD_Formats.Character_Byte =>
            return Character_Byte;
         when Posix_Tools.Text.OD_Formats.Signed_Integer =>
            return Signed_Integer;
         when Posix_Tools.Text.OD_Formats.Floating_Point =>
            return Floating_Point;
         when Posix_Tools.Text.OD_Formats.Octal_Integer =>
            return Octal_Integer;
         when Posix_Tools.Text.OD_Formats.Unsigned_Integer =>
            return Unsigned_Integer;
         when Posix_Tools.Text.OD_Formats.Hex_Integer =>
            return Hex_Integer;
      end case;
   end To_Dump_Kind;

   function Unit_Field (Spec : Dump_Spec; Text : String; First : Positive) return String is
      Value : constant Interfaces.Unsigned_64 :=
        Posix_Tools.Text.OD_Formats.Unit_Value (Text, First, Spec.Size);
   begin
      case Spec.Kind is
         when Named_Byte =>
            return Posix_Tools.Text.OD_Formats.Named_Field (Text (First));
         when Character_Byte =>
            return Posix_Tools.Text.OD_Formats.Character_Field (Text (First));
         when Signed_Integer =>
            return " " & Posix_Tools.Text.OD_Formats.Signed_Image (Value, Spec.Size);
         when Floating_Point =>
            return " " & Floating_Image (Value, Spec.Size);
         when Octal_Integer =>
            return " " & Posix_Tools.Text.OD_Formats.Octal_U64_Image (Value, Spec.Size * 3);
         when Unsigned_Integer =>
            return " " & Posix_Tools.Text.OD_Formats.Decimal_U64_Image (Value);
         when Hex_Integer =>
            return " " & Posix_Tools.Text.OD_Formats.Hex_U64_Image (Value, Spec.Size * 2);
      end case;
   end Unit_Field;
end Posix_Tools.Commands.Od_Rendering;
