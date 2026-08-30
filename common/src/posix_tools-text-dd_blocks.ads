with Posix_Tools.Numbers;

package Posix_Tools.Text.DD_Blocks is
   type Record_Counts is record
      Full    : Posix_Tools.Numbers.Count := 0;
      Partial : Posix_Tools.Numbers.Count := 0;
   end record;

   type Transfer_Plan_Status is
     (Valid_Transfer,
      Offset_Overflow,
      Count_Overflow);

   type Transfer_Plan is record
      Status       : Transfer_Plan_Status := Valid_Transfer;
      Start_Index  : Natural := 1;
      Last_Index   : Natural := 0;
      Prefix_Count : Posix_Tools.Numbers.Count := 0;
   end record;

   function Counts_For
     (Byte_Count : Posix_Tools.Numbers.Count;
      Block_Size : Posix_Tools.Numbers.Count) return Record_Counts;

   function Offset_Overflows
     (Block_Count : Posix_Tools.Numbers.Count;
      Block_Size  : Posix_Tools.Numbers.Count) return Boolean;

   function Selected_Input
     (Value       : String;
      Block_Size  : Posix_Tools.Numbers.Count;
      Block_Count : Posix_Tools.Numbers.Count) return String;

   function Transfer_Slice
     (Input_Length      : Natural;
      Count             : Posix_Tools.Numbers.Count;
      Input_Block_Size  : Posix_Tools.Numbers.Count;
      Output_Block_Size : Posix_Tools.Numbers.Count;
      Skip_Blocks       : Posix_Tools.Numbers.Count;
      Seek_Blocks       : Posix_Tools.Numbers.Count) return Transfer_Plan;
end Posix_Tools.Text.DD_Blocks;
