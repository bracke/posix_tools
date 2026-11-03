separate (Command_Tests.Stream_Command_Tests)

   procedure Test_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Text_Path : constant String := Fixture_Path ("file-text.txt");
      Data_Path : constant String := Fixture_Path ("file-data.bin");
      Empty_Path : constant String := Fixture_Path ("file-empty.bin");
      Dir_Path : constant String := Fixture_Path ("file-dir");
      Png_Path : constant String := Fixture_Path ("file-image.png");
      Zip_Path : constant String := Fixture_Path ("file-archive.zip");
      Script_Path : constant String := Fixture_Path ("file-script.sh");
      Tar_Path : constant String := Fixture_Path ("file-archive.tar");
      Magic_Path : constant String := Fixture_Path ("file.magic");
      Magic_Data_Path : constant String := Fixture_Path ("file-magic-data.bin");
      Missing_Path : constant String := Fixture_Path ("file-missing.txt");
      LF : constant Character := Character'Val (10);

   begin
      Delete_If_Exists (Text_Path);
      Delete_If_Exists (Data_Path);
      Delete_If_Exists (Empty_Path);
      Delete_If_Exists (Dir_Path);
      Delete_If_Exists (Png_Path);
      Delete_If_Exists (Zip_Path);
      Delete_If_Exists (Script_Path);
      Delete_If_Exists (Tar_Path);
      Delete_If_Exists (Magic_Path);
      Delete_If_Exists (Magic_Data_Path);

      Write_File (Text_Path, "hello" & LF);
      Write_File (Data_Path, "a" & Character'Val (0) & "b");
      Write_File (Empty_Path, "");
      Write_File (Png_Path, Character'Val (16#89#) & "PNG" & Character'Val (13) & LF
                  & Character'Val (16#1A#) & LF);
      Write_File (Zip_Path, "PK" & Character'Val (3) & Character'Val (4) & "rest");
      Write_File (Script_Path, "#!/bin/sh" & LF & "echo ok" & LF);
      Write_File (Tar_Path, String'(1 .. 257 => Character'Val (0)) & "ustar");
      Write_File (Magic_Path, "0:AB\x00:custom binary:application/x-custom" & LF);
      Write_File (Magic_Data_Path, "AB" & Character'Val (0) & "tail");
      if not Ada.Directories.Exists (Dir_Path) then
         Ada.Directories.Create_Directory (Dir_Path);
      end if;

      Context.Initialize ("file", Four_Args (Text_Path, Data_Path, Empty_Path, Dir_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "file classifies readable operands successfully");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Text_Path & ": text" & LF
           & Data_Path & ": data" & LF
           & Empty_Path & ": empty" & LF
         & Dir_Path & ": directory" & LF,
         "file classification output");

      Context.Initialize ("file", Four_Args (Png_Path, Zip_Path, Script_Path, Tar_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           Png_Path & ": PNG image data" & LF
           & Zip_Path & ": Zip archive data" & LF
           & Script_Path & ": script text executable" & LF
           & Tar_Path & ": tar archive data" & LF,
         "file applies built-in content signatures");

      Context.Initialize ("file", Two_Args ("-i", Png_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Png_Path & ": image/png" & LF,
         "file -i emits MIME classification");

      Context.Initialize ("file", One_Arg ("-"));
      Test_Contexts.Set_Standard_Input (Context, "%PDF-1.7" & LF);
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-: PDF document" & LF,
         "file classifies standard input operand");

      Context.Initialize ("file", Three_Args ("-m", Magic_Path, Magic_Data_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Magic_Data_Path & ": custom binary" & LF,
         "file applies external magic-file descriptions");

      Context.Initialize ("file", Four_Args ("-i", "-m", Magic_Path, Magic_Data_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Magic_Data_Path & ": application/x-custom" & LF,
         "file applies external magic-file MIME descriptions");

      Context.Initialize ("file", One_Arg (Missing_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "file reports missing operand path as operational failure");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "",
         "file missing path has no data output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "file: '" & Missing_Path & "': cannot open file" & LF,
         "file missing diagnostic");

      Context.Initialize ("file", No_Args);
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "file rejects missing operands");

      Context.Initialize ("file", One_Arg ("-z"));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "file rejects unknown options");

      Delete_If_Exists (Text_Path);
      Delete_If_Exists (Data_Path);
      Delete_If_Exists (Empty_Path);
      Delete_If_Exists (Dir_Path);
      Delete_If_Exists (Png_Path);
      Delete_If_Exists (Zip_Path);
      Delete_If_Exists (Script_Path);
      Delete_If_Exists (Tar_Path);
      Delete_If_Exists (Magic_Path);
      Delete_If_Exists (Magic_Data_Path);
   end Test_File;
