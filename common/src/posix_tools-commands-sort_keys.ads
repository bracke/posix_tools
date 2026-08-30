with Ada.Containers.Vectors;
with Posix_Tools.Streams.Lines;

package Posix_Tools.Commands.Sort_Keys is
   type Sort_Key_Definition is record
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Fold_Case : Boolean := False;
      Numeric_Sort : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order : Boolean := False;
      Ignore_Nonprinting : Boolean := False;
      Reverse_Order : Boolean := False;
   end record;

   package Sort_Key_Vectors is new Ada.Containers.Vectors (Positive, Sort_Key_Definition);

   function Sort_Keys_Equal
     (Left, Right : String;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Ignore_Leading_Blanks,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "") return Boolean;

   procedure Sort_Lines
     (Lines : in out Posix_Tools.Streams.Lines.Segment_Vector;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "");

   function Lines_Are_Sorted
     (Lines : Posix_Tools.Streams.Lines.Segment_Vector;
      Keys : Sort_Key_Vectors.Vector;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Reverse_Order,
      Unique,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "") return Boolean;
end Posix_Tools.Commands.Sort_Keys;
