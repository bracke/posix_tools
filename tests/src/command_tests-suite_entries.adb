with AUnit.Test_Caller;
with AUnit.Test_Suites;
with File_Command_Tests;

package body Command_Tests.Suite_Entries is
   package Caller is new AUnit.Test_Caller (Command_Tests.Fixture);
   package File_Caller is new AUnit.Test_Caller (File_Command_Tests.Fixture);

   --  The file commands' tests, each under the command it holds to POSIX.
   procedure Register_File_Commands (Result : AUnit.Test_Suites.Access_Test_Suite);

   procedure Register_File_Commands (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:rm refuses dot and root operands", File_Command_Tests.Test_Rm_Refuses_Dot_And_Root'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:rm force reports failures", File_Command_Tests.Test_Rm_Force_Reports_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:rm interactive per entry", File_Command_Tests.Test_Rm_Interactive_Per_Entry'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:rm and mv prompts localized", File_Command_Tests.Test_Rm_Mv_Prompts_Localized'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:ln same file", File_Command_Tests.Test_Ln_Same_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:mv move by copying", File_Command_Tests.Test_Move_By_Copying'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:mv diagnostics", File_Command_Tests.Test_Mv_Diagnostics'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp link loop", File_Command_Tests.Test_Cp_Link_Loop'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp link options", File_Command_Tests.Test_Cp_Link_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp into itself through a link", File_Command_Tests.Test_Cp_Into_Itself_Through_Link'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp preserves mode bits", File_Command_Tests.Test_Cp_Preserves_Mode_Bits'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp force replaces unwritable target", File_Command_Tests.Test_Cp_Force_Replaces_Unwritable'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp interactive inside a tree", File_Command_Tests.Test_Cp_Interactive_Inside_Tree'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp leaves the source alone", File_Command_Tests.Test_Cp_Leaves_Source_Alone'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:ls operands", File_Command_Tests.Test_Ls_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:chmod symbolic grammar", File_Command_Tests.Test_Chmod_Symbolic_Grammar'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:mkdir mode and diagnostics", File_Command_Tests.Test_Mkdir_Mode_And_Diagnostics'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:find glob brackets", File_Command_Tests.Test_Glob_Brackets'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:wc utf-8 resynchronises", File_Command_Tests.Test_UTF_8_Resynchronises'Access));
   end Register_File_Commands;

   procedure Register (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      Register_File_Commands (Result);
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:du", Test_Du'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:fold", Test_Fold'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:host identity commands", Test_Host_Identity_Commands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:simple output failures", Test_Simple_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:standard input read failures", Test_Standard_Input_Read_Failures'Access));
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:expand", Test_Expand'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:expr", Test_Expr'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:expr extension operands", Test_Expr_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:find exec batches", Test_Find_Exec_Batches'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:find missing operands", Test_Find_Missing_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:find symbolic links", Test_Find_Symbolic_Links'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:printf character conversion", Test_Printf_Character_Conversion'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:printf escapes", Test_Printf_Escapes'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:printf extension operands", Test_Printf_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:printf numeric arguments", Test_Printf_Numeric_Arguments'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:test argument counts", Test_Test_Argument_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:test extension operands", Test_Test_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:test integer operands", Test_Test_Integer_Operands'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:file", Test_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:extended utilities", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:verbose output failures",
            Test_Command_Verbose_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:arch", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cp", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cksum", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cmp", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:comm", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:cut", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:date", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:dd", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:df", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:du smoke", Test_Du'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:env", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:expand smoke", Test_Expand'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:expr smoke", Test_Expr'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:file smoke", Test_File'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:find", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:fold smoke", Test_Fold'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:getconf", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:groups", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:hostname", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:ln", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:locale", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:ls", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:mkdir", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:mkfifo", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:mv", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:nice", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:nl smoke", Test_Nl'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:nohup", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:od", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:paste", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:pathchk", Test_Pathchk'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:printenv", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:printf", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:rm", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:rmdir", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:seq smoke", Test_Seq'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:sha256sum", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:split", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:sort", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:stat", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tee", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:test", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:timeout", Test_Timeout_Statuses'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:touch", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tr", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tty", Test_Tty'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:unexpand smoke", Test_Unexpand'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:unlink smoke", Test_Unlink'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:uniq", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:which", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:xargs", Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:yes smoke", Test_Yes'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:xargs status bands", Test_Xargs_Status_Bands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-OPTIONS-0002 command option ordering",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0001 bounded binary copy",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0002 localized overwrite prompt",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0003 fifo recreation",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-CP-0004 socket recreation",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-SORT-0001 stable unique sort",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-ENV-0001 utility status",
            Test_Env_Utility_Status'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-VERBOSE-0001 verbose output failures",
            Test_Command_Verbose_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDERR-0001 xargs trace failure",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-XARGS-0001 status bands",
            Test_Xargs_Status_Bands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0002 find output failure",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0003 date output failure",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0004 dd output failure",
            Test_Command_Surface_Smoke'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("regression:REG-STDOUT-0005 tr output failure",
            Test_Command_Surface_Smoke'Access));
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:nl", Test_Nl'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:seq", Test_Seq'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:seq empty range", Test_Seq_Empty_Range'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:sort large input", Test_Sort_Large_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:sort ordering rules", Test_Sort_Ordering_Rules'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cut characters", Test_Cut_Characters'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tee opens each file once", Test_Tee_Opens_Each_File_Once'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:tr streams characters", Test_Tr_Streams_Characters'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:uniq filters", Test_Uniq_Filters'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create ("command:xargs continues after failure", Test_Xargs_Continues_After_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:unlink", Test_Unlink'Access));
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:unexpand", Test_Unexpand'Access));
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:yes", Test_Yes'Access));
   end Register;
end Command_Tests.Suite_Entries;
