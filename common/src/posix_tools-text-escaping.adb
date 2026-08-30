package body Posix_Tools.Text.Escaping
  with SPARK_Mode => On
is
   function Needs_Escaping (Ch : Character) return Boolean is
     (Character'Pos (Ch) < 32 or else Character'Pos (Ch) = 127);

   function Escaped_Character_Length (Ch : Character) return Positive is
     (if Needs_Escaping (Ch) then 4 else 1);

   function Hex_Digit (Value : Natural) return Character
     with
       Pre  => Value < 16,
       Post =>
         (if Value < 10 then Hex_Digit'Result in '0' .. '9'
          else Hex_Digit'Result in 'A' .. 'F')
   is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('A') + Value - 10);
      end if;
   end Hex_Digit;

   function Escaped_Length (Text : String) return Long_Long_Integer is
      Processed : Natural := 0;
      Result    : Long_Long_Integer := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Result >= Long_Long_Integer (Processed));
         pragma Loop_Invariant (Result <= Long_Long_Integer (Processed) * 4);
         pragma Loop_Variant (Increases => Processed);

         Result := Result
           + Long_Long_Integer
             (Escaped_Character_Length (Text (Text'First + Processed)));
         Processed := Processed + 1;
      end loop;

      return Result;
   end Escaped_Length;

   function Escape_Untrusted (Text : String) return String is
      Result    : String (1 .. Text'Length * 4) := (others => Character'Val (0));
      Last      : Natural := 0;
      Processed : Natural := 0;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Last <= Result'Length);
         pragma Loop_Invariant (Last >= Processed);
         pragma Loop_Invariant (Last <= Processed * 4);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch   : constant Character := Text (Text'First + Processed);
            Code : constant Natural := Character'Pos (Ch);
         begin
            pragma Assert (Processed + 1 <= Text'Length);
            pragma Assert ((Processed + 1) * 4 <= Text'Length * 4);
            pragma Assert (Last + 4 <= Result'Length);

            if Needs_Escaping (Ch) then
               Result (Last + 1) := '\';
               Result (Last + 2) := 'x';
               Result (Last + 3) := Hex_Digit (Code / 16);
               Result (Last + 4) := Hex_Digit (Code mod 16);
               Last := Last + 4;
            else
               Result (Last + 1) := Ch;
               Last := Last + 1;
            end if;
         end;

         Processed := Processed + 1;
      end loop;

      return Result (1 .. Last);
   end Escape_Untrusted;
end Posix_Tools.Text.Escaping;
