with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Paths;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Tooling_Checks;
with Tooling_Support;

package body Integration_Smoke is
   use Tooling_Support;

   procedure Run is
      use Ada.Strings.Unbounded;

      procedure Expect_Output
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Expected_Status : Integer;
         Expected_Output : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Capture_Within (Label, Program, Args);
      begin
         if Captured.Status /= Expected_Status then
            --  Run it again with its errors kept: a crash says why on stderr.
            declare
               Again : constant Project_Tools.Processes.Captured_Process :=
                 Capture_Within (Label & " with its errors", Program, Args, Err_To_Out => True);
            begin
               Ada.Text_IO.Put_Line (To_String (Again.Output));
            end;
            Tooling_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Tooling_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output;

      procedure Expect_Nonempty_Line
        (Label   : String;
         Program : String;
         Args    : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Capture_Within (Label, Program, Args);
         Output : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 0 then
            Tooling_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status));
         elsif Output'Length <= 1 or else Output (Output'Last) /= Character'Val (10) then
            Tooling_Checks.Fail (Label & " did not produce one nonempty line");
         end if;
      end Expect_Nonempty_Line;

      procedure Expect_Output_With_Input
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Input           : String;
         Expected_Status : Integer;
         Expected_Output : String;
         Err_To_Out      : Boolean := False)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Capture_Within (Label, Program, Args, Input => Input, Err_To_Out => Err_To_Out);
      begin
         if Captured.Status /= Expected_Status then
            Tooling_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Tooling_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output_With_Input;

      LF : constant Character := Character'Val (10);

      function Identity_Output (Command : String) return String is
      begin
         return
           "schema=1" & LF
           & "project=posix-tools" & LF
           & "command=" & Command & LF
           & "version=" & Posix_Tools.Version.Version_String & LF;
      end Identity_Output;

      --  The value of the string constant Name that the Ada spec at Path
      --  declares, so the expected engine versions follow the constants
      --  the commands report rather than a copy of them.
      function String_Constant (Path : String; Name : String) return String is
         Content : constant String := Project_Tools.Files.Read_Raw_File (Path);
         Marker  : constant String := Name & " : constant String := """;
         At_Name : constant Natural := Ada.Strings.Fixed.Index (Content, Marker);
         From    : constant Positive := At_Name + Marker'Length;
      begin
         if At_Name = 0 then
            Tooling_Checks.Fail (Path & " declares no string constant " & Name);
         end if;

         return Content (From .. Ada.Strings.Fixed.Index (Content (From .. Content'Last), """") - 1);
      end String_Constant;

      Awklib_Version : constant String :=
        String_Constant (Project_Tools.Files.Join (Root, "../awklib/src/awklib.ads"), "Version");
      Sedlib_Version : constant String :=
        String_Constant (Project_Tools.Files.Join (Root, "tools/sed/src/library/sed-version.ads"), "Engine_Version");

      function Version_Output (Command : String) return String is
      begin
         if Command = "awk" then
            return
              "awk " & Posix_Tools.Version.Version_String & LF
              & "awklib " & Awklib_Version & LF
              & "license MIT" & LF;
         elsif Command = "grep" then
            return
              "grep " & Posix_Tools.Version.Version_String & LF
              & "engine greplib" & LF
              & "license MIT" & LF;
         elsif Command = "sed" then
            return
              "sed " & Posix_Tools.Version.Version_String & LF
              & "engine sedlib " & Sedlib_Version & LF
              & "license MIT" & LF;
         else
            return Command & " (posix-tools) " & Posix_Tools.Version.Version_String & LF;
         end if;
      end Version_Output;

      Smoke_File : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-smoke.txt");
      Smoke_Leaf : constant String := "posix-tools-executable-smoke.txt";

      procedure Expect_File (Label, Path, Expected_Content : String) is
      begin
         if not Project_Tools.Files.File_Exists (Path) then
            Tooling_Checks.Fail (Label & " did not create expected file");
         else
            declare
               Actual_Content : constant String := Project_Tools.Files.Read_Raw_File (Path);
            begin
               if Actual_Content /= Expected_Content then
                  Tooling_Checks.Fail
                    (Label & " created file with unexpected content: expected """
                     & Display_Output (Expected_Content) & """ actual """
                     & Display_Output (Actual_Content) & """");
               end if;
            end;
         end if;
      end Expect_File;

      procedure Remove_Path (Path : String) is
      begin
         if Project_Tools.Files.Directory_Exists (Path) then
            Project_Tools.Files.Delete_Tree (Path);
         else
            Project_Tools.Files.Delete_File_If_Present (Path);
         end if;
      end Remove_Path;
   begin
      Expect_Output
        ("root executable version",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
         0,
         "posix-tools " & Posix_Tools.Version.Version_String & LF);

      Expect_Output
        ("root executable identity",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
         0,
         Identity_Output ("posix-tools"));

      Expect_Nonempty_Line
        ("root executable help",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
         begin
            Expect_Output
              (Executable & " executable version",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
               0,
               Version_Output (Executable));

            Expect_Output
              (Executable & " executable identity",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
               0,
               Identity_Output (Executable));

            Expect_Nonempty_Line
              (Executable & " executable help",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));
         end;
      end loop;

      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("basename executable data",
         Built_Command_Path ("basename"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Smoke_Leaf & LF);

      Expect_Output
        ("cat executable data",
         Built_Command_Path ("cat"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output
        ("dirname executable data",
         Built_Command_Path ("dirname"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Posix_Tools.Paths.Dirname (Smoke_File) & LF);

      Expect_Output
        ("echo executable data",
         Built_Command_Path ("echo"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha beta" & LF);

      Expect_Output
        ("printf executable data",
         Built_Command_Path ("printf"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("%s:%s\n"),
             Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha:beta" & LF);

      Expect_Output
        ("date executable data",
         Built_Command_Path ("date"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-u"),
                                             Project_Tools.Processes.Argument ("+%Z")]),
         0,
         "UTC" & LF);

      Expect_Output
        ("dd executable data",
         Built_Command_Path ("dd"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("if=" & Smoke_File),
                                             Project_Tools.Processes.Argument ("bs=5"),
                                             Project_Tools.Processes.Argument ("count=1")]),
         0,
         "alpha");

      Expect_Output
        ("env executable data",
         Built_Command_Path ("env"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-i"),
                                             Project_Tools.Processes.Argument ("NAME=value")]),
         0,
         "NAME=value" & LF);

      Expect_Output
        ("false executable status",
         Built_Command_Path ("false"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         1,
         "");

      Expect_Output
        ("head executable data",
         Built_Command_Path ("head"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      declare
         Copy_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-copy.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
         Expect_Output
           ("cp executable data",
            Built_Command_Path ("cp"),
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument (Smoke_File),
                Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "");
         Expect_Output
           ("cp executable copied data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
      end;

      Expect_Output
        ("find executable data",
         Built_Command_Path ("find"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                             Project_Tools.Processes.Argument ("-type"),
                                             Project_Tools.Processes.Argument ("f")]),
         0,
         Smoke_File & LF);

      Expect_Output
        ("grep executable data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex default",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("a+b")]),
         "a+b" & LF & "ab" & LF,
         0,
         "a+b" & LF);

      Expect_Output_With_Input
        ("grep executable extended regex",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-E"),
                                             Project_Tools.Processes.Argument ("a+b")]),
         "a+b" & LF & "ab" & LF,
         0,
         "ab" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex interval",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("^a\{2,3\}$")]),
         "a" & LF & "aa" & LF & "aaa" & LF & "aaaa" & LF,
         0,
         "aa" & LF & "aaa" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex grouping",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("^a\(b\|c\)$")]),
         "ab" & LF & "ac" & LF & "ad" & LF,
         0,
         "ab" & LF & "ac" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex equivalence class",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("[[=a=]]")]),
         "=" & LF & "a" & LF & "b" & LF,
         0,
         "a" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex collating symbol",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("[[.ch.]]")]),
         "cat" & LF & "hat" & LF & "chord" & LF,
         0,
         "chord" & LF);

      declare
         Env_Command : constant String := Project_Tools.Processes.Locate_Command ("env");
         N_Tilde : constant String := Character'Val (16#C3#) & Character'Val (16#B1#);
      begin
         if Env_Command = "" then
            Tooling_Checks.Fail ("grep locale range smoke requires env");
         end if;

         Expect_Output_With_Input
           ("grep executable basic regex locale range",
            Env_Command,
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("LC_ALL=es_ES.UTF-8"),
                Project_Tools.Processes.Argument (Built_Command_Path ("grep")),
                Project_Tools.Processes.Argument ("-G"),
                Project_Tools.Processes.Argument ("[n-o]")]),
            "n" & LF & N_Tilde & LF & "o" & LF & "p" & LF,
            0,
            "n" & LF & N_Tilde & LF & "o" & LF);
      end;

      Expect_Output
        ("grep executable context data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-A"),
                                             Project_Tools.Processes.Argument ("1"),
                                             Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output
        ("grep executable only-matching data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-ow"),
                                             Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      declare
         Env_Command : constant String := Project_Tools.Processes.Locate_Command ("env");
      begin
         if Env_Command = "" then
            Tooling_Checks.Fail ("grep localized diagnostic smoke requires env");
         end if;

         Expect_Output_With_Input
           ("grep executable localized diagnostic",
            Env_Command,
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("LC_ALL=da_DK.UTF-8"),
                Project_Tools.Processes.Argument (Built_Command_Path ("grep")),
                Project_Tools.Processes.Argument ("-Z"),
                Project_Tools.Processes.Argument ("pattern")]),
            "",
            2,
            "grep: ukendt valgmulighed '-Z'" & LF
            & "usage: grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] "
            & "[-m num] [-e pattern] [-f pattern_file] pattern [file...]" & LF,
            True);
      end;

      declare
         Grep_Dir : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-grep-dir");
         Grep_Subdir : constant String := Project_Tools.Files.Join (Grep_Dir, "sub");
         Grep_File : constant String := Project_Tools.Files.Join (Grep_Subdir, "hit.txt");
      begin
         Remove_Path (Grep_Dir);
         Expect_Output
           ("grep executable recursive mkdir root",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Grep_Dir)]),
            0,
            "");
         Expect_Output
           ("grep executable recursive mkdir sub",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Grep_Subdir)]),
            0,
            "");
         Project_Tools.Files.Write_Raw_File (Grep_File, "needle" & LF);
         Expect_Output
           ("grep executable recursive data",
            Built_Command_Path ("grep"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-r"),
                                                Project_Tools.Processes.Argument ("needle"),
                                                Project_Tools.Processes.Argument (Grep_Dir)]),
            0,
            Grep_File & ":needle" & LF);
         Remove_Path (Grep_Dir);
      end;

      declare
         Link_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-link.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
         Expect_Output
           ("ln executable data",
            Built_Command_Path ("ln"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                                Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "");
         Expect_Output
           ("ln executable linked data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
      end;

      declare
         Made_Dir : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mkdir");
      begin
         Remove_Path (Made_Dir);
         Expect_Output
           ("mkdir executable data",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if not Project_Tools.Files.Directory_Exists (Made_Dir) then
            Tooling_Checks.Fail ("mkdir executable data did not create directory");
         end if;
         Expect_Output
           ("rmdir executable data",
            Built_Command_Path ("rmdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if Project_Tools.Files.Directory_Exists (Made_Dir) then
            Tooling_Checks.Fail ("rmdir executable data did not remove directory");
         end if;
      end;

      declare
         Mv_Source : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-source.txt");
         Mv_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-target.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Mv_Source);
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
         Project_Tools.Files.Write_Raw_File (Mv_Source, "move-data");
         Expect_Output
           ("mv executable data",
            Built_Command_Path ("mv"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Mv_Source),
                                                Project_Tools.Processes.Argument (Mv_Target)]),
            0,
            "");
         Expect_File ("mv executable data", Mv_Target, "move-data");
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
      end;

      declare
         Rm_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-rm.txt");
      begin
         Project_Tools.Files.Write_Raw_File (Rm_Target, "remove-data");
         Expect_Output
           ("rm executable data",
            Built_Command_Path ("rm"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Rm_Target)]),
            0,
            "");
         if Project_Tools.Files.File_Exists (Rm_Target) then
            Tooling_Checks.Fail ("rm executable data did not remove file");
         end if;
      end;

      Expect_Nonempty_Line
        ("pwd executable data",
         Built_Command_Path ("pwd"),
         Project_Tools.Processes.No_Arguments);

      Project_Tools.Files.Write_Raw_File (Smoke_File, "beta" & LF & "alpha");
      Expect_Output
        ("sort executable data",
         Built_Command_Path ("sort"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);
      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("tail executable data",
         Built_Command_Path ("tail"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "beta" & LF);

      Expect_Output
        ("true executable status",
         Built_Command_Path ("true"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         0,
         "");

      declare
         Tee_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-tee.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
         Expect_Output_With_Input
           ("tee executable data",
            Built_Command_Path ("tee"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Tee_Target)]),
            "tee-data" & LF,
            0,
            "tee-data" & LF);
         Expect_File ("tee executable data", Tee_Target, "tee-data" & LF);
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
      end;

      Expect_Output
        ("test executable status",
         Built_Command_Path ("test"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-f"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "");

      declare
         Touch_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-touch.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
         Expect_Output
           ("touch executable data",
            Built_Command_Path ("touch"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Touch_Target)]),
            0,
            "");
         Expect_File ("touch executable data", Touch_Target, "");
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
      end;

      Expect_Output_With_Input
        ("tr executable data",
         Built_Command_Path ("tr"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("a-z"),
             Project_Tools.Processes.Argument ("A-Z")]),
         "alpha",
         0,
         "ALPHA");

      Expect_Output_With_Input
        ("uniq executable data",
         Built_Command_Path ("uniq"),
         Project_Tools.Processes.No_Arguments,
         "alpha" & LF & "alpha" & LF & "beta" & LF,
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output_With_Input
        ("xargs executable data",
         Built_Command_Path ("xargs"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-r")]),
         "",
         0,
         "");

      Expect_Output
        ("wc executable data",
         Built_Command_Path ("wc"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-c"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "11 " & Smoke_File & LF);

      Project_Tools.Files.Delete_File_If_Present (Smoke_File);

      Ada.Text_IO.Put_Line ("executable integration smoke checks passed");
   end Run;
end Integration_Smoke;
