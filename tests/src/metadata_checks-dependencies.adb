with Project_Tools.Release_Checks;

package body Metadata_Checks.Dependencies is
   procedure Run is
   begin
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "posix_tools_common =");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "aunit =");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "project_tools =");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/alire.toml", "posix_tools_common = { path = ""../common"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/alire.toml", "project_tools = { path = ""../../project_tools"" }");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "executables = [""posix_tools_tests""]");
      Require_Crate_Metadata ("tests/alire.toml", "posix_tools_tests", "posix_tools_tests.gpr");
      Forbid_Text
        ("tests/alire.toml",
         "posix_tools =",
         "tests manifest must not depend on root binary crate");
      Forbid_Text
        ("tests/alire.toml",
         "hostkit =",
         "tests manifest must use common adapters instead of depending on hostkit directly");
      Forbid_Text
        ("tests/alire.toml",
         "messages =",
         "tests manifest must use common localization instead of depending on messages directly");
      Forbid_Text
        ("tests/alire.toml",
         "terminal_styles =",
         "tests manifest must use common presentation instead of depending on terminal_styles directly");
      Forbid_Text ("common/alire.toml", "aunit =", "common manifest must not depend on aunit");
      Forbid_Text
        ("common/alire.toml", "project_tools =", "common manifest must not depend on project_tools");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers.adb",
         "Ada.Text_IO.Standard_Input",
         "file helpers must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers.adb",
         "Ada.Streams.Stream_IO",
         "file helpers must use project filesystem adapters for file operands");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers-streaming.adb",
         "Ada.Text_IO.Standard_Input",
         "file helpers must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers-streaming.adb",
         "Ada.Streams.Stream_IO",
         "file helpers must use project filesystem adapters for file operands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "if File_Name = ""-"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Context.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "function Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.ads", "function Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STDIN-0001");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Ada.Text_IO.Standard_Input",
         "tail must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Ada.Streams.Stream_IO",
         "tail command must use shared file helpers for file chunk iteration");
      Forbid_Text
        ("common/src/posix_tools-commands-wc.adb",
         "Ada.Text_IO.Standard_Input",
         "wc must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-wc.adb",
         "Ada.Streams.Stream_IO",
         "wc command must use shared file helpers for file chunk iteration");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers-streaming.adb", "procedure For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers-streaming.adb", "Action (Context, Buffer, Last)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "For_Each_File_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "File_Helpers.Streaming.For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Action => Retain_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Action => Emit_From_Start");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "File_Helpers.Streaming.For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Action => Count_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail byte mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc default and mixed text");
      Forbid_Text
        ("common/src/posix_tools-commands-head.adb",
         "Requested : Posix_Tools.Numbers.Count := 10;",
         "head must not keep requested line count in package-level mutable state");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Seen      : Posix_Tools.Numbers.Count := 0;",
         "tail must not keep line position in package-level mutable state");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Buffer    : Lines.Vector;",
         "tail must not keep retained lines in package-level mutable state");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Requested  : Posix_Tools.Numbers.Count := 10;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "First_File : Positive := 1;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-tail_counts.ads", "type Count_Origin is (From_End, From_Start);");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Origin     : Count_Origin := From_End;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Filled : Natural := 0;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Next   : Ada.Streams.Stream_Element_Offset := Ring'First;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Retain_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Emit_From_Start");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head output failure status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail output failure status");
   end Run;
end Metadata_Checks.Dependencies;
