with AUnit.Test_Caller;
with Command_Tests.Tail_Tests;
with Command_Tests.Wc_Tests;

package body Command_Tests.Stream_Suite_Entries is
   package Caller is new AUnit.Test_Caller (Command_Tests.Fixture);
   package Tail renames Command_Tests.Tail_Tests;
   package Wc renames Command_Tests.Wc_Tests;

   procedure Register_Tail_Commands
     (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail byte mode edges", Tail.Test_Tail_Byte_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail compact counts", Tail.Test_Tail_Compact_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail follow live", Tail.Test_Tail_Follow_Live'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:tail invalid count",
            Tail.Test_Tail_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:tail missing count",
            Tail.Test_Tail_Missing_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail line mode edges", Tail.Test_Tail_Line_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:tail multiple file headers",
            Tail.Test_Tail_Multiple_File_Headers'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:tail plus origin", Tail.Test_Tail_Plus_Origin'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail standard input", Tail.Test_Tail_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail output failure", Tail.Test_Tail_Output_Failure'Access));
   end Register_Tail_Commands;

   procedure Register_Tail_Properties
     (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail byte suffix", Tail.Test_Tail_Byte_Suffix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:tail standard input bytes",
            Tail.Test_Tail_Standard_Input_Byte_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail line suffix", Tail.Test_Tail_Line_Suffix_Property'Access));
   end Register_Tail_Properties;

   procedure Register_Wc
     (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:wc multiple files", Wc.Test_Wc_Multiple_Files'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:wc default and mixed text",
            Wc.Test_Wc_Default_And_Mixed_Text'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:wc text counts", Wc.Test_Wc_Text_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc invalid UTF-8", Wc.Test_Wc_Text_Invalid_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:wc malformed UTF-8",
            Wc.Test_Wc_Text_Malformed_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:wc code point validity",
            Wc.Test_Wc_Text_Code_Point_Validity'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc standard input", Wc.Test_Wc_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc byte count", Wc.Test_Wc_Byte_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:wc standard input bytes",
            Wc.Test_Wc_Standard_Input_Byte_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc line count", Wc.Test_Wc_Line_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:wc standard input lines",
            Wc.Test_Wc_Standard_Input_Line_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc output failure", Wc.Test_Wc_Output_Failure'Access));
   end Register_Wc;
end Command_Tests.Stream_Suite_Entries;
