with AUnit.Test_Caller;
with Command_Tests.Diagnostic_Tests;
with Command_Tests.Dispatch;
with Command_Tests.Head_Tests;
with Command_Tests.Locale_Tests;
with Command_Tests.Option_Behavior_Tests;
with Command_Tests.Output_Failure_Tests;
with Command_Tests.Root_Tests;
with Command_Tests.Scripting;
with Command_Tests.Simple_Tests;
with Command_Tests.Stream_Suite_Entries;
with Command_Tests.Stream_Command_Tests;
with Command_Tests.Xargs_Tests;
with Command_Tests.Surface_Smoke.Data;
with Command_Tests.Surface_Smoke.Files;
with Command_Tests.Surface_Smoke.Filters;
with Command_Tests.Surface_Smoke.Metadata;
with Command_Tests.Surface_Smoke.Metadata.Pathchk;
with Command_Tests.Surface_Smoke.Host;
with Command_Tests.Surface_Smoke.Text;
with Command_Tests.Surface_Smoke.Text.Sort_Cases;
with File_Command_Tests;
with Grep_Command_Tests;
with Rg_Command_Tests;
with Rg_Color_Tests;
with Rg_Context_Tests;
with Rg_Diagnostic_Tests;
with Rg_Differential_Tests;
with Rg_Encoding_Tests;
with Rg_Follow_Tests;
with Rg_Heading_Tests;
with Rg_Input_Tests;
with Rg_Json_Tests;
with Rg_Multiline_Tests;
with Rg_Null_Tests;
with Rg_Replace_Tests;
with Rg_Robustness_Tests;
with Rg_Sort_Tests;
with Rg_Stats_Tests;
with Rg_Unicode_Tests;
with Rg_Worker_Tests;

