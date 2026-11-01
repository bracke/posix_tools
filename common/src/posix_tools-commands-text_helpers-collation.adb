with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with I18N.Collation;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Text_Helpers.Collation is
   use Ada.Strings.Unbounded;

   function Compare (Locale, Left, Right : String) return Integer is
   begin
      if Is_Byte_Collation_Locale (Locale) then
         return (if Left < Right then -1 elsif Left > Right then 1 else 0);
      elsif I18N.Collation.Available then
         return I18N.Collation.Compare (Left, Right, Locale, I18N.Collation.Tertiary);
      end if;

      declare
         Left_Key  : constant String := Locale_Sort_Text (Locale, Left);
         Right_Key : constant String := Locale_Sort_Text (Locale, Right);
      begin
         return (if Left_Key < Right_Key then -1 elsif Left_Key > Right_Key then 1 else 0);
      end;
   end Compare;

   function Is_Byte_Collation_Locale (Locale : String) return Boolean is
      Family : constant String := Ada.Characters.Handling.To_Lower (Locale_Family (Locale));
   begin
      return Family in "" | "c" | "posix";
   end Is_Byte_Collation_Locale;

   function Is_Multibyte_Locale (Locale : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Locale);
   begin
      return not Is_Byte_Collation_Locale (Locale)
        or else Ada.Strings.Fixed.Index (Lower, ".utf-8") > 0
        or else Ada.Strings.Fixed.Index (Lower, ".utf8") > 0;
   end Is_Multibyte_Locale;

   function Locale_Collating_Symbol (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
   begin
      if Family = "es" and then Element = "ch" then
         return "ch";
      elsif Family = "es" and then Element = "ll" then
         return "ll";
      elsif Family = "da" and then Element = "aa" then
         return "aa";
      else
         return Element;
      end if;
   end Locale_Collating_Symbol;

   function Locale_Collation_Order (Locale, Set1 : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      Ordered : String (1 .. 256);
      Last    : Natural := 0;
      Spanish_After_Enye : constant String := "opqrstuvwxyzABCDEFGHIJKLMN";

      procedure Append_If_Available (Ch : Character);

      function Key (Ch : Character) return String;

      procedure Append_If_Available (Ch : Character) is
      begin
         if (for all Item of Set1 => Item /= Ch)
           and then (for all I in 1 .. Last => Ordered (I) /= Ch)
         then
            Last := Last + 1;
            Ordered (Last) := Ch;
         end if;
      end Append_If_Available;

      function Key (Ch : Character) return String is
      begin
         if I18N.Collation.Available
           and then not Is_Byte_Collation_Locale (Locale)
           and then Family /= "en"
         then
            return I18N.Collation.Sort_Key ([1 => Ch], Locale, I18N.Collation.Primary);
         else
            return [1 => Ch];
         end if;
      exception
         when Constraint_Error =>
            return [1 => Ch];
      end Key;
   begin
      if Family = "da" then
         for Ch in Character range 'a' .. 'z' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#A6#));
         Append_If_Available (Character'Val (16#B8#));
         Append_If_Available (Character'Val (16#A5#));
         for Ch in Character range 'A' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      elsif Family = "es" then
         for Ch in Character range 'a' .. 'n' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#B1#));
         for Ch of Spanish_After_Enye loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#91#));
         for Ch in Character range 'O' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      end if;

      for Code in 0 .. 255 loop
         Append_If_Available (Character'Val (Code));
      end loop;

      if Family /= "da" and then Family /= "es" then
         for I in 2 .. Last loop
            declare
               Item : constant Character := Ordered (I);
               J    : Natural := I;
            begin
               while J > 1
                 and then (Key (Item) < Key (Ordered (J - 1))
                           or else (Key (Item) = Key (Ordered (J - 1)) and then Item < Ordered (J - 1)))
               loop
                  Ordered (J) := Ordered (J - 1);
                  J := J - 1;
               end loop;
               Ordered (J) := Item;
            end;
         end loop;
      end if;

      for I in 1 .. Last loop
         Append (Output, Ordered (I));
      end loop;

      return To_String (Output);
   end Locale_Collation_Order;

   function Locale_Equivalence_Class (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;

      procedure Append_If_Equivalent (Candidate : String);

      function Equivalent (Candidate : String) return Boolean;

      procedure Append_If_Equivalent (Candidate : String) is
      begin
         if Equivalent (Candidate)
           and then Ada.Strings.Fixed.Index (To_String (Output), Candidate) = 0
         then
            Append (Output, Candidate);
         end if;
      end Append_If_Equivalent;

      function Equivalent (Candidate : String) return Boolean is
      begin
         return I18N.Collation.Available
           and then I18N.Collation.Compare
             (Candidate, Element, Locale, I18N.Collation.Primary) = 0;
      exception
         when Constraint_Error =>
            return False;
      end Equivalent;
   begin
      Append (Output, Element);
      for Code in Character'Pos ('A') .. Character'Pos ('Z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in Character'Pos ('a') .. Character'Pos ('z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in 16#00C0# .. 16#017F# loop
         Append_If_Equivalent (Posix_Tools.Text.UTF_8.Encode (Long_Long_Integer (Code)));
      end loop;

      if Element = "a" then
         if Family = "da" then
            Append_If_Equivalent ("a");
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A1#));
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A0#));
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#)
                    & Character'Val (16#C3#) & Character'Val (16#A0#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#));
         end if;
      elsif Element = "e" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A9#));
         end if;
      elsif Element = "o" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B8#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B3#));
         end if;
      elsif Element = "A" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#81#));
         end if;
      elsif Element = "E" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#89#));
         end if;
      elsif Element = "O" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#98#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#93#));
         end if;
      end if;

      if Length (Output) > Element'Length then
         return To_String (Output);
      end if;

      return Element;
   end Locale_Equivalence_Class;

   function Locale_Family (Locale : String) return String is
      Dot : Natural := 0;
   begin
      for I in Locale'Range loop
         if Locale (I) = '.' or else Locale (I) = '_' or else Locale (I) = '-' then
            Dot := I - 1;
            exit;
         end if;
      end loop;

      if Dot = 0 then
         return Locale;
      elsif Dot < Locale'First then
         return "";
      else
         return Locale (Locale'First .. Dot);
      end if;
   end Locale_Family;

   function Locale_Sort_Text (Locale, Text : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      I      : Positive := Text'First;

      procedure Append_Byte_Order (Ch : Character);

      procedure Append_Collation (Primary, Secondary : Character);

      function Has_Bytes (Pattern : String) return Boolean;

      procedure Append_Byte_Order (Ch : Character) is
      begin
         Append (Output, Ch);
         Append (Output, Character'Val (0));
      end Append_Byte_Order;

      procedure Append_Collation (Primary, Secondary : Character) is
      begin
         Append (Output, Primary);
         Append (Output, Secondary);
      end Append_Collation;

      function Has_Bytes (Pattern : String) return Boolean is
      begin
         return I + Pattern'Length - 1 <= Text'Last
           and then Text (I .. I + Pattern'Length - 1) = Pattern;
      end Has_Bytes;
   begin
      if not Is_Byte_Collation_Locale (Locale)
        and then Family /= "da"
        and then Family /= "es"
        and then I18N.Collation.Available
      then
         declare
            CLDR_Key : constant String := I18N.Collation.Sort_Key (Text, Locale, I18N.Collation.Tertiary);
         begin
            if CLDR_Key /= Text then
               return CLDR_Key;
            end if;
         end;
      end if;

      if Family /= "da" and then Family /= "es" then
         return Text;
      end if;

      while I <= Text'Last loop
         if Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (166)) then
            Append_Collation ('{', 'a');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (134)) then
            Append_Collation ('{', 'A');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (184)) then
            Append_Collation ('{', 'b');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (152)) then
            Append_Collation ('{', 'B');
            I := I + 2;
         elsif Family = "da"
           and then (Has_Bytes (Character'Val (195) & Character'Val (165))
                     or else Has_Bytes (Character'Val (226) & Character'Val (132) & Character'Val (171)))
         then
            Append_Collation ('{', 'c');
            I := I + (if Character'Pos (Text (I)) = 195 then 2 else 3);
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (133)) then
            Append_Collation ('{', 'C');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ch") then
            Append_Collation ('c', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ch") then
            Append_Collation ('C', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ll") then
            Append_Collation ('l', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ll") then
            Append_Collation ('L', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (177)) then
            Append_Collation ('n', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (145)) then
            Append_Collation ('N', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (161)) then
            Append_Collation ('a', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (169)) then
            Append_Collation ('e', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (173)) then
            Append_Collation ('i', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (179)) then
            Append_Collation ('o', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (186)) then
            Append_Collation ('u', 'a');
            I := I + 2;
         else
            Append_Byte_Order (Text (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Locale_Sort_Text;
end Posix_Tools.Commands.Text_Helpers.Collation;
