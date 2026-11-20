--  Proved bounded arithmetic shared by rg's sequential and parallel accounting.
package Posix_Tools.Rg_Arithmetic
  with Pure,
       SPARK_Mode => On
is
   function Saturating_Add (Left, Right : Natural) return Natural
     with Post =>
       Saturating_Add'Result =
         (if Left > Natural'Last - Right then Natural'Last else Left + Right);
end Posix_Tools.Rg_Arithmetic;
