package Command_Tests.Wc_Tests is
   procedure Test_Wc_Text_Counts (T : in out Fixture);
   procedure Test_Wc_Default_And_Mixed_Text (T : in out Fixture);
   procedure Test_Wc_Text_Invalid_UTF_8 (T : in out Fixture);
   procedure Test_Wc_Text_Malformed_UTF_8 (T : in out Fixture);
   procedure Test_Wc_Text_Code_Point_Validity (T : in out Fixture);
   procedure Test_Wc_Multiple_Files (T : in out Fixture);
   procedure Test_Wc_Standard_Input (T : in out Fixture);
   procedure Test_Wc_Byte_Count_Property (T : in out Fixture);
   procedure Test_Wc_Standard_Input_Byte_Property (T : in out Fixture);
   procedure Test_Wc_Line_Count_Property (T : in out Fixture);
   procedure Test_Wc_Standard_Input_Line_Property (T : in out Fixture);
   procedure Test_Wc_Output_Failure (T : in out Fixture);
end Command_Tests.Wc_Tests;
