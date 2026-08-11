package body Posix_Tools.Tail_Rings
  with SPARK_Mode => On
is
   function Capacity (First, Last : Position) return Natural is
   begin
      return Natural (Last - First + 1);
   end Capacity;

   function Advance
     (First   : Position;
      Last    : Position;
      Current : Position;
      Filled  : Natural) return Advance_Result
   is
      New_Filled : Natural := Filled;
      New_Next   : Position;
   begin
      if New_Filled < Capacity (First, Last) then
         New_Filled := New_Filled + 1;
      end if;

      if Current = Last then
         New_Next := First;
      else
         New_Next := Current + 1;
      end if;

      return (Filled => New_Filled, Next => New_Next);
   end Advance;
end Posix_Tools.Tail_Rings;
