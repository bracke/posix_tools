with Ada.Containers;
with Posix_Tools.Commands.Sort_Key_Text;
with Posix_Tools.Commands.Sort_Keys.Comparison;

package body Posix_Tools.Commands.Sort_Keys is
   use Posix_Tools.Commands.Sort_Key_Text;
   use type Ada.Containers.Count_Type;

   function Line_Greater_With_Keys
     (Left, Right : String;
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
      Locale : String := "")
      return Boolean
   is
      Comparison : Integer;
   begin
      if Keys.Length = 0 then
         return Posix_Tools.Commands.Sort_Keys.Comparison.Line_Greater
           (Left,
            Right,
            Fold_Case,
            Numeric_Sort,
            Ignore_Leading_Blanks,
            Stable_Sort,
            Dictionary_Order,
            Ignore_Nonprinting,
            Field_Start,
            Field_End,
            Character_Start,
            Character_End,
            Field_Separator,
            Has_Field_Separator,
            Locale);
      end if;

      for Key of Keys loop
         Comparison :=
           Posix_Tools.Commands.Sort_Keys.Comparison.Sort_Key_Comparison
             (Left,
              Right,
              Key,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Separator,
              Has_Field_Separator,
              Locale);
         if Comparison /= 0 then
            return (if Key.Reverse_Order then Comparison < 0 else Comparison > 0);
         end if;
      end loop;

      return False;
   end Line_Greater_With_Keys;

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
      Locale : String := "") return Boolean
   is
   begin
      if Keys.Length = 0 then
         return
           Sort_Key
             (Left,
              Fold_Case,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale,
              False)
           =
           Sort_Key
             (Right,
              Fold_Case,
              Ignore_Leading_Blanks,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale,
              False);
      end if;

      for Key of Keys loop
         declare
            Effective_Fold_Case : constant Boolean := Fold_Case or else Key.Fold_Case;
            Left_Key : constant String :=
              Sort_Key
                (Left,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Dictionary_Order or else Key.Dictionary_Order,
                 Ignore_Nonprinting or else Key.Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Right_Key : constant String :=
              Sort_Key
                (Right,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Dictionary_Order or else Key.Dictionary_Order,
                 Ignore_Nonprinting or else Key.Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
         begin
            if Left_Key /= Right_Key then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Sort_Keys_Equal;

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
      Locale : String := "")
   is
      Swapped : Boolean;
   begin
      if Lines.Length < 2 then
         return;
      end if;

      loop
         Swapped := False;
         for I in 1 .. Positive (Lines.Length) - 1 loop
            if Line_Greater_With_Keys
              (Lines.Element (I),
               Lines.Element (I + 1),
               Keys,
               Fold_Case,
               Numeric_Sort,
               Ignore_Leading_Blanks,
               Stable_Sort,
               Dictionary_Order,
               Ignore_Nonprinting,
               Field_Start,
               Field_End,
               Character_Start,
               Character_End,
               Field_Separator,
               Has_Field_Separator,
               Locale)
            then
               declare
                  Temp : constant String := Lines.Element (I);
               begin
                  Lines.Replace_Element (I, Lines.Element (I + 1));
                  Lines.Replace_Element (I + 1, Temp);
                  Swapped := True;
               end;
            end if;
         end loop;
         exit when not Swapped;
      end loop;
   end Sort_Lines;

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
      Locale : String := "")
      return Boolean
   is
   begin
      if Lines.Length < 2 then
         return True;
      end if;

      for I in 1 .. Positive (Lines.Length) - 1 loop
         if (not Reverse_Order)
           and then Line_Greater_With_Keys
             (Lines.Element (I),
              Lines.Element (I + 1),
              Keys,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Stable_Sort,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale)
         then
            return False;
         elsif Reverse_Order
           and then Line_Greater_With_Keys
             (Lines.Element (I + 1),
              Lines.Element (I),
              Keys,
              Fold_Case,
              Numeric_Sort,
              Ignore_Leading_Blanks,
              Stable_Sort,
              Dictionary_Order,
              Ignore_Nonprinting,
              Field_Start,
              Field_End,
              Character_Start,
              Character_End,
              Field_Separator,
              Has_Field_Separator,
              Locale)
         then
            return False;
         end if;

         if Unique then
            if Sort_Keys_Equal
                 (Lines.Element (I),
                  Lines.Element (I + 1),
                  Keys,
                  Fold_Case,
                  Ignore_Leading_Blanks,
                  Dictionary_Order,
                  Ignore_Nonprinting,
                  Field_Start,
                  Field_End,
                  Character_Start,
                  Character_End,
                  Field_Separator,
                  Has_Field_Separator,
                  Locale)
            then
               return False;
            end if;
         end if;
      end loop;

      return True;
   end Lines_Are_Sorted;
end Posix_Tools.Commands.Sort_Keys;
