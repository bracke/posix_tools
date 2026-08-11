with AUnit.Test_Caller;
with AUnit.Test_Suites;

package body Command_Tests.Suite is
   package Caller is new AUnit.Test_Caller (Command_Tests.Fixture);

   function Test_Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:basename", Test_Basename'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:basename edge cases", Test_Basename_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:basename dirname commands", Test_Basename_Dirname_Command_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cat files", Test_Cat_Files'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:cat continues after missing file", Test_Cat_Continues_After_Missing_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cat standard input", Test_Cat_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:cat byte preservation", Test_Cat_Byte_Preservation_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cat output failure", Test_Cat_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:dirname", Test_Dirname'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:dirname edge cases", Test_Dirname_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:simple output failures", Test_Simple_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:echo", Test_Echo'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:echo data edge cases", Test_Echo_Data_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:echo output", Test_Echo_Output_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:echo extension handling", Test_Echo_Extensions_Are_Sole_Argument'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:end-of-options", Test_End_Of_Options'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:false", Test_False'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:false extension edges", Test_False_Extension_Edges'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:head counts", Test_Head_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head default limits", Test_Head_Default_Limits'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head prefix", Test_Head_Prefix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head standard input", Test_Head_Standard_Input_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:head invalid count", Test_Head_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head multiple file headers", Test_Head_Multiple_File_Headers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head standard input", Test_Head_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head output failure", Test_Head_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:help and version", Test_Help_And_Version'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("locale:help", Test_Help_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:diagnostic", Test_Diagnostic_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("presentation:styling", Test_Presentation_Styling'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:identity", Test_Identity'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:pwd context fallbacks", Test_Pwd_Context_Fallbacks'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:pwd options", Test_Pwd_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:pwd option precedence", Test_Pwd_Option_Precedence_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root list", Test_Root_List'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root usage edges", Test_Root_Usage_Edges'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root paths", Test_Root_Paths'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root verify", Test_Root_Verify'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:root command help uses command metadata",
            Test_Root_Command_Help_Uses_Command_Metadata'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root version and help", Test_Root_Version_And_Help'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:root help", Test_Root_Localized_Help'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root output failure", Test_Root_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail byte mode edges", Test_Tail_Byte_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail compact counts", Test_Tail_Compact_Counts'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tail invalid count", Test_Tail_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail line mode edges", Test_Tail_Line_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail multiple file headers", Test_Tail_Multiple_File_Headers'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tail plus origin", Test_Tail_Plus_Origin'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail standard input", Test_Tail_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail output failure", Test_Tail_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail byte suffix", Test_Tail_Byte_Suffix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail line suffix", Test_Tail_Line_Suffix_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:usage errors", Test_Usage_Errors'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:true", Test_True'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:true extension edges", Test_True_Extension_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:true false operands", Test_True_False_Operand_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:wc multiple files", Test_Wc_Multiple_Files'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc default and mixed text", Test_Wc_Default_And_Mixed_Text'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:wc text counts", Test_Wc_Text_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc invalid UTF-8", Test_Wc_Text_Invalid_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc malformed UTF-8", Test_Wc_Text_Malformed_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc standard input", Test_Wc_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc byte count", Test_Wc_Byte_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc line count", Test_Wc_Line_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc output failure", Test_Wc_Output_Failure'Access));
      return Result;
   end Test_Suite;
end Command_Tests.Suite;
