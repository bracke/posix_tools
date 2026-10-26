with Project_Tools.Release_Checks;

package body Metadata_Checks.Source_Rules is
   procedure Run is
   begin
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "hostkit =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "messages =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "terminal_styles =");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "hostkit = { path = ""../../hostkit"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "messages = { path = ""../../messages"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "terminal_styles = { path = ""../../terminal_styles"" }");
      Require_Crate_Metadata ("common/alire.toml", "posix_tools_common", "posix_tools_common.gpr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.help.usage = Brug");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.help.usage = Uso");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "en.posix_tools.diagnostic.line_count.invalid");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.file.read_failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.internal_failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.text.invalid_utf8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.pwd.unavailable");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.resource.count_too_large");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "with Messages.Runtime;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Runtime.Render");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Arguments.Set");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Result.Output_Text");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.help.usage");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.help.options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.common.option.help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.common.option.version");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Escape_Untrusted (Subject)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "function Escape_Untrusted");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-usage_messages.adb", "posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-usage_messages.adb", "posix_tools.diagnostic.extra_operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-usage_messages.adb", "posix_tools.diagnostic.count.invalid");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "posix_tools.diagnostic.file.read_failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "posix_tools.diagnostic.resource.count_too_large");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "posix_tools.diagnostic.text.invalid_utf8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "unknown locale no message-key leak");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Danish extra operand diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Danish count too large diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "with Terminal_Styles;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.ads", "type Style_Mode is (Automatic, Always, Never)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Auto");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Always");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Never");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Destination_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Role_Error");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Presentation.Diagnostic");
      Forbid_Text
        ("common/src/posix_tools-help.adb",
         "with Terminal_Styles",
         "help rendering must use Posix_Tools.Presentation instead of terminal_styles directly");
      Forbid_Text
        ("common/src/posix_tools-commands-root.adb",
         "with Terminal_Styles",
         "root rendering must use Posix_Tools.Presentation instead of terminal_styles directly");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Never)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Always)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Automatic)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Terminal_Name");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Standard_Error");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-terminals.adb",
         "Hostkit.Host",
         "terminal adapter must use hostkit descriptors for standard stream terminal checks");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Terminals.Standard_Output_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Terminals.Standard_Error_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.adb", "return Self.Output_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.adb", "return Self.Error_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Max_Identity_Output_Bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Process.Locate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Process.Run_Captured");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Descriptors.Open_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Descriptors.Read");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Capture_Leaf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Timeout_Ms  => 2000");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Output = Excessive_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Error = Excessive_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Expected_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Is_Wrong_Version_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Output = Expected_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Fs.Is_Executable");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "return ""shadowed""");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "stdout.txt",
         "identity verification must not use a fixed stdout capture leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "stderr.txt",
         "identity verification must not use a fixed stderr capture leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "Ada.Text_IO",
         "identity verification must read captured subprocess output through hostkit descriptors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Host_Adapters.Executables.Locate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Host_Adapters.Executables.Verify_Identity");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Staged_Verification;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Verify_Identity_At_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:root verify");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:root verify statuses");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Contains_Executable (Context.Argument (2))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Render_Command_Help (Context, Context.Argument (2))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Render_Command_Help (Context, Context.Command_Name)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "root command help must reuse command metadata");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "function Root_Status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "return Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "exit when Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "root output failure status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-ROOT-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:simple output failures");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "simple output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STDOUT-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Stop := Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Ok := not Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "exit when Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat output failure has no read diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "en.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-environment.adb", "with Ada.Environment_Variables;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "with Ada.Directories;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "Hostkit.Metadata.Same_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "type File_Time is private");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "Copy_File_Times");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "File_Time_Of");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "Set_File_Times");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-host_adapters-file_system.adb",
         "Hostkit.Metadata.Set_File_Times");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-file_system.adb",
         "Ada.Streams.Stream_IO",
         "production file adapter must route byte stream operations through hostkit descriptors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.ads", "private with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Hostkit.Descriptors.Write");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Hostkit.Descriptors.Read");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Open_Write_Exclusive");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Spill_Leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.ads",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.adb",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.adb",
         "spill.bin",
         "production temporary storage filenames must not use a fixed spill leaf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-arguments.adb", "with Ada.Command_Line;");
      Forbid_Text
        ("common/src/posix_tools-arguments.adb",
         "Ada.Command_Line",
         "argument value type must not capture process command-line state");
      Forbid_Text
        ("common/src/posix_tools-localization.adb",
         "Ada.Directories",
         "localization must use the project filesystem adapter for catalog path probing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd stale PWD fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "Try_Physical_Current_Directory");
      Forbid_Text
        ("common/src/posix_tools-commands-pwd.adb",
         "when others",
         "pwd must report expected current-directory failures through context results");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Error");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Transfer_Interrupted");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-streams.adb",
         "Ada.Text_IO",
         "standard stream adapter must use hostkit descriptors for byte-oriented process streams");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/build_checks.adb", "build common crate");
      --  Each unit must stay in the proof driver's table at its level.
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.version""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.command_inventory""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.numbers""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.paths""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.utf_8""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.classification""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.whitespace_data""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.streams.counting""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.counts""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.tail_rings""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.tail_counts""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.wc_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.exit_status""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.commands.results""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.commands""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.streams""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.escaping""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.checksum_lines""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.checksums""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.cut_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.dd_conversions""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.duration_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.file_magic_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.line_breaks""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.byte_classes""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.matching""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.nice_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.base_parsing""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.suffixes""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.tab_stops""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.logical_paths""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.portable_paths""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.test_operators""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.hex_digests""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.sort_modifiers""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.paste_delimiters""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.printf_escapes""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.seq_formats""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.find_expressions""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.od_formats""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.signal_names""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.nl_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.decimal_parsing""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.file_modes""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.file_modes""), To_Unbounded_String (""2""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.numeric_images""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.option_parsing""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.octal_modes""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.octal_parsing""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.owner_groups""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.time_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.touch_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/proof_targets.adb",
         "(To_Unbounded_String (""posix_tools.text.xargs_fields""), To_Unbounded_String (""1""))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "--prover=z3");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "Selected GNATprove targets");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Cut_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.DD_Conversions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Duration_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Checksum_Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Checksums");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.File_Magic_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Decimal_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Base_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Suffixes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Tab_Stops");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Logical_Paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Portable_Paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Test_Operators");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Hex_Digests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Sort_Modifiers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Paste_Delimiters");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Nice_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Xargs_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Find_Expressions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.OD_Formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Signal_Names");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.NL_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Count_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parsed_Find_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parse_Find_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Age_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Ownership_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Missing_Owner_Name_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parse_Type_Filter");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Find_Special_File_Class");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Type_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.File_Modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_Any_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_All_Mode_Bits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Set_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Clear_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Clear_Mode_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Set_Mode_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parsed_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parse_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parse_Find_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Symbolic_Permission_Bits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Apply_Symbolic_Permission_Operation");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Apply_Symbolic_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Symbolic_Who_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Permission_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-touch_fields.ads", "Normalize_ISO_Date_Time");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Missing_Argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-signals.ads", "Unknown_Disposition");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Numeric_Images");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Seq_Formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Tail_Counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Option_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Cursor_Progresses");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Source_Is_Consistent");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Status_Is_Consistent");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-xargs_parsing.adb", "Text.Byte_Classes.Is_Xargs_Blank");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-host.ads", "Last <= Groups'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "Last <= Groups'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Octal_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Octal_Modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Time_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Touch_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-line_breaks.ads", "Line_Number_Through");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Arguments.Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "host adapters");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Ada.Containers.Indefinite_Vectors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "metadata checks keep that document synchronized");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "tail ring arithmetic tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "wc field arithmetic tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/release-process.md", "posix_tools_tests prove");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/build_checks.adb", "build root crate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/build_checks.adb", "build tests crate");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/build_checks.adb",
         "for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/build_checks.adb",
         """build "" & Posix_Tools.Command_Inventory.Executable (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "procedure Run_Staged_Verification");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Verify_Identity_At_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", """posix-tools"", Built_Root_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Built_Root_Path, ""0.0.0""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Status /= ""wrong version""");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/posix_tools_tests.adb",
         "Executable : constant String := Posix_Tools.Command_Inventory.Executable (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "staged verification checks passed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "posix_tools.gpr", "for Body (""Posix_Tools_Main"") use ""posix-tools.adb""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tools/false/posix_tools_false.gpr", "for Body (""Posix_Tools_False_Main"") use ""false.adb""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tools/true/posix_tools_true.gpr", "for Body (""Posix_Tools_True_Main"") use ""true.adb""");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Hostkit",
         "command context must use project host adapters instead of hostkit directly");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Directories",
         "command context must use project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Environment_Variables",
         "command context must use project environment adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Text_IO",
         "command context must use project stream adapter");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Environment;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Streams;");
      Forbid_Text
        ("common/src/posix_tools-commands-find_evaluation.adb",
         "GNAT.OS_Lib",
         "find evaluation must use project host adapters");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Fs",
         "find command algorithm must use the project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Metadata",
         "find command algorithm must use the project filesystem adapter for metadata");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Signals",
         "find command algorithm must use the project signals adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Ada.Directories",
         "find command algorithm must use the project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "GNAT.OS_Lib",
         "find command algorithm must use the project filesystem adapter for timestamps");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-find.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tee.adb", "with Posix_Tools.Host_Adapters.Signals;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Terminals;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Environment.Value");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.File_System.Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-contexts.adb",
         "Host_Adapters.File_System.Try_Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-contexts.adb",
         "Host_Adapters.File_System.Path_Names_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Write_Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Write_Standard_Error_Line");
      Forbid_Text
        ("common/src/posix_tools-help.adb",
         "with Terminal_Styles",
         "help renderer must use project presentation adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-root.adb",
         "with Terminal_Styles",
         "root command must use project presentation adapter");
   end Run;
end Metadata_Checks.Source_Rules;
