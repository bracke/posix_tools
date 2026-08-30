package body Posix_Tools.Text.Suffixes
  with SPARK_Mode => On
is
   function Lowercase_Character (Value : Natural) return Character
     with
       Pre  => Value <= 25,
       Post => Lowercase_Character'Result in 'a' .. 'z'
   is
   begin
      return Character'Val (Character'Pos ('a') + Value);
   end Lowercase_Character;

   function Lowercase_Capacity (Length : Positive) return Natural
   is
      Result    : Natural := 1;
      Processed : Natural := 0;
   begin
      while Processed < Length loop
         pragma Loop_Invariant (Processed <= Length);
         pragma Loop_Invariant (Result >= 1);
         pragma Loop_Variant (Increases => Processed);

         if Result > Natural'Last / 26 then
            return Natural'Last;
         end if;

         Result := Result * 26;
         Processed := Processed + 1;
      end loop;

      return Result;
   end Lowercase_Capacity;

   function Lowercase_Image (Index : Natural; Length : Positive) return String is
      Result : String (1 .. Length) := [others => 'a'];
      Work   : Natural := Index;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in 'a' .. 'z');

         Result (I) := Lowercase_Character (Work mod 26);
         Work := Work / 26;
      end loop;

      return Result;
   end Lowercase_Image;
end Posix_Tools.Text.Suffixes;
