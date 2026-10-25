with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Commands.Sort_Key_Text is
   use Ada.Strings.Unbounded;

   function Sort_Key
     (Text : String;
      Fold_Case, Ignore_Leading_Blanks, Dictionary_Order, Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "";
      Apply_Locale_Collation : Boolean := True) return String
   is
      --  Without a field separator a field is a run of blanks followed by
      --  the run of non-blanks after it, so its leading blanks belong to it;
      --  they are skipped only when Ignore_Leading_Blanks (-b) asks.
      function Field_Base (Field : Positive) return Natural;
      function Field_Limit (Field : Positive) return Natural;
      function Key_Base (Field : Positive) return Natural;
      function Skip_Blanks (From, Limit : Natural) return Natural;
      function Skip_Nonblanks (From : Natural) return Natural;

      --  The first index of Field, or Text'Last + 1 when the line has fewer
      --  fields.
      function Field_Base (Field : Positive) return Natural is
         I : Natural := Text'First;
      begin
         for Unused in 2 .. Field loop
            if Has_Field_Separator then
               while I <= Text'Last and then Text (I) /= Field_Separator loop
                  I := I + 1;
               end loop;
               if I > Text'Last then
                  return Text'Last + 1;
               end if;
               I := I + 1;
            else
               I := Skip_Nonblanks (Skip_Blanks (I, Text'Last));
            end if;
         end loop;
         return I;
      end Field_Base;

      --  The last index of Field.
      function Field_Limit (Field : Positive) return Natural is
         I : Natural := Field_Base (Field);
      begin
         if Has_Field_Separator then
            while I <= Text'Last and then Text (I) /= Field_Separator loop
               I := I + 1;
            end loop;
            return I - 1;
         else
            return Skip_Nonblanks (Skip_Blanks (I, Text'Last)) - 1;
         end if;
      end Field_Limit;

      --  Where the characters of Field are counted from.
      function Key_Base (Field : Positive) return Natural is
        (if Ignore_Leading_Blanks then Skip_Blanks (Field_Base (Field), Field_Limit (Field))
         else Field_Base (Field));

      function Skip_Blanks (From, Limit : Natural) return Natural is
         I : Natural := From;
      begin
         while I <= Limit and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I)) loop
            I := I + 1;
         end loop;
         return I;
      end Skip_Blanks;

      function Skip_Nonblanks (From : Natural) return Natural is
         I : Natural := From;
      begin
         while I <= Text'Last and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I)) loop
            I := I + 1;
         end loop;
         return I;
      end Skip_Nonblanks;

      First : constant Natural :=
        Natural'Min (Text'Last + 1, Key_Base (Field_Start) + Character_Start - 1);
      Last  : constant Natural :=
        (if Field_End = 0 then Text'Last
         elsif Character_End = 0 then Field_Limit (Field_End)
         else Natural'Min (Field_Limit (Field_End), Key_Base (Field_End) + Character_End - 1));
   begin
      if First > Text'Last or else First > Last then
         return "";
      elsif not Fold_Case and then not Dictionary_Order and then not Ignore_Nonprinting then
         declare
            Raw_Key : constant String := Text (First .. Last);
         begin
            return
              (if Apply_Locale_Collation
               then Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Raw_Key)
               else Raw_Key);
         end;
      elsif Fold_Case and then not Dictionary_Order and then not Ignore_Nonprinting then
         declare
            Raw_Key : constant String :=
              Posix_Tools.Commands.Text_Helpers.Folded_Sort_Text (Text (First .. Last));
         begin
            return
              (if Apply_Locale_Collation
               then Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Raw_Key)
               else Raw_Key);
         end;
      else
         declare
            Key : Unbounded_String;
         begin
            for I in First .. Last loop
               if (not Dictionary_Order
                   or else Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character (Text (I)))
                 and then (not Ignore_Nonprinting
                           or else Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable (Text (I)))
               then
                  Append (Key, Text (I));
               end if;
            end loop;
            declare
               Raw_Key : constant String :=
                 (if Fold_Case
                  then Posix_Tools.Commands.Text_Helpers.Folded_Sort_Text (To_String (Key))
                  else To_String (Key));
            begin
               return
                 (if Apply_Locale_Collation
                  then Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Raw_Key)
                  else Raw_Key);
            end;
         end;
      end if;
   end Sort_Key;
end Posix_Tools.Commands.Sort_Key_Text;
