package body Posix_Tools.Numbers is
   function Parse_Nonnegative (Text : String) return Parse_Result is
      Value : Count := 0;
   begin
      if Text = "" then
         return (Status => Empty, Value => 0);
      elsif Text (Text'First) = '-' then
         return (Status => Negative_Not_Permitted, Value => 0);
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return (Status => Invalid_Syntax, Value => 0);
         end if;

         if Value > (Count'Last - Count (Character'Pos (Ch) - Character'Pos ('0'))) / 10 then
            return (Status => Overflow, Value => 0);
         end if;

         Value := Value * 10 + Count (Character'Pos (Ch) - Character'Pos ('0'));
      end loop;

      return (Status => Valid, Value => Value);
   end Parse_Nonnegative;
end Posix_Tools.Numbers;
