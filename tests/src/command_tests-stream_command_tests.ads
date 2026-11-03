package Command_Tests.Stream_Command_Tests is
   procedure Test_Cut_Characters (T : in out Fixture);
   procedure Test_Du (T : in out Fixture);
   procedure Test_Expand (T : in out Fixture);
   procedure Test_File (T : in out Fixture);
   procedure Test_Fold (T : in out Fixture);
   procedure Test_Nl (T : in out Fixture);
   procedure Test_Seq (T : in out Fixture);
   procedure Test_Seq_Empty_Range (T : in out Fixture);
   procedure Test_Sort_Large_Input (T : in out Fixture);
   procedure Test_Sort_Ordering_Rules (T : in out Fixture);
   procedure Test_Tee_Opens_Each_File_Once (T : in out Fixture);
   procedure Test_Tr_Streams_Characters (T : in out Fixture);
   procedure Test_Unexpand (T : in out Fixture);
   procedure Test_Uniq_Filters (T : in out Fixture);
   procedure Test_Unlink (T : in out Fixture);
end Command_Tests.Stream_Command_Tests;
