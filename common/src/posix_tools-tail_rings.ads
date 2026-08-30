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
       Post =>
         Capacity'Result >= 1
         and then Capacity'Result = Natural (Last - First + 1);

   function Is_Full
     (First  : Position;
      Last   : Position;
      Filled : Natural) return Boolean is
     (Filled = Capacity (First, Last))
     with
       Pre  => First <= Last
         and then Last - First < Long_Long_Integer (Natural'Last)
         and then Filled <= Capacity (First, Last),
       Post =>
         Is_Full'Result = (Filled = Capacity (First, Last));

   function Will_Wrap (Current, Last : Position) return Boolean is
     (Current = Last)
     with
       Pre  => Current <= Last,
       Post => Will_Wrap'Result = (Current = Last);

   function Next_Position
     (First   : Position;
      Last    : Position;
      Current : Position) return Position is
     (if Will_Wrap (Current, Last) then First else Current + 1)
     with
       Pre  => First <= Last
         and then Current in First .. Last,
       Post => Next_Position'Result in First .. Last
         and then
           (if Will_Wrap (Current, Last) then
              Next_Position'Result = First
            else
              Next_Position'Result = Current + 1);

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
         and then Advance'Result.Filled >= Filled
         and then
           Advance'Result.Next = Next_Position (First, Last, Current)
         and then
           Advance'Result.Filled =
             (if Is_Full (First, Last, Filled) then Filled else Filled + 1)
         and then
           Is_Full (First, Last, Advance'Result.Filled) =
             (Is_Full (First, Last, Filled)
              or else Filled + 1 = Capacity (First, Last));
end Posix_Tools.Tail_Rings;
