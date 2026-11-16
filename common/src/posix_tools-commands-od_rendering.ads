with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Helpers;
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

   type Renderer is private;

   procedure Initialize
     (State       : out Renderer;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean);

   procedure Feed
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text    : String);

   procedure Finish
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   --  Emit completed rendered lines without completing a partial input block.
   procedure Flush_Output
     (State   : in out Renderer;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Render
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Text        : String;
      Actual_Skip : Natural;
      Address     : Posix_Tools.Text.OD_Formats.Address_Base;
      Formats     : Dump_Spec_Vectors.Vector;
      Verbose     : Boolean);

private
   type Renderer is record
      Actual_Skip  : Natural := 0;
      Offset       : Natural := 0;
      Address      : Posix_Tools.Text.OD_Formats.Address_Base :=
        Posix_Tools.Text.OD_Formats.Octal_Address;
      Formats      : Dump_Spec_Vectors.Vector;
      Verbose      : Boolean := False;
      Previous_Block : Ada.Strings.Unbounded.Unbounded_String;
      Pending      : Ada.Strings.Unbounded.Unbounded_String;
      Output_Buffer : Posix_Tools.Commands.Helpers.Output_Buffer;
      Have_Previous : Boolean := False;
      Suppressed    : Boolean := False;
   end record;
end Posix_Tools.Commands.Od_Rendering;
