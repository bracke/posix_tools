with Posix_Tools.Numbers;

package Posix_Tools.Counts
  with SPARK_Mode => On
is
   use type Posix_Tools.Numbers.Count;

   function Should_Emit_From_Start
     (Position  : Posix_Tools.Numbers.Count;
      Requested : Posix_Tools.Numbers.Count) return Boolean;

   function Suffix_Start
     (Total     : Posix_Tools.Numbers.Count;
      Requested : Posix_Tools.Numbers.Count) return Posix_Tools.Numbers.Count
     with
       Pre  => Total < Posix_Tools.Numbers.Count'Last,
       Post => Suffix_Start'Result in 1 .. Total + 1;
end Posix_Tools.Counts;
