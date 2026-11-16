with Ada.Unchecked_Conversion;
with Interfaces;

package body Posix_Tools.Commands.Od_Rendering is
   use Ada.Strings.Unbounded;
   use type Interfaces.Unsigned_64;
   use type Posix_Tools.Text.OD_Formats.Address_Base;

   function Floating_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String;

   function To_Dump_Kind (Kind : Posix_Tools.Text.OD_Formats.Dump_Format_Kind) return Dump_Kind;

   function Unit_Field (Spec : Dump_Spec; Text : String; First : Positive) return String;

   procedure Emit_Block
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Block   : String);

   procedure Emit_Line
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text    : String);

   procedure Emit_Line
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text    : String)
   is
   begin
      Posix_Tools.Commands.Helpers.Buffered_Put_Line
        (State.Output_Buffer, Context, Text);
   end Emit_Line;

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

   procedure Emit_Block
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Block   : String)
   is
   begin
      if not State.Verbose
        and then State.Have_Previous
        and then Block = To_String (State.Previous_Block)
      then
         if not State.Suppressed then
            Emit_Line (State, Context, "*");
            State.Suppressed := True;
         end if;
         State.Offset := State.Offset + Block'Length;
         return;
      end if;

      for Format_Index in State.Formats.First_Index .. State.Formats.Last_Index loop
         declare
            Spec   : constant Dump_Spec := State.Formats.Element (Format_Index);
            Output : Unbounded_String;
            I      : Natural := Block'First;
         begin
            while I <= Block'Last loop
               Append (Output, Unit_Field (Spec, Block, I));
               I := I + Spec.Size;
            end loop;
            Emit_Line
              (State, Context,
               (if State.Address = Posix_Tools.Text.OD_Formats.No_Address
                or else Format_Index /= State.Formats.First_Index
                then ""
                else Posix_Tools.Text.OD_Formats.Address_Image
                  (State.Address, State.Actual_Skip + State.Offset))
               & To_String (Output));
         end;
      end loop;
      State.Previous_Block := To_Unbounded_String (Block);
      State.Have_Previous := True;
      State.Suppressed := False;
      State.Offset := State.Offset + Block'Length;
   end Emit_Block;

   procedure Initialize
     (State       : out Renderer;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean) is
   begin
      State :=
        (Actual_Skip => Actual_Skip, Address => Address, Formats => Formats,
         Verbose => Verbose, others => <>);
   end Initialize;

   procedure Feed
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text    : String)
   is
      First : Natural := Text'First;
   begin
      if Length (State.Pending) > 0 then
         declare
            Needed : constant Natural := 16 - Length (State.Pending);
            Taken  : constant Natural := Natural'Min (Needed, Text'Length);
         begin
            if Taken > 0 then
               Append (State.Pending, Text (First .. First + Taken - 1));
               First := First + Taken;
            end if;
            if Length (State.Pending) = 16 then
               Emit_Block (State, Context, To_String (State.Pending));
               State.Pending := Null_Unbounded_String;
            end if;
         end;
      end if;

      while First + 15 <= Text'Last loop
         Emit_Block (State, Context, Text (First .. First + 15));
         First := First + 16;
      end loop;
      if First <= Text'Last then
         Append (State.Pending, Text (First .. Text'Last));
      end if;
   end Feed;

   procedure Finish
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
   begin
      if Length (State.Pending) > 0 then
         Emit_Block (State, Context, To_String (State.Pending));
         State.Pending := Null_Unbounded_String;
      end if;
      if State.Address /= Posix_Tools.Text.OD_Formats.No_Address then
         Emit_Line
           (State, Context,
            Posix_Tools.Text.OD_Formats.Address_Image
              (State.Address, State.Actual_Skip + State.Offset));
      end if;
      Flush_Output (State, Context);
   end Finish;

   procedure Flush_Output
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class)
   is
   begin
      Posix_Tools.Commands.Helpers.Flush_Output
        (State.Output_Buffer, Context);
   end Flush_Output;

   procedure Render
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text        : String;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean)
   is
      State : Renderer;
   begin
      Initialize (State, Actual_Skip, Address, Formats, Verbose);
      Feed (State, Context, Text);
      Finish (State, Context);
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
