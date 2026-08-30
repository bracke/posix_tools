with Ada.Containers.Vectors;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Text.OD_Formats;

package Posix_Tools.Commands.Od_Rendering is
   type Dump_Kind is
     (Named_Byte, Character_Byte, Signed_Integer, Floating_Point, Octal_Integer, Unsigned_Integer, Hex_Integer);

   type Dump_Spec is record
      Kind : Dump_Kind := Octal_Integer;
      Size : Positive := 1;
   end record;

   package Dump_Spec_Vectors is new Ada.Containers.Vectors (Positive, Dump_Spec);

   procedure Append_Dump_Format
     (Formats : in out Dump_Spec_Vectors.Vector;
      Parsed  : Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item);

   function Append_Shorthand_Format
     (Formats : in out Dump_Spec_Vectors.Vector;
      Option  : Character) return Boolean;

   function Append_Shorthand_Formats
     (Formats : in out Dump_Spec_Vectors.Vector;
      Option  : String) return Boolean;

   procedure Render
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text        : String;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean);
end Posix_Tools.Commands.Od_Rendering;
