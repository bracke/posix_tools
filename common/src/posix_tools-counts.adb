package body Posix_Tools.Counts
  with SPARK_Mode => On
is
   function Should_Emit_From_Start
     (Position  : Posix_Tools.Numbers.Count;
      Requested : Posix_Tools.Numbers.Count) return Boolean
   is
   begin
      return Requested = 0 or else Position >= Requested;
   end Should_Emit_From_Start;

   function Suffix_Start
     (Total     : Posix_Tools.Numbers.Count;
      Requested : Posix_Tools.Numbers.Count) return Posix_Tools.Numbers.Count
   is
   begin
      if Requested = 0 then
         return Total + 1;
      elsif Requested >= Total then
         return 1;
      else
         return Total - Requested + 1;
      end if;
   end Suffix_Start;
end Posix_Tools.Counts;
