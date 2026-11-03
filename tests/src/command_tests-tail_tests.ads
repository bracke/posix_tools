package Command_Tests.Tail_Tests is
   procedure Test_Tail_Byte_Mode_Edges (T : in out Fixture);
   procedure Test_Tail_Compact_Counts (T : in out Fixture);
   procedure Test_Tail_Follow_Live (T : in out Fixture);
   procedure Test_Tail_Invalid_Count (T : in out Fixture);
   procedure Test_Tail_Missing_Count (T : in out Fixture);
   procedure Test_Tail_Line_Mode_Edges (T : in out Fixture);
   procedure Test_Tail_Multiple_File_Headers (T : in out Fixture);
   procedure Test_Tail_Plus_Origin (T : in out Fixture);
   procedure Test_Tail_Standard_Input (T : in out Fixture);
   procedure Test_Tail_Output_Failure (T : in out Fixture);
   procedure Test_Tail_Byte_Suffix_Property (T : in out Fixture);
   procedure Test_Tail_Standard_Input_Byte_Property (T : in out Fixture);
   procedure Test_Tail_Line_Suffix_Property (T : in out Fixture);
end Command_Tests.Tail_Tests;
