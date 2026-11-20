package body Posix_Tools.Rg_Arithmetic
  with SPARK_Mode => On
is
   function Saturating_Add (Left, Right : Natural) return Natural is
     (if Left > Natural'Last - Right then Natural'Last else Left + Right);
end Posix_Tools.Rg_Arithmetic;
