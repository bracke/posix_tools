package body Posix_Tools.Tail_Counts
  with SPARK_Mode => On
is
   function Parse_Count (Text : String) return Parsed_Count is
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      if Text /= "" and then Text (Text'First) = '+' then
         if Text'Length = 1 then
            return
              (Status => Posix_Tools.Numbers.Invalid_Syntax,
               Value  => 0,
               Origin => From_Start);
         end if;

         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (Text'First + 1 .. Text'Last));
         return
           (Status => Parsed.Status,
            Value  => Parsed.Value,
            Origin => From_Start);
      else
         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text);
         return
           (Status => Parsed.Status,
            Value  => Parsed.Value,
            Origin => From_End);
      end if;
   end Parse_Count;
end Posix_Tools.Tail_Counts;
