with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with I18N.Collation;

package body Posix_Tools.Commands.Text_Helpers.Collation.Locale_Rules is
   use Ada.Strings.Unbounded;

   procedure Append_UTF_8 (Output : in out Unbounded_String; Code_Point : Long_Long_Integer) is
   begin
      if Code_Point <= 16#7F# then
         Append (Output, Character'Val (Natural (Code_Point)));
      elsif Code_Point <= 16#7FF# then
         Append (Output, Character'Val (16#C0# + Natural (Code_Point / 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      elsif Code_Point <= 16#FFFF# then
         Append (Output, Character'Val (16#E0# + Natural (Code_Point / 4_096)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      else
         Append (Output, Character'Val (16#F0# + Natural (Code_Point / 262_144)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 4_096) mod 64)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      end if;
   end Append_UTF_8;

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

   function Locale_Equivalence_Class (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;

      function Equivalent (Candidate : String) return Boolean is
      begin
         return I18N.Collation.Available
           and then I18N.Collation.Compare
             (Candidate, Element, Locale, I18N.Collation.Primary) = 0;
      exception
         when Constraint_Error =>
            return False;
      end Equivalent;

      procedure Append_If_Equivalent (Candidate : String) is
      begin
         if Equivalent (Candidate)
           and then Ada.Strings.Fixed.Index (To_String (Output), Candidate) = 0
         then
            Append (Output, Candidate);
         end if;
      end Append_If_Equivalent;
   begin
      Append (Output, Element);
      for Code in Character'Pos ('A') .. Character'Pos ('Z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in Character'Pos ('a') .. Character'Pos ('z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in 16#00C0# .. 16#017F# loop
         declare
            Candidate : Unbounded_String;
         begin
            Append_UTF_8 (Candidate, Long_Long_Integer (Code));
            Append_If_Equivalent (To_String (Candidate));
         end;
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
           and then Family /= ""
           and then Family /= "C"
           and then Family /= "POSIX"
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
end Posix_Tools.Commands.Text_Helpers.Collation.Locale_Rules;
