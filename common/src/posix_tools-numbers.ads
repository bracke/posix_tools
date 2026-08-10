package Posix_Tools.Numbers is
   type Count is range 0 .. 2 ** 63 - 1;
   type Parse_Status is (Valid, Empty, Invalid_Syntax, Negative_Not_Permitted, Overflow);

   type Parse_Result is record
      Status : Parse_Status := Empty;
      Value  : Count := 0;
   end record;

   function Parse_Nonnegative (Text : String) return Parse_Result;
end Posix_Tools.Numbers;
