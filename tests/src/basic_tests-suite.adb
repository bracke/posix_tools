with AUnit.Test_Caller;
with Basic_Tests.Silent_Handler_Parser;
with Basic_Tests.Tooling_Regressions;
with Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob;
with Basic_Tests.Text_Algorithms.Fields_And_File_Modes;
with Basic_Tests.Text_Algorithms.Images_And_Formats;
with Basic_Tests.Text_Algorithms.Parsing_And_Conversion;
with Basic_Tests.Text_Algorithms.Stream_UTF_8_Counting;
with Command_Tests.Dispatch;
with File_Operations_Tests;
with Operation_Tests;

package body Basic_Tests.Suite is
   package Caller is new AUnit.Test_Caller (Basic_Tests.Fixture);
   package Command_Caller is new AUnit.Test_Caller (Command_Tests.Fixture);
   package File_Operations_Caller is new AUnit.Test_Caller (File_Operations_Tests.Fixture);
   package Operation_Caller is new AUnit.Test_Caller (Operation_Tests.Fixture);

   function Test_Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test
        (Result,
         Command_Caller.Create
           ("basic:command inventory", Command_Tests.Dispatch.Test_Command_Inventory'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:numbers", Test_Numbers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:account IDs", Test_Account_Ids'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:silent handler parser",
            Basic_Tests.Silent_Handler_Parser.Test_Parser'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:catalog defaults parser",
            Basic_Tests.Tooling_Regressions.Test_Catalog_Default_Parser'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:warning policy parser",
            Basic_Tests.Tooling_Regressions.Test_Warning_Policy_Parser'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:source rules parser",
            Basic_Tests.Tooling_Regressions.Test_Source_Rules_Parser'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:continuous integration paths",
            Basic_Tests.Tooling_Regressions.Test_Continuous_Integration_Paths'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:Ada lexical view",
            Basic_Tests.Tooling_Regressions.Test_Ada_Lexing'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:test work directory lifecycle",
            Basic_Tests.Tooling_Regressions.Test_Work_Directory_Lifecycle'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:regression registry parser",
            Basic_Tests.Tooling_Regressions.Test_Regression_Registry_Parser'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:sed catalog defaults",
            Basic_Tests.Tooling_Regressions.Test_Sed_Catalog_Defaults'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:awk catalog defaults",
            Basic_Tests.Tooling_Regressions.Test_Awk_Catalog_Defaults'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("basic:option parsing", Basic_Tests.Test_Option_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:option parsing", Test_Option_Parsing_Properties'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:count windows", Test_Count_Windows'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:exit status", Test_Exit_Status'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:paths", Basic_Tests.Test_Paths'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:paths", Test_Path_Properties'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:tail ring arithmetic", Test_Tail_Ring_Arithmetic'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:wc field arithmetic", Test_Wc_Field_Arithmetic'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:byte counting", Test_Stream_Counting'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("streams:utf-8 counting",
            Basic_Tests.Text_Algorithms.Stream_UTF_8_Counting.Run'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:parsing and conversion",
            Basic_Tests.Text_Algorithms.Parsing_And_Conversion.Run'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:field parsing",
            Basic_Tests.Text_Algorithms.Parsing_And_Conversion.Run_Field_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:validation and sorting",
            Basic_Tests.Text_Algorithms.Parsing_And_Conversion.Run_Validation_And_Sorting'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:fields and file modes",
            Basic_Tests.Text_Algorithms.Fields_And_File_Modes.Run'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:images and formats",
            Basic_Tests.Text_Algorithms.Images_And_Formats.Run'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:od and numeric formats",
            Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob.Run_OD_And_Numeric_Formats'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:time and touch fields",
            Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob.Run_Time_And_Touch'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("text:escaping time and glob",
            Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob.Run'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:lf segment splitting", Test_Stream_Line_Split'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:lf segment reassembly", Test_Stream_Line_Properties'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("streams:file fixture", Test_Stream_File_Fixture'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("streams:file callback cleanup",
            Test_File_Chunk_Callback_Cleanup'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("basic:version", Basic_Tests.Test_Version'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:natural order", File_Operations_Tests.Test_Natural_Order'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:permission image", File_Operations_Tests.Test_Permission_Image'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:directory listing", File_Operations_Tests.Test_Directory_Listing'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:listing sort", File_Operations_Tests.Test_Listing_Sort'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:temporary storage long path",
            File_Operations_Tests.Test_Temporary_Storage_Long_Path'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Operations_Caller.Create
           ("basic:temporary storage outcomes",
            File_Operations_Tests.Test_Temporary_Storage_Outcomes'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Operation_Caller.Create ("basic:copy tree", Operation_Tests.Test_Copy_Tree'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Operation_Caller.Create ("basic:copy conflicts", Operation_Tests.Test_Copy_Conflicts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Operation_Caller.Create ("basic:copy cancel", Operation_Tests.Test_Copy_Cancel'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Operation_Caller.Create
           ("basic:copy progress exception",
            Operation_Tests.Test_Copy_Progress_Exception'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Operation_Caller.Create ("basic:remove tree", Operation_Tests.Test_Remove_Tree'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Operation_Caller.Create ("basic:move", Operation_Tests.Test_Move'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Operation_Caller.Create
           ("basic:mv into a directory",
            Operation_Tests.Test_Mv_Into_Directory'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Operation_Caller.Create ("basic:copy kept and stopped", Operation_Tests.Test_Copy_Kept_And_Stopped'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Operation_Caller.Create
           ("basic:rm keeps link targets",
            Operation_Tests.Test_Rm_Keeps_Link_Targets'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Operation_Caller.Create
           ("basic:cp keeps broken links",
            Operation_Tests.Test_Cp_Keeps_Broken_Links'Access));
      return Result;
   end Test_Suite;
end Basic_Tests.Suite;
