with Ada.Strings.Unbounded;

package body Posix_Tools.Text.DD_Blocks is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Numbers.Count;

   function Counts_For
     (Byte_Count : Posix_Tools.Numbers.Count;
      Block_Size : Posix_Tools.Numbers.Count) return Record_Counts
   is
   begin
      if Block_Size = 0 then
         return (Full => 0, Partial => 0);
      else
         return
           (Full    => Byte_Count / Block_Size,
            Partial => (if Byte_Count mod Block_Size = 0 then 0 else 1));
      end if;
   end Counts_For;

   function Offset_Overflows
     (Block_Count : Posix_Tools.Numbers.Count;
      Block_Size  : Posix_Tools.Numbers.Count) return Boolean
   is
   begin
      return Block_Size /= 0
        and then Block_Count > Posix_Tools.Numbers.Count'Last / Block_Size;
   end Offset_Overflows;

   function Selected_Input
     (Value       : String;
      Block_Size  : Posix_Tools.Numbers.Count;
      Block_Count : Posix_Tools.Numbers.Count) return String
   is
      Selected : Unbounded_String;
      Start    : Natural := Value'First;
      Stop     : Natural;
      Blocks   : Posix_Tools.Numbers.Count := 0;
   begin
      if Block_Size = 0
        or else Block_Size > Posix_Tools.Numbers.Count (Natural'Last)
        or else Block_Count = 0
        or else Value = ""
      then
         return "";
      end if;

      while Start <= Value'Last
        and then Blocks < Block_Count
      loop
         Stop :=
           Natural'Min
             (Start + Natural (Block_Size) - 1,
              Value'Last);
         Append (Selected, Value (Start .. Stop));
         Blocks := Blocks + 1;
         Start := Stop + 1;
      end loop;

      return To_String (Selected);
   end Selected_Input;

   function Transfer_Slice
     (Input_Length      : Natural;
      Count             : Posix_Tools.Numbers.Count;
      Input_Block_Size  : Posix_Tools.Numbers.Count;
      Output_Block_Size : Posix_Tools.Numbers.Count;
      Skip_Blocks       : Posix_Tools.Numbers.Count;
      Seek_Blocks       : Posix_Tools.Numbers.Count) return Transfer_Plan
   is
      Limit        : Posix_Tools.Numbers.Count;
      Prefix_Count : Posix_Tools.Numbers.Count;
      Start        : Natural;
      Last         : Natural;
   begin
      if Offset_Overflows (Skip_Blocks, Input_Block_Size)
        or else Offset_Overflows (Seek_Blocks, Output_Block_Size)
      then
         return (Status => Offset_Overflow, others => <>);
      end if;

      declare
         Skip_Bytes : constant Posix_Tools.Numbers.Count :=
           Skip_Blocks * Input_Block_Size;
      begin
         if Skip_Bytes >= Posix_Tools.Numbers.Count (Input_Length) then
            Start := 1;
            Last := 0;
         else
            Start := 1 + Natural (Skip_Bytes);
            Last := Start;
         end if;
      end;

      if Count = Posix_Tools.Numbers.Count'Last then
         Limit :=
           (if Last < Start
            then 0
            else Posix_Tools.Numbers.Count (Input_Length - Start + 1));
      elsif Count > Posix_Tools.Numbers.Count'Last / Input_Block_Size then
         return (Status => Count_Overflow, others => <>);
      else
         Limit := Count * Input_Block_Size;
      end if;

      if Last < Start or else Limit = 0 then
         Last := Start - 1;
      elsif Limit > Posix_Tools.Numbers.Count (Input_Length - Start + 1) then
         Last := Input_Length;
      else
         Last := Start + Natural (Limit) - 1;
      end if;

      Prefix_Count := Seek_Blocks * Output_Block_Size;
      if Prefix_Count > Posix_Tools.Numbers.Count (Natural'Last) then
         return (Status => Offset_Overflow, others => <>);
      end if;

      return
        (Status       => Valid_Transfer,
         Start_Index  => Start,
         Last_Index   => Last,
         Prefix_Count => Prefix_Count);
   end Transfer_Slice;
end Posix_Tools.Text.DD_Blocks;
