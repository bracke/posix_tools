package Posix_Tools.Tail_Rings
  with SPARK_Mode => On
is
   subtype Position is Long_Long_Integer range 1 .. Long_Long_Integer'Last;

   type Advance_Result is record
      Filled : Natural;
      Next   : Position;
   end record;

   function Capacity (First, Last : Position) return Natural
     with
       Pre  => First <= Last
         and then Last - First < Long_Long_Integer (Natural'Last),
       Post => Capacity'Result >= 1;

   function Advance
     (First   : Position;
      Last    : Position;
      Current : Position;
      Filled  : Natural) return Advance_Result
     with
       Pre  => First <= Last
         and then Last - First < Long_Long_Integer (Natural'Last)
         and then Current in First .. Last
         and then Filled <= Capacity (First, Last),
       Post => Advance'Result.Next in First .. Last
         and then Advance'Result.Filled <= Capacity (First, Last)
         and then Advance'Result.Filled >= Filled;
end Posix_Tools.Tail_Rings;
