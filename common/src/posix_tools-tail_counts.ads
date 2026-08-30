with Posix_Tools.Numbers;

package Posix_Tools.Tail_Counts
  with SPARK_Mode => On
is
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;

   type Count_Origin is (From_End, From_Start);

   type Parsed_Count is record
      Status : Posix_Tools.Numbers.Parse_Status := Posix_Tools.Numbers.Empty;
      Value  : Posix_Tools.Numbers.Count := 0;
      Origin : Count_Origin := From_End;
   end record;

   function Parse_Count (Text : String) return Parsed_Count
     with
       Post =>
         (if Parse_Count'Result.Status /= Posix_Tools.Numbers.Valid then
            Parse_Count'Result.Value = 0)
         and then
           (if Text /= "" and then Text (Text'First) = '+' then
              Parse_Count'Result.Origin = From_Start
            else
              Parse_Count'Result.Origin = From_End)
         and then
           (if Text = "+" then
              Parse_Count'Result.Status = Posix_Tools.Numbers.Invalid_Syntax);
end Posix_Tools.Tail_Counts;
