with Posix_Tools.Numbers;

package Posix_Tools.Counts
  with SPARK_Mode => On
is
   use type Posix_Tools.Numbers.Count;

   function Rounded_Units
     (Bytes     : Long_Long_Integer;
      Unit_Size : Long_Long_Integer) return Long_Long_Integer
     with
       Pre  => Unit_Size > 0,
       Post =>
         (if Bytes <= 0 then
            Rounded_Units'Result = 0
          else
            Rounded_Units'Result = ((Bytes - 1) / Unit_Size) + 1
            and then Rounded_Units'Result > 0);

   function Should_Emit_From_Start
     (Position  : Posix_Tools.Numbers.Count;
      Requested : Posix_Tools.Numbers.Count) return Boolean
     with
       Post =>
         Should_Emit_From_Start'Result =
           (Requested = 0 or else Position >= Requested);

   function Suffix_Start
     (Total     : Posix_Tools.Numbers.Count;
     Requested : Posix_Tools.Numbers.Count) return Posix_Tools.Numbers.Count
     with
       Pre  => Total < Posix_Tools.Numbers.Count'Last,
       Post =>
         Suffix_Start'Result in 1 .. Total + 1
         and then
           (Suffix_Start'Result = Total + 1) =
             (Requested = 0 or else Total = 0)
         and then
           (if Requested = 0 then
              Suffix_Start'Result = Total + 1)
         and then
           (if Requested /= 0 and then Total /= 0 then
              Suffix_Start'Result <= Total)
         and then
           (if Requested >= Total and then Requested /= 0 then
              Suffix_Start'Result = 1)
         and then
           (if Requested < Total and then Requested /= 0 then
              Suffix_Start'Result = Total - Requested + 1);
end Posix_Tools.Counts;
