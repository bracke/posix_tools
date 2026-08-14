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
        (Result,
         Caller.Create
           ("regression:REG-CAT-0002 missing file continuation",
            Test_Cat_Continues_After_Missing_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cat standard input", Test_Cat_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDIN-0001 standard input operands",
            Test_Cat_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:cat byte preservation", Test_Cat_Byte_Preservation_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cat output failure", Test_Cat_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-CAT-0003 cat output failure", Test_Cat_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:dirname", Test_Dirname'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:dirname edge cases", Test_Dirname_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:simple output failures", Test_Simple_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0001 simple output failures",
            Test_Simple_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:echo", Test_Echo'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:echo data edge cases", Test_Echo_Data_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:echo output", Test_Echo_Output_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:echo extension handling", Test_Echo_Extensions_Are_Sole_Argument'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:end-of-options", Test_End_Of_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:env utility status", Test_Env_Utility_Status'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:expanded utilities", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:expanded verbose output failures",
            Test_Expanded_Verbose_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cp", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cksum", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cmp", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:comm", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cut", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:date", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:dd", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:env", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:find", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:ln", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:ls", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:mkdir", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:mv", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:od", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:paste", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:printf", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:rm", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:rmdir", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:split", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:sort", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tee", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:test", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:touch", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tr", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:uniq", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:xargs", Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:xargs status bands", Test_Xargs_Status_Bands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-OPTIONS-0002 expanded option ordering",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0001 bounded binary copy",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0002 localized overwrite prompt",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0003 fifo recreation",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0004 socket recreation",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-SORT-0001 stable unique sort",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-ENV-0001 utility status",
            Test_Env_Utility_Status'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-VERBOSE-0001 verbose output failures",
            Test_Expanded_Verbose_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDERR-0001 xargs trace failure",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-XARGS-0001 status bands",
            Test_Xargs_Status_Bands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0002 find output failure",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0003 date output failure",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0004 dd output failure",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0005 tr output failure",
            Test_Expanded_Command_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:false", Test_False'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:false extension edges", Test_False_Extension_Edges'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:head counts", Test_Head_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-HEAD-0001 head counts", Test_Head_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head default limits", Test_Head_Default_Limits'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head prefix", Test_Head_Prefix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head standard input", Test_Head_Standard_Input_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:head invalid count", Test_Head_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-HEAD-0002 head invalid count", Test_Head_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-HEAD-0004 head missing count", Test_Head_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head multiple file headers", Test_Head_Multiple_File_Headers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head standard input", Test_Head_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head output failure", Test_Head_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-HEAD-0003 head output failure", Test_Head_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:help and version", Test_Help_And_Version'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("locale:help", Test_Help_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:version data", Test_Version_Locale_Invariance'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:diagnostic", Test_Diagnostic_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("presentation:styling", Test_Presentation_Styling'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:identity", Test_Identity'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:identity data", Test_Identity_Locale_Invariance'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:pwd context fallbacks", Test_Pwd_Context_Fallbacks'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:pwd options", Test_Pwd_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:pwd option precedence", Test_Pwd_Option_Precedence_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root list", Test_Root_List'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:root list inventory", Test_Root_List_Inventory_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:root list data", Test_Root_List_Locale_Invariance'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root usage edges", Test_Root_Usage_Edges'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root paths", Test_Root_Paths'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:root verify", Test_Root_Verify'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:root verify statuses", Test_Root_Verify_Status_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:root paths verify inventory",
            Test_Root_Paths_Verify_Inventory_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:root command help uses command metadata",
            Test_Root_Command_Help_Uses_Command_Metadata'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("property:root command help inventory",
            Test_Root_Command_Help_Inventory_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root version and help", Test_Root_Version_And_Help'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:root help", Test_Root_Localized_Help'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:root output failure", Test_Root_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-ROOT-0002 root output failure", Test_Root_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail byte mode edges", Test_Tail_Byte_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-TAIL-0001 tail byte suffix", Test_Tail_Byte_Mode_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail compact counts", Test_Tail_Compact_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-TAIL-0002 tail compact counts", Test_Tail_Compact_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tail follow live", Test_Tail_Follow_Live'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-TAIL-0006 tail live follow", Test_Tail_Follow_Live'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tail invalid count", Test_Tail_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-TAIL-0003 tail invalid count", Test_Tail_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-TAIL-0005 tail missing count", Test_Tail_Invalid_Count'Access));
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
        (Result, Caller.Create ("regression:REG-TAIL-0004 tail output failure", Test_Tail_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail byte suffix", Test_Tail_Byte_Suffix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail standard input bytes", Test_Tail_Standard_Input_Byte_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:tail line suffix", Test_Tail_Line_Suffix_Property'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:usage errors", Test_Usage_Errors'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-DIAG-0001 diagnostic escaping",
            Test_Usage_Errors'Access));
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
        (Result, Caller.Create ("regression:REG-WC-0002 wc split utf-8", Test_Wc_Text_Invalid_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc malformed UTF-8", Test_Wc_Text_Malformed_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-WC-0003 wc malformed utf-8", Test_Wc_Text_Malformed_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-WC-0004 wc code point validity", Test_Wc_Text_Malformed_UTF_8'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc standard input", Test_Wc_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc byte count", Test_Wc_Byte_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc standard input bytes", Test_Wc_Standard_Input_Byte_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc line count", Test_Wc_Line_Count_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:wc standard input lines", Test_Wc_Standard_Input_Line_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:wc output failure", Test_Wc_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("regression:REG-WC-0005 wc output failure", Test_Wc_Output_Failure'Access));
      return Result;
   end Test_Suite;
end Command_Tests.Suite;
