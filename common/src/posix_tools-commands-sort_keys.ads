with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
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
      Locale              : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Sorts Lines stably in O(n log n), building every line's comparison keys
   --  once. With Options.Unique only the first line of each run of lines
   --  whose keys compare equal is kept.
   procedure Sort_Lines
     (Lines   : in out Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options);

   --  True when Lines is already in the order Sort_Lines would produce, and,
   --  with Options.Unique, when no two adjacent lines have equal keys.
   function Lines_Are_Sorted
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Boolean;
end Posix_Tools.Commands.Sort_Keys;
