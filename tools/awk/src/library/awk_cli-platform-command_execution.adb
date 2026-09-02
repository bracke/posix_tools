separate (Awk_CLI.Platform)
package body Command_Execution is
   type Command_Run_Files is record
      Temp_Dir    : U.Unbounded_String;
      Stdin_Path  : U.Unbounded_String;
      Stdout_Path : U.Unbounded_String;
      Stderr_Path : U.Unbounded_String;
   end record;

   function Create_Command_Run_Files return Command_Run_Files is
      Temp_Dir : constant String :=
        Hostkit.Fs.Create_Temporary_Directory ("awk-command-getline");
   begin
      return
        (Temp_Dir    => U.To_Unbounded_String (Temp_Dir),
         Stdin_Path  => U.To_Unbounded_String (Join (Temp_Dir, "stdin")),
         Stdout_Path => U.To_Unbounded_String (Join (Temp_Dir, "stdout")),
         Stderr_Path => U.To_Unbounded_String (Join (Temp_Dir, "stderr")));
   end Create_Command_Run_Files;

   function Command_Run_Files_Available (Files : Command_Run_Files) return Boolean is
     (U.To_String (Files.Temp_Dir) /= "" and then Hostkit.Shell.Executable /= "");

   procedure Cleanup_Command_Run_Files (Files : Command_Run_Files) is
   begin
      if U.To_String (Files.Temp_Dir) /= "" then
         Delete_If_Present (U.To_String (Files.Stdin_Path));
         Delete_If_Present (U.To_String (Files.Stdout_Path));
         Delete_If_Present (U.To_String (Files.Stderr_Path));
         Delete_Tree_If_Present (U.To_String (Files.Temp_Dir));
      end if;
   end Cleanup_Command_Run_Files;

   function Run_Command
     (Command : String;
      Output  : out U.Unbounded_String) return Boolean
   is
      --  This is the host service for awklib's command-getline callback. It is
      --  deliberately isolated here so no CLI package shells out as an AWK
      --  parser/runtime fallback.
      Args    : Hostkit.String_Vectors.Vector;
      Status  : Hostkit.Process.Process_Outcome;
      Ignored : Integer := -1;
      Files   : Command_Run_Files;
      Success : Boolean := False;
   begin
      Output := U.Null_Unbounded_String;
      Files := Create_Command_Run_Files;

      if Command_Run_Files_Available (Files)
        and then Write_File (U.To_String (Files.Stdin_Path), "", Append => False)
      then
         Args.Append
           (Hostkit.UString'(U.To_Unbounded_String (Hostkit.Shell.Command_Option)));
         Args.Append (Hostkit.UString'(U.To_Unbounded_String (Command)));

         Status :=
           Hostkit.Process.Run_Captured
             (Program     => Hostkit.Shell.Executable,
              Arguments   => Args,
              Stdin_Path  => U.To_String (Files.Stdin_Path),
              Stdout_Path => U.To_String (Files.Stdout_Path),
              Stderr_Path => U.To_String (Files.Stderr_Path));

         if Status.Started
           and then not Status.Timed_Out
           and then Read_File (U.To_String (Files.Stdout_Path), Output) = Read_Success
         then
            Ignored := Status.Exit_Status;
            Success := Ignored >= 0;
         end if;
      end if;

      Cleanup_Command_Run_Files (Files);
      return Success;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error
         | Constraint_Error | Program_Error | Storage_Error =>
         Output := U.Null_Unbounded_String;
         Cleanup_Command_Run_Files (Files);
         return False;
   end Run_Command;
end Command_Execution;
