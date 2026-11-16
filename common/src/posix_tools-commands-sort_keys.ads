with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Sort_Key_Text;
with Posix_Tools.Numbers;
with Posix_Tools.Streams.Lines;

package Posix_Tools.Commands.Sort_Keys is
   --  The ordering options of POSIX sort: -b -d -f -i -n -r. They are given
   --  either globally or attached to one -k key, and a key with any of them
   --  attached uses only its own.
   type Ordering_Rules is record
      Fold_Case             : Boolean := False;
      Numeric_Sort          : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order      : Boolean := False;
      Ignore_Nonprinting    : Boolean := False;
      Reverse_Order         : Boolean := False;
   end record;

   type Sort_Key_Definition is record
      Field_Start     : Positive := 1;
      Field_End       : Natural := 0;
      Character_Start : Positive := 1;
      Character_End   : Natural := 0;
      Rules           : Ordering_Rules;
      Has_Modifiers   : Boolean := False;
   end record;

   package Sort_Key_Vectors is new Ada.Containers.Vectors (Positive, Sort_Key_Definition);

   type Sort_Options is record
      Keys                : Sort_Key_Vectors.Vector;
      Global              : Ordering_Rules;
      Field_Separator     : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Stable_Sort         : Boolean := False;
      Unique              : Boolean := False;
      --  The collation locale, and the one -n reads numbers in.
      Locale              : Ada.Strings.Unbounded.Unbounded_String;
      Numeric_Locale      : Ada.Strings.Unbounded.Unbounded_String;
      --  Cached once by the command so numeric key preparation does not
      --  reload locale number-format data for every record.
      ASCII_Numeric_Format : Boolean := False;
   end record;

   --  Reusable prepared comparisons for bounded/external sorting.  Preparing
   --  each line once avoids rebuilding locale and numeric keys during merge.
   type Comparator is private;
   type Prepared_Line is private;

   procedure Initialize (Self : out Comparator; Options : Sort_Options);
   function Uses_Direct_Text_Key (Self : Comparator) return Boolean;
   function Prepare_Line (Self : Comparator; Line : String) return Prepared_Line;
   function Prepare_Line
     (Self : Comparator;
      Line : Ada.Strings.Unbounded.Unbounded_String) return Prepared_Line;
   function Estimated_Storage_Size
     (Self : Comparator;
      Line : String) return Posix_Tools.Numbers.Count;
   function Compare
     (Self : Comparator; Left, Right : Prepared_Line) return Integer;
   function Keys_Equal
     (Self : Comparator; Left, Right : Prepared_Line) return Boolean;
   function Original (Line : Prepared_Line) return String;
   function Original_Length (Line : Prepared_Line) return Natural;
   function Original_Slice
     (Line : Prepared_Line;
      Low  : Positive;
      High : Natural) return String;

   --  Sorts Lines stably in O(n log n), building every line's comparison keys
   --  once. With Options.Unique only the first line of each run of lines
   --  whose keys compare equal is kept.
   procedure Sort_Lines
     (Lines   : in out Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options);

   --  The index of the first line of Lines out of the order Sort_Lines would
   --  produce, or, with Options.Unique, the first whose key equals the one
   --  before it; 0 when there is none.
   function First_Disorder
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Natural;

private
   use type Posix_Tools.Commands.Sort_Key_Text.Key_Range;
   package Rule_Vectors is new Ada.Containers.Vectors (Positive, Ordering_Rules);
   package Boolean_Vectors is new Ada.Containers.Vectors (Positive, Boolean);
   package Range_Vectors is new Ada.Containers.Vectors
     (Positive, Posix_Tools.Commands.Sort_Key_Text.Key_Range);

   type Comparator is record
      Options      : Sort_Options;
      Rules        : Rule_Vectors.Vector;
      Range_Keys   : Boolean_Vectors.Vector;
      Whole_Line   : Boolean := True;
      Direct_Text_Key : Boolean := False;
      Use_Whole    : Boolean := False;
      Last_Resort  : Boolean := True;
      Reverse_Last : Boolean := False;
   end record;

   type Prepared_Line is record
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Keys  : Posix_Tools.Streams.Lines.Segment_Vector;
      Ranges : Range_Vectors.Vector;
      Whole : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Posix_Tools.Commands.Sort_Keys;
