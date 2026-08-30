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
      First : Natural := Text'First;
      Last  : Natural := Text'Last;

      function Apply_Start_Character (Index : Natural) return Natural is
      begin
         if Character_Start = 1 then
            return Index;
         elsif Index > Text'Last then
            return Text'Last + 1;
         else
            return Natural'Min (Text'Last + 1, Index + Character_Start - 1);
         end if;
      end Apply_Start_Character;

      function Field_Start_Index return Natural is
         Field : Positive := 1;
         I     : Natural := Text'First;
      begin
         if Field_Start = 1 then
            if Has_Field_Separator then
               return Apply_Start_Character (Text'First);
            end if;
         elsif Has_Field_Separator then
            while I <= Text'Last loop
               if Text (I) = Field_Separator then
                  Field := Field + 1;
                  if Field = Field_Start then
                     return Apply_Start_Character (I + 1);
                  end if;
               end if;
               I := I + 1;
            end loop;
            return Text'Last + 1;
         end if;

         while I <= Text'Last
           and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
         loop
            I := I + 1;
         end loop;

         while Field < Field_Start and then I <= Text'Last loop
            while I <= Text'Last
              and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
            loop
               I := I + 1;
            end loop;
            while I <= Text'Last
              and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
            loop
               I := I + 1;
            end loop;
            Field := Field + 1;
         end loop;
         return Apply_Start_Character (I);
      end Field_Start_Index;

      function Field_End_Index return Natural is
         Field : Positive := 1;
         I     : Natural := Text'First;
         Base  : Natural := Text'First;
      begin
         if Field_End = 0 then
            return Text'Last;
         elsif Has_Field_Separator then
            while I <= Text'Last loop
               if Field = Field_End and then Text (I) = Field_Separator then
                  return
                    (if Character_End = 0
                     then I - 1
                     else Natural'Min (I - 1, Base + Character_End - 1));
               elsif Text (I) = Field_Separator then
                  Field := Field + 1;
                  Base := I + 1;
               end if;
               I := I + 1;
            end loop;
            return
              (if Character_End = 0
               then Text'Last
               else Natural'Min (Text'Last, Base + Character_End - 1));
         end if;

         while I <= Text'Last
           and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
         loop
            I := I + 1;
         end loop;

         while Field < Positive'Max (1, Field_End) and then I <= Text'Last loop
            while I <= Text'Last
              and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
            loop
               I := I + 1;
            end loop;
            while I <= Text'Last
              and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
            loop
               I := I + 1;
            end loop;
            Field := Field + 1;
         end loop;

         Base := I;
         while I <= Text'Last
           and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (I))
         loop
            I := I + 1;
         end loop;
         return
           (if Character_End = 0
            then I - 1
            else Natural'Min (I - 1, Base + Character_End - 1));
      end Field_End_Index;
   begin
      First := Field_Start_Index;
      Last := Field_End_Index;
      if Ignore_Leading_Blanks then
         while First <= Last
           and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (First))
         loop
            First := First + 1;
         end loop;
      end if;

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