package body Command_Tests.Suite_Entries is
   use Command_Tests.Diagnostic_Tests;
   use Command_Tests.Head_Tests;
   use Command_Tests.Locale_Tests;
   use Command_Tests.Option_Behavior_Tests;
   use Command_Tests.Output_Failure_Tests;
   use Command_Tests.Root_Tests;
   use Command_Tests.Simple_Tests;
   use Command_Tests.Stream_Command_Tests;
   use Command_Tests.Xargs_Tests;
   package Caller is new AUnit.Test_Caller (Command_Tests.Fixture);
   package File_Caller is new AUnit.Test_Caller (File_Command_Tests.Fixture);
   package Grep_Caller is new AUnit.Test_Caller (Grep_Command_Tests.Fixture);
   package Rg_Caller is new AUnit.Test_Caller (Rg_Command_Tests.Fixture);
   package Rg_Color_Caller is new AUnit.Test_Caller (Rg_Color_Tests.Fixture);
   package Rg_Context_Caller is new AUnit.Test_Caller (Rg_Context_Tests.Fixture);
   package Rg_Diagnostic_Caller is new AUnit.Test_Caller (Rg_Diagnostic_Tests.Fixture);
   package Rg_Differential_Caller is new AUnit.Test_Caller (Rg_Differential_Tests.Fixture);
   package Rg_Encoding_Caller is new AUnit.Test_Caller (Rg_Encoding_Tests.Fixture);
   package Rg_Follow_Caller is new AUnit.Test_Caller (Rg_Follow_Tests.Fixture);
   package Rg_Heading_Caller is new AUnit.Test_Caller (Rg_Heading_Tests.Fixture);
   package Rg_Input_Caller is new AUnit.Test_Caller (Rg_Input_Tests.Fixture);
   package Rg_Json_Caller is new AUnit.Test_Caller (Rg_Json_Tests.Fixture);
   package Rg_Multiline_Caller is new AUnit.Test_Caller (Rg_Multiline_Tests.Fixture);
   package Rg_Null_Caller is new AUnit.Test_Caller (Rg_Null_Tests.Fixture);
   package Rg_Replace_Caller is new AUnit.Test_Caller (Rg_Replace_Tests.Fixture);
   package Rg_Robustness_Caller is new AUnit.Test_Caller (Rg_Robustness_Tests.Fixture);
   package Rg_Sort_Caller is new AUnit.Test_Caller (Rg_Sort_Tests.Fixture);
   package Rg_Stats_Caller is new AUnit.Test_Caller (Rg_Stats_Tests.Fixture);
   package Rg_Unicode_Caller is new AUnit.Test_Caller (Rg_Unicode_Tests.Fixture);
   package Rg_Worker_Caller is new AUnit.Test_Caller (Rg_Worker_Tests.Fixture);
   package Surface_Caller is new AUnit.Test_Caller (Command_Tests.Surface_Smoke.Surface_Fixture);

   --  The file commands' tests, each under the command it holds to POSIX.
   procedure Register_File_Commands (Result : AUnit.Test_Suites.Access_Test_Suite);

   --  grep's tests, run through a capturing context.
   procedure Register_Grep (Result : AUnit.Test_Suites.Access_Test_Suite);

   --  rg's command and pattern-adapter tests.
   procedure Register_Rg (Result : AUnit.Test_Suites.Access_Test_Suite);

   --  The command surface tests, one per command or small family, in the
   --  order the single surface test they replace ran them.
   procedure Register_Surface_Commands (Result : AUnit.Test_Suites.Access_Test_Suite);

   procedure Register_File_Commands (Result : AUnit.Test_Suites.Access_Test_Suite) is
      package T renames File_Command_Tests;
   begin
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:rm refuses dot and root operands",
            T.Test_Rm_Refuses_Dot_And_Root'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:rm force reports failures",
            T.Test_Rm_Force_Reports_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:rm interactive per entry",
            T.Test_Rm_Interactive_Per_Entry'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:rm and mv prompts localized",
            T.Test_Rm_Mv_Prompts_Localized'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:ln same file", T.Test_Ln_Same_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:mv move by copying", T.Test_Move_By_Copying'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:mv diagnostics", T.Test_Mv_Diagnostics'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp link loop", T.Test_Cp_Link_Loop'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:cp link options", T.Test_Cp_Link_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:cp into itself through a link",
            T.Test_Cp_Into_Itself_Through_Link'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:cp preserves mode bits", T.Test_Cp_Preserves_Mode_Bits'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:cp force replaces unwritable target",
            T.Test_Cp_Force_Replaces_Unwritable'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:cp interactive inside a tree",
            T.Test_Cp_Interactive_Inside_Tree'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:cp leaves the source alone",
            T.Test_Cp_Leaves_Source_Alone'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:ls operands", T.Test_Ls_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:chmod symbolic grammar", T.Test_Chmod_Symbolic_Grammar'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:mkdir mode and diagnostics",
            T.Test_Mkdir_Mode_And_Diagnostics'Access));
      AUnit.Test_Suites.Add_Test
        (Result, File_Caller.Create ("command:find glob brackets", T.Test_Glob_Brackets'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         File_Caller.Create
           ("command:wc utf-8 resynchronises", T.Test_UTF_8_Resynchronises'Access));
   end Register_File_Commands;

   procedure Register_Grep (Result : AUnit.Test_Suites.Access_Test_Suite) is
      package T renames Grep_Command_Tests;
   begin
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep output is not truncated", T.Test_Output_Is_Not_Truncated'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep output failure", T.Test_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Grep_Caller.Create
           ("command:grep quiet selection wins over errors",
            T.Test_Quiet_Selection_Wins_Over_Errors'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep context separators", T.Test_Context_Separators'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep pattern lists", T.Test_Pattern_Lists'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep standard input label", T.Test_Standard_Input_Label'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Grep_Caller.Create
           ("command:grep help and version",
            Grep_Command_Tests.Test_Help_And_Version'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep basic to extended", T.Test_Basic_To_Extended'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Grep_Caller.Create ("command:grep event rendering", T.Test_Event_Rendering'Access));
   end Register_Grep;

   procedure Register_Rg (Result : AUnit.Test_Suites.Access_Test_Suite) is
      package T renames Rg_Command_Tests;
   begin
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Caller.Create
           ("command:rg help and version",
            Rg_Command_Tests.Test_Help_And_Version'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg pattern adapter", T.Test_Pattern_Adapter'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg default syntax policy", T.Test_Default_Syntax_Policy'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Differential_Caller.Create
           ("command:rg ripgrep 15.2.0 differential",
            Rg_Differential_Tests.Test_Reference_Differential'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Caller.Create
           ("command:rg option parsing",
            Rg_Command_Tests.Test_Option_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Diagnostic_Caller.Create
           ("command:rg diagnostics",
            Rg_Diagnostic_Tests.Test_Diagnostics'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Robustness_Caller.Create
           ("command:rg fault handling",
            Rg_Robustness_Tests.Test_Faults'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Robustness_Caller.Create
           ("property:rg fixed strings",
            Rg_Robustness_Tests.Test_Fixed_String_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Worker_Caller.Create
           ("command:rg parallel workers",
            Rg_Worker_Tests.Test_Parallel_Search'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg sequential search", T.Test_Sequential_Search'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg pattern files", T.Test_Pattern_Files'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg ignore policy", T.Test_Ignore_Policy'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg ignore controls", T.Test_Ignore_Controls'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg recursive traversal", T.Test_Recursive_Traversal'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg file listing", T.Test_File_Listing'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg glob filtering", T.Test_Glob_Filtering'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg file types", T.Test_File_Types'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg rendering", T.Test_Rendering'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Context_Caller.Create
           ("command:rg context output", Rg_Context_Tests.Test_Context_Output'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Follow_Caller.Create
           ("command:rg symbolic-link traversal", Rg_Follow_Tests.Test_Follow_Links'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Follow_Caller.Create
           ("command:rg file-system boundary", Rg_Follow_Tests.Test_One_File_System'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Heading_Caller.Create
           ("command:rg heading output", Rg_Heading_Tests.Test_Heading_Output'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg selection controls", T.Test_Selection_Controls'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg result modes", T.Test_Result_Modes'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Rg_Caller.Create ("command:rg match result modes", T.Test_Match_Result_Modes'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Unicode_Caller.Create
           ("command:rg Unicode case", Rg_Unicode_Tests.Test_Unicode_Case'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Input_Caller.Create
           ("command:rg binary controls", Rg_Input_Tests.Test_Binary_Controls'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Input_Caller.Create
           ("command:rg input encoding", Rg_Input_Tests.Test_Encoding'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Encoding_Caller.Create
           ("command:rg encoding surface", Rg_Encoding_Tests.Test_Encoding_Surface'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Input_Caller.Create
           ("command:rg maximum file size", Rg_Input_Tests.Test_Max_File_Size'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Multiline_Caller.Create
           ("command:rg multiline search", Rg_Multiline_Tests.Test_Multiline_Search'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Null_Caller.Create
           ("command:rg NUL modes", Rg_Null_Tests.Test_Nul_Modes'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Replace_Caller.Create
           ("command:rg replacement output", Rg_Replace_Tests.Test_Replacement_Output'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Sort_Caller.Create
           ("command:rg path sorting", Rg_Sort_Tests.Test_Path_Sorting'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Stats_Caller.Create
           ("command:rg statistics", Rg_Stats_Tests.Test_Statistics'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Color_Caller.Create
           ("command:rg color output", Rg_Color_Tests.Test_Color_Output'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Rg_Json_Caller.Create
           ("command:rg JSON output", Rg_Json_Tests.Test_Json_Output'Access));
   end Register_Rg;

   procedure Register_Surface_Commands (Result : AUnit.Test_Suites.Access_Test_Suite) is
      package Data renames Command_Tests.Surface_Smoke.Data;
      package Files renames Command_Tests.Surface_Smoke.Files;
      package Filters renames Command_Tests.Surface_Smoke.Filters;
      package Metadata renames Command_Tests.Surface_Smoke.Metadata;
      package Host renames Command_Tests.Surface_Smoke.Host;
      package Text renames Command_Tests.Surface_Smoke.Text;
   begin
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:cp surface", Files.Test_Cp'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:cp bounded binary", Files.Test_Cp_Bounded_Binary'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:cp localized prompt", Files.Test_Cp_Localized_Prompt'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:cp FIFO recreation", Files.Test_Cp_FIFO_Recreation'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:cp socket recreation", Files.Test_Cp_Socket_Recreation'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:ln surface", Files.Test_Ln'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:link surface", Files.Test_Link'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:readlink surface", Files.Test_Readlink'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:realpath surface", Files.Test_Realpath'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:chmod surface", Files.Test_Chmod'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:chown surface", Files.Test_Chown'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:chgrp surface", Files.Test_Chgrp'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:uname surface", Host.Test_Uname'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:sleep surface", Host.Test_Sleep'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:id surface", Host.Test_Id'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:whoami surface", Host.Test_Whoami'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:logname surface", Host.Test_Logname'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:kill surface", Host.Test_Kill'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:mv surface", Files.Test_Mv'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:rm surface", Files.Test_Rm'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:mv end of options surface", Files.Test_Mv_End_Of_Options'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:rm directory surface", Files.Test_Rm_Directory'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:mkdir surface", Files.Test_Mkdir'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:arch surface", Host.Test_Arch'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:df surface", Host.Test_Df'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:getconf surface", Host.Test_Getconf'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:groups surface", Host.Test_Groups'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:locale surface", Host.Test_Locale'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:hostname surface", Host.Test_Hostname'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:mkfifo surface", Files.Test_Mkfifo'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:nice surface", Host.Test_Nice'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:nohup surface", Host.Test_Nohup'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:printenv surface", Host.Test_Printenv'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:which surface", Host.Test_Which'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:stat surface", Files.Test_Stat'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:cp multiple sources surface", Files.Test_Cp_Multiple_Sources'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:mv multiple sources surface", Files.Test_Mv_Multiple_Sources'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:rmdir surface", Files.Test_Rmdir'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:rm verbose surface", Files.Test_Rm_Verbose'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:option operands surface", Files.Test_Option_Operands'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:touch surface", Metadata.Test_Touch'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:dd basic", Text.Test_Dd_Basic'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:dd positioning", Text.Test_Dd_Positioning'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:dd conversions", Text.Test_Dd_Conversions'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:dd files and validation",
            Text.Test_Dd_Files_And_Validation'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:printf basic", Text.Test_Printf_Basic'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:printf integers", Text.Test_Printf_Integers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:printf floating", Text.Test_Printf_Floating'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:printf defaults and output",
            Text.Test_Printf_Defaults_And_Output'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:printf invalid numbers",
            Text.Test_Printf_Invalid_Numbers'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:printf characters and escapes",
            Text.Test_Printf_Characters_And_Escapes'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:sort surface",
            Command_Tests.Surface_Smoke.Text.Sort_Cases.Test_Sort'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:sort folding surface",
            Command_Tests.Surface_Smoke.Text.Sort_Cases.Test_Sort_Folding'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:sort keys surface",
            Text.Test_Sort_Keys_And_Modifiers'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:sort numeric and I/O surface",
            Text.Test_Sort_Numeric_And_IO'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create ("command:uniq output operand surface", Filters.Test_Uniq_Output_Operand'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:tee surface", Filters.Test_Tee'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:tr surface", Filters.Test_Tr'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:uniq surface", Filters.Test_Uniq'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:xargs surface", Filters.Test_Xargs'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:date surface", Host.Test_Date'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:date formats surface", Host.Test_Date_Formats'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:date localized formats surface",
            Host.Test_Date_Localized_Formats'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:date timezones surface", Host.Test_Date_Timezones'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:date setting surface", Host.Test_Date_Setting'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:env surface", Host.Test_Env'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:find surface", Metadata.Test_Find'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:find names and types surface",
            Metadata.Test_Find_Names_And_Types'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:find size and time surface",
            Metadata.Test_Find_Size_And_Time'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:find execution surface", Metadata.Test_Find_Execution'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:find traversal and metadata surface",
            Metadata.Test_Find_Traversal_And_Metadata'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:find expressions surface", Metadata.Test_Find_Expressions'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:test surface", Metadata.Test_Test'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:cksum surface", Data.Test_Cksum'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Surface_Caller.Create ("command:sha256sum surface", Data.Test_Sha256sum'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:cmp surface", Data.Test_Cmp'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:paste surface",
            Command_Tests.Surface_Smoke.Data.Test_Paste'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:cut surface", Data.Test_Cut'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:comm surface", Data.Test_Comm'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:od surface", Data.Test_Od'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:ls surface", Metadata.Test_Ls'Access));
      AUnit.Test_Suites.Add_Test (Result, Surface_Caller.Create ("command:split surface", Data.Test_Split'Access));
   end Register_Surface_Commands;

   procedure Register (Result : AUnit.Test_Suites.Access_Test_Suite) is
   begin
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:internal error diagnostics",
            Command_Tests.Surface_Smoke.Host.Test_Internal_Error_Diagnostics'Access));
      Register_File_Commands (Result);
      Register_Grep (Result);
      Register_Rg (Result);
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
           ("command:cat continues after missing file",
            Test_Cat_Continues_After_Missing_File'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:cat standard input",
            Test_Cat_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:cat byte preservation", Test_Cat_Byte_Preservation_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:cat output failure", Test_Cat_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:dirname", Test_Dirname'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:dirname edge cases", Test_Dirname_Edge_Cases'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:du", Test_Du'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:fold", Test_Fold'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:host identity commands", Test_Host_Identity_Commands'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:standard input read failures", Test_Standard_Input_Read_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:simple output failures",
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
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:expand", Test_Expand'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:expr", Command_Tests.Scripting.Test_Expr'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:expr extension operands", Command_Tests.Scripting.Test_Expr_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:find exec batches", Command_Tests.Scripting.Test_Find_Exec_Batches'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:find missing operands", Command_Tests.Scripting.Test_Find_Missing_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:find symbolic links", Command_Tests.Scripting.Test_Find_Symbolic_Links'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:printf character conversion", Command_Tests.Scripting.Test_Printf_Character_Conversion'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:printf escapes", Command_Tests.Scripting.Test_Printf_Escapes'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:printf extension operands", Command_Tests.Scripting.Test_Printf_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:printf numeric arguments", Command_Tests.Scripting.Test_Printf_Numeric_Arguments'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:test argument counts", Command_Tests.Scripting.Test_Test_Argument_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:test extension operands", Command_Tests.Scripting.Test_Test_Extension_Operands'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:test integer operands", Command_Tests.Scripting.Test_Test_Integer_Operands'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:file", Test_File'Access));
      Register_Surface_Commands (Result);
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:dispatch binds inventory wrappers",
            Command_Tests.Dispatch.Test_Binds_Wrappers'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:pathchk",
            Command_Tests.Surface_Smoke.Metadata.Pathchk.Test_Pathchk'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:timeout", Command_Tests.Surface_Smoke.Host.Test_Timeout'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:tty", Test_Tty'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:env utility status",
            Command_Tests.Surface_Smoke.Host.Test_Env_Utility_Status'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:verbose output failures",
            Test_Command_Verbose_Output_Failures'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Surface_Caller.Create
           ("command:xargs status bands",
            Command_Tests.Surface_Smoke.Filters.Test_Xargs_Status_Bands'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:false", Test_False'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:false extension edges", Test_False_Extension_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head counts", Test_Head_Counts'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head default limits", Test_Head_Default_Limits'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head prefix", Test_Head_Prefix_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:head standard input", Test_Head_Standard_Input_Property'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:head invalid count",
            Test_Head_Invalid_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:head missing count",
            Test_Head_Missing_Count'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head multiple file headers", Test_Head_Multiple_File_Headers'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head standard input", Test_Head_Standard_Input'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:head output failure", Test_Head_Output_Failure'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:help and version",
            Command_Tests.Locale_Tests.Test_Help_And_Version'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("locale:help", Test_Help_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:version data", Test_Version_Locale_Invariance'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:diagnostic", Test_Diagnostic_Locales'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("locale:categories", Test_Locale_Categories'Access));
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
      Command_Tests.Stream_Suite_Entries.Register_Tail_Commands (Result);
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:unexpand", Test_Unexpand'Access));
      Command_Tests.Stream_Suite_Entries.Register_Tail_Properties (Result);
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:option parsing",
            Command_Tests.Option_Behavior_Tests.Test_Option_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("command:usage errors",
            Test_Usage_Errors'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:true", Test_True'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("command:true extension edges", Test_True_Extension_Edges'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("property:true false operands", Test_True_False_Operand_Property'Access));
      Command_Tests.Stream_Suite_Entries.Register_Wc (Result);
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("command:yes", Test_Yes'Access));
   end Register;
end Command_Tests.Suite_Entries;
