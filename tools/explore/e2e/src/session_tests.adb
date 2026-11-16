with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with E2E_Bootstrap;
with E2E_Files;
with E2E_Processes;
with E2E_Rig;
with E2E_Rig.Testing;
with GNAT.OS_Lib;
with Terminal.Core;
with Terminal.PTY.Backend;

package body Session_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);

   use type Ada.Directories.File_Size;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   CR  : constant Character := Character'Val (13);
   DEL : constant Character := Character'Val (127);
   ESC : constant Character := Character'Val (27);

   subtype Terminal_Modes is Terminal.Core.Mode_Snapshot;

   type Natural_Array is array (Positive range <>) of Natural;

   --  A PNG of one pixel.
   function Tiny_PNG return String is
     ([for Code of Natural_Array'
         [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#, 16#00#, 16#00#, 16#00#, 16#0D#, 16#49#,
          16#48#, 16#44#, 16#52#, 16#00#, 16#00#, 16#00#, 16#01#, 16#00#, 16#00#, 16#00#, 16#01#, 16#08#, 16#06#,
          16#00#, 16#00#, 16#00#, 16#1F#, 16#15#, 16#C4#, 16#89#, 16#00#, 16#00#, 16#00#, 16#0D#, 16#49#, 16#44#,
          16#41#, 16#54#, 16#78#, 16#9C#, 16#63#, 16#F8#, 16#CF#, 16#C0#, 16#F0#, 16#1F#, 16#00#, 16#05#, 16#00#,
          16#01#, 16#FF#, 16#89#, 16#99#, 16#3D#, 16#1D#, 16#00#, 16#00#, 16#00#, 16#00#, 16#49#, 16#45#, 16#4E#,
          16#44#, 16#AE#, 16#42#, 16#60#, 16#82#]
       => Character'Val (Code)]);

   --  Start explore on Directory and wait for its first full frame.
   procedure Open (Session : in out E2E_Rig.Rig; Directory : String; Columns : Positive := 100);

   --  Quit, and check that the terminal was handed back as it was found.
   procedure Quit (Session : in out E2E_Rig.Rig);

   --  Pump until there is a file at Path, at most about five seconds;
   --  whether there is.
   function Wait_For_File (Session : in out E2E_Rig.Rig; Path : String) return Boolean;

   procedure Open (Session : in out E2E_Rig.Rig; Directory : String; Columns : Positive := 100) is
   begin
      E2E_Rig.Start (Session, Directory, Columns => Columns);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "q quit"), "explore drew its screen");
   end Open;

   procedure Quit (Session : in out E2E_Rig.Rig) is
      Ended : Boolean;
      Code  : Integer;
   begin
      E2E_Rig.Send (Session, "q");
      E2E_Rig.Wait_Exit (Session, Ended, Code);
      E2E_Rig.Stop (Session);
      AUnit.Assertions.Assert (Ended and then Code = 0, "explore quit with status 0, not" & Integer'Image (Code));
   end Quit;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:start and quit", Test_Start_And_Quit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:browse and preview", Test_Browse_And_Preview'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:copy", Test_Copy'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("session:concurrent sessions",
            Test_Concurrent_Sessions'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("session:exit status normalization",
            Test_Exit_Status_Normalization'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:resize", Test_Resize'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:clipboard", Test_Clipboard'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:image", Test_Image'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:shell command", Test_Shell_Command'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:interrupt", Test_Interrupt'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("session:launch failure poisons coordinator",
            Test_Launch_Failure_Poisons'Access));
      AUnit.Test_Suites.Add_Test
        (Result,
         Caller.Create
           ("session:subprocess timeout",
            Test_Subprocess_Timeout'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:conflicts", Test_Conflicts'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("session:rename", Test_Rename'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("session:quit while previewing", Test_Quit_While_Previewing'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("session:quit while copying", Test_Quit_While_Copying'Access));
      return Result;
   end Suite;

   procedure Test_Browse_And_Preview (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("browse");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/beta/inner");
      E2E_Files.Write (Root & "/alpha.txt", "the first line" & Character'Val (10) & "the second");
      Open (Session, Root);

      --  Directories come first: beta is selected, and its listing previewed.
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "inner/"), "beta's listing");

      E2E_Rig.Send (Session, "j");
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "the first line") and then E2E_Rig.Wait_For (Session, "the second"),
         "the text file previewed");

      E2E_Rig.Send (Session, "k" & "l");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For_Header (Session, "/browse/beta"), "into beta");

      E2E_Rig.Send (Session, "h");
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For_Header (Session, "/browse") and then E2E_Rig.Wait_For (Session, "alpha.txt"),
         "and back");
      Quit (Session);
   end Test_Browse_And_Preview;

   procedure Test_Clipboard (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("clipboard");
      Session : E2E_Rig.Rig;
   begin
      E2E_Files.Write (Root & "/item", "");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "item"), "listed");

      E2E_Rig.Send (Session, "cc");

      for Step in 1 .. 500 loop
         exit when E2E_Rig.Clipboard (Session)'Length > 0;
         E2E_Rig.Pump (Session, 10);
      end loop;

      AUnit.Assertions.Assert
        (E2E_Rig.Clipboard (Session) = Root & "/item",
         "the terminal put the selected path on the clipboard: " & E2E_Rig.Clipboard (Session));
      Quit (Session);
   end Test_Clipboard;

   procedure Test_Concurrent_Sessions (T : in out Fixture) is
      pragma Unreferenced (T);
      Root   : constant String :=
        E2E_Rig.Fixture ("concurrent-sessions");
      First_Path  : aliased constant String := Root & "/first";
      Second_Path : aliased constant String := Root & "/second";
      First       : aliased E2E_Rig.Rig;
      Second      : aliased E2E_Rig.Rig;
      First_Ok, Second_Ok : Boolean;
      First_Error, Second_Error : Ada.Strings.Unbounded.Unbounded_String;

      procedure Await_Both_Prepared;

      protected Preparation_Gate is
         procedure Arrive;
         entry Wait;
      private
         Arrivals : Natural := 0;
      end Preparation_Gate;

      protected body Preparation_Gate is
         procedure Arrive is
         begin
            Arrivals := Arrivals + 1;
         end Arrive;

         entry Wait when Arrivals = 2 is
         begin
            null;
         end Wait;
      end Preparation_Gate;

      procedure Await_Both_Prepared is
      begin
         Preparation_Gate.Arrive;
         select
            Preparation_Gate.Wait;
         or
            delay 5.0;
            raise Program_Error with
              "concurrent session preparation did not overlap";
         end select;
      end Await_Both_Prepared;

      protected Start_Gate is
         entry Wait;
         procedure Open;
      private
         Opened : Boolean := False;
      end Start_Gate;

      protected body Start_Gate is
         procedure Open is
         begin
            Opened := True;
         end Open;

         entry Wait when Opened is
         begin
            null;
         end Wait;
      end Start_Gate;

      task type Starter
        (Session   : not null access E2E_Rig.Rig;
         Directory : not null access constant String)
      is
         entry Result
           (Ok      : out Boolean;
            Message : out Ada.Strings.Unbounded.Unbounded_String);
      end Starter;

      task body Starter is
         Succeeded : Boolean := False;
         Failure_Message : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Start_Gate.Wait;
         begin
            E2E_Rig.Testing.Start_Synchronized
              (Session.all, Directory.all, Await_Both_Prepared'Access);
            Succeeded := True;
         exception
            when Failure : others =>
               --  intentional terminal exception barrier
               Failure_Message :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Ada.Exceptions.Exception_Information (Failure));
         end;

         accept Result
           (Ok      : out Boolean;
            Message : out Ada.Strings.Unbounded.Unbounded_String)
         do
            Ok := Succeeded;
            Message := Failure_Message;
         end Result;
      end Starter;

      First_Starter  : Starter (First'Access, First_Path'Access);
      Second_Starter : Starter (Second'Access, Second_Path'Access);
   begin
      Ada.Directories.Create_Path (First_Path);
      Ada.Directories.Create_Path (Second_Path);
      E2E_Files.Write (First_Path & "/alpha", "");
      E2E_Files.Write (Second_Path & "/beta", "");

      Start_Gate.Open;
      First_Starter.Result (First_Ok, First_Error);
      Second_Starter.Result (Second_Ok, Second_Error);
      AUnit.Assertions.Assert
        (First_Ok and then Second_Ok,
         "simultaneous starts succeeded: "
         & Ada.Strings.Unbounded.To_String (First_Error)
         & Ada.Strings.Unbounded.To_String (Second_Error));

      E2E_Rig.Expect
        (First, E2E_Rig.Wait_For (First, "alpha"),
         "the first concurrent session listed its fixture");
      E2E_Rig.Expect
        (Second, E2E_Rig.Wait_For (Second, "beta"),
         "the second concurrent session listed its fixture");
      E2E_Rig.Expect
        (First, E2E_Rig.Wait_For (First, "alpha"),
         "the first concurrent session remained independent");

      Quit (Second);
      Quit (First);
   end Test_Concurrent_Sessions;

   procedure Test_Conflicts (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("conflicts");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/dst");
      Ada.Directories.Create_Path (Root & "/src");
      E2E_Files.Write (Root & "/src/a", "new a");
      E2E_Files.Write (Root & "/src/b", "new b");
      E2E_Files.Write (Root & "/dst/a", "old");
      E2E_Files.Write (Root & "/dst/b", "old");
      Open (Session, Root);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "src/"), "listed");

      --  Yank both files of src, and paste them over those of dst.
      E2E_Rig.Send (Session, "j");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "l");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For_Header (Session, "/conflicts/src"), "into src");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "b"), "src listed");
      E2E_Rig.Send (Session, "  y");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "h");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For_Header (Session, "/conflicts"), "back");
      E2E_Rig.Send (Session, "k");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "l");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For_Header (Session, "/conflicts/dst"), "into dst");

      --  Pasted with the jobs panel opened at once, before the job asks.
      E2E_Rig.Send (Session, "pw");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "a exists"), "asked about a");
      E2E_Rig.Send (Session, "o");

      --  Answered, the job asks about b at once: the question shown is b's.
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "b exists"), "then asked about b");
      E2E_Rig.Send (Session, "o");
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "copied a +1")
         and then E2E_Rig.Wait_For (Session, "operations: j/k")
         and then not E2E_Rig.Wait_For (Session, "exists", 300),
         "done, and the jobs panel still open");
      AUnit.Assertions.Assert
        (Ada.Directories.Size (Root & "/dst/a") = 5 and then Ada.Directories.Size (Root & "/dst/b") = 5,
         "both overwritten");
      E2E_Rig.Send (Session, "w");
      E2E_Rig.Pump (Session, 100);
      Quit (Session);
   end Test_Conflicts;

   procedure Test_Copy (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("copy");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/target");
      E2E_Files.Write (Root & "/source.txt", "copied text");
      Open (Session, Root);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "source.txt"), "listed");

      --  Yank the file, go into target, and paste.
      E2E_Rig.Send (Session, "j");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "y");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "k");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "l");
      AUnit.Assertions.Assert (E2E_Rig.Wait_For_Header (Session, "/copy/target"), "into target");
      E2E_Rig.Send (Session, "p");

      --  Done is said in the status line, the last row; the file's preview
      --  says "copied text", and must not be taken for it.
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "source.txt") and then E2E_Rig.Wait_For_Row (Session, 24, " copied source.txt"),
         "the copy listed, and reported done");
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Root & "/target/source.txt")
         and then Ada.Directories.Size (Root & "/target/source.txt") = 11,
         "and on disk, whole");
      Quit (Session);
   end Test_Copy;

   procedure Test_Exit_Status_Normalization (T : in out Fixture) is
      pragma Unreferenced (T);
      package PTY renames Terminal.PTY.Backend;
   begin
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Exited, 1, E2E_Rig.Decoded_Status) = 1,
         "decoded exit status");
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Exited, 300, E2E_Rig.Decoded_Status) = 300,
         "wide decoded exit status");
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Exited, 256, E2E_Rig.Raw_POSIX_Wait_Status) = 1,
         "raw POSIX exit status");
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Signaled, -2, E2E_Rig.Decoded_Status) = 130,
         "decoded signal status");
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Signaled, 2, E2E_Rig.Raw_POSIX_Wait_Status) = 130,
         "raw POSIX signal status");
      AUnit.Assertions.Assert
        (E2E_Rig.Exit_Code
           (PTY.Signaled, 130, E2E_Rig.Raw_POSIX_Wait_Status) = 130,
         "raw POSIX core-dump status");
   end Test_Exit_Status_Normalization;

   procedure Test_Image (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("image");
      Session : E2E_Rig.Rig;
   begin
      E2E_Files.Write (Root & "/dot.png", Tiny_PNG);
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "dot.png"), "listed");

      for Step in 1 .. 300 loop
         exit when E2E_Rig.Placeholder_Cells (Session) > 0;
         E2E_Rig.Pump (Session, 10);
      end loop;

      AUnit.Assertions.Assert (E2E_Rig.Graphics_Count (Session) > 0, "the image was sent as Kitty graphics");
      AUnit.Assertions.Assert
        (E2E_Rig.Placeholder_Cells (Session) > 0, "and placed in the preview pane with placeholders");
      Quit (Session);
   end Test_Image;

   procedure Test_Interrupt (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("interrupt");
      Session : E2E_Rig.Rig;
      Ended   : Boolean;
      Code    : Integer;
   begin
      E2E_Files.Write (Root & "/one", "");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "one"), "listed");

      --  An interrupt while a command has the terminal is the command's,
      --  and explore carries on. The one sent once explore has the terminal
      --  back, when the test makes the file "go", ends the session.
      E2E_Rig.Send (Session, "!");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send
        (Session,
         "target=$PPID; kill -INT ""$target""; echo survived; "
         & "nohup sh -c 'n=200; while [ ""$n"" -gt 0 ] && [ ! -e go ]; do "
         & "n=$((n - 1)); sleep 0.05; done; [ -e go ] && kill -INT ""$1""' "
         & "_ ""$target"" </dev/null >/dev/null 2>&1 &" & CR);
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "press Enter") and then E2E_Rig.Wait_For (Session, "survived"),
         "the command ran on");
      E2E_Rig.Send (Session, "" & CR);
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "q quit") and then E2E_Rig.Modes (Session).Alternate_Screen,
         "explore took the terminal back, the interrupt meant for the command forgotten");

      E2E_Files.Write (Root & "/go", "");
      E2E_Rig.Wait_Exit (Session, Ended, Code);

      declare
         After : constant Terminal_Modes := E2E_Rig.Modes (Session);
      begin
         AUnit.Assertions.Assert
           (Ended and then Code = 130, "ended as an interrupt ends a program, status" & Integer'Image (Code));
         AUnit.Assertions.Assert
           (not After.Alternate_Screen and then not After.Mouse_SGR and then not After.Bracketed_Paste
            and then After.Keyboard_Flags = 0 and then After.Cursor_Visible,
            "the terminal handed back as it was found");
      end;

      E2E_Rig.Stop (Session);
   end Test_Interrupt;

   procedure Test_Launch_Failure_Poisons (T : in out Fixture) is
      pragma Unreferenced (T);
      Status : constant Integer :=
        E2E_Processes.Run
          (E2E_Bootstrap.Program_Path,
           E2E_Rig.Testing.Launch_Failure_Argument,
           Timeout_Ms => 20_000);
   begin
      AUnit.Assertions.Assert
        (Status = 0,
         "the isolated launcher-failure recovery check succeeded");
   end Test_Launch_Failure_Poisons;

   procedure Test_Quit_While_Copying (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("quit-copying");
      Session : E2E_Rig.Rig;
      Ended   : Boolean;
      Code    : Integer;
   begin
      --  The copy finds its target there already and waits for an answer:
      --  it runs, however fast the machine, until it gets one or explore
      --  quits.
      Ada.Directories.Create_Path (Root & "/target");
      E2E_Files.Write (Root & "/item", "new");
      E2E_Files.Write (Root & "/target/item", "old");
      Open (Session, Root);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "item"), "listed");

      --  Directories come first: down to the file, yank, up to target, in.
      E2E_Rig.Send (Session, "j");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "y");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "k");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "l");
      AUnit.Assertions.Assert (E2E_Rig.Wait_For_Header (Session, "/quit-copying/target"), "into target");

      --  Quit typed with the paste, before the copy can ask its question,
      --  which would take the keys: the copy is on the board already, so
      --  quitting asks first.
      E2E_Rig.Send (Session, "pq");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "quit and stop them?"), "quitting asks first");

      --  No keeps explore, and the copy, going; quit asked again at once,
      --  before the copy's question is shown, asks again.
      E2E_Rig.Send (Session, "nq");
      E2E_Rig.Wait_Exit (Session, Ended, Code, Timeout_Ms => 300);
      AUnit.Assertions.Assert (not Ended, "n does not quit");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "quit and stop them?"), "asked again");

      --  Yes quits, stopping the copy where it waits.
      E2E_Rig.Send (Session, "y");
      E2E_Rig.Wait_Exit (Session, Ended, Code);
      E2E_Rig.Stop (Session);
      AUnit.Assertions.Assert (Ended and then Code = 0, "y quits");
      AUnit.Assertions.Assert
        (Ada.Directories.Size (Root & "/target/item") = 3, "and the copy was stopped before it overwrote anything");
   end Test_Quit_While_Copying;

   procedure Test_Quit_While_Previewing (T : in out Fixture) is
      pragma Unreferenced (T);

      LF       : constant Character := Character'Val (10);
      Root     : constant String := E2E_Rig.Fixture ("quit-previewing");
      Scratch  : constant String := Root & "/tmp";
      Taken    : constant String := Scratch & "/explore-thumbnails-1";
      Made     : constant String := Scratch & "/explore-thumbnails-2";
      Session  : E2E_Rig.Rig;
      Ended    : Boolean;
      Code     : Integer;
      Private_Mode : Boolean;
   begin
      Ada.Directories.Create_Path (Root & "/files");
      Ada.Directories.Create_Path (Taken);
      E2E_Files.Write (Root & "/files/x.slow", "");
      E2E_Files.Write
        (Root & "/explore.toml", "[[preview]]" & LF & "match = ""*.slow""" & LF & "run = 'sleep 30'" & LF);

      --  Thumbnails, and what previewers print, go to a directory made below
      --  TMPDIR, whose first name is taken.
      E2E_Rig.Start
        (Session,
         Root & "/files",
         Options             => "--config " & E2E_Rig.Quoted (Root & "/explore.toml"),
         Temporary_Directory => Scratch);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "x.slow"), "listed, and its previewer running");

      for Step in 1 .. 300 loop
         exit when Ada.Directories.Exists (Made);
         E2E_Rig.Pump (Session, 10);
      end loop;

      --  ls, not stat: macOS's stat has no -c, and both print the same mode.
      E2E_Files.Write (Root & "/mode.sh", "test ""$(ls -ld ""$1"" | cut -c1-10)"" = drwx------" & LF);

      declare
         Script    : aliased String := Root & "/mode.sh";
         Directory : aliased String := Made;
      begin
         Private_Mode :=
           GNAT.OS_Lib.Spawn ("/bin/sh", [Script'Unchecked_Access, Directory'Unchecked_Access]) = 0;
      end;

      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Made) and then Private_Mode,
         "a directory of its own, closed to everyone else, not the one whose name was taken");

      --  The previewer is stopped: quitting does not wait for it.
      declare
         Asked : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         E2E_Rig.Send (Session, "q");
         E2E_Rig.Wait_Exit (Session, Ended, Code, Timeout_Ms => 10_000);
         E2E_Rig.Stop (Session);
         AUnit.Assertions.Assert
           (Ended and then Code = 0 and then Ada.Real_Time.Clock - Asked < Ada.Real_Time.Seconds (3),
            "quit at once, with status 0");
      end;
   end Test_Quit_While_Previewing;

   procedure Test_Rename (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("rename");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/sub");
      E2E_Files.Write (Root & "/plain.txt", "");
      E2E_Files.Write (Root & "/sub/found.txt", "");
      Open (Session, Root);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "plain.txt"), "listed");

      --  A click on the parent pane while the new name is typed goes nowhere.
      E2E_Rig.Send (Session, "j");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "r");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "rename to"), "the rename prompt");
      E2E_Rig.Send (Session, ESC & "[<0;5;5M" & ESC & "[<0;5;5m");
      E2E_Rig.Pump (Session, 100);
      E2E_Rig.Send (Session, [1 .. 9 => DEL] & "moved.txt" & CR);
      AUnit.Assertions.Assert
        (Wait_For_File (Session, Root & "/moved.txt") and then not Ada.Directories.Exists (Root & "/plain.txt"),
         "renamed where it was, not in the directory clicked");

      --  A search result is renamed in its own directory, from its own name.
      E2E_Rig.Send (Session, "/");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "found" & CR);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "sub/found.txt"), "found below");
      E2E_Rig.Send (Session, "r");
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "rename to"), "the rename prompt");
      E2E_Rig.Send (Session, [1 .. 9 => DEL] & "kept.txt" & CR);
      AUnit.Assertions.Assert
        (Wait_For_File (Session, Root & "/sub/kept.txt") and then not Ada.Directories.Exists (Root & "/kept.txt"),
         "renamed in sub, not at the search's root");
      Quit (Session);
   end Test_Rename;

   procedure Test_Resize (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("resize");
      Session : E2E_Rig.Rig;
   begin
      Ada.Directories.Create_Path (Root & "/only");
      Open (Session, Root);

      --  Too narrow for the selected entry's details beside the position and
      --  the quit hint, whatever the owner's name: the details give way.
      --  Narrower than anything can be drawn in: explore waits it out.
      E2E_Rig.Resize (Session, 2, 1);
      E2E_Rig.Pump (Session, 200);
      E2E_Rig.Resize (Session, 30, 50);
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For_Row (Session, 30, "q quit"),
         "the status line moved to the new last row");
      E2E_Rig.Expect
        (Session,
         Ada.Strings.Fixed.Index (E2E_Rig.Row (Session, 2), "only/") in 1 .. 4,
         "below 80 columns the current pane is the first");
      Quit (Session);
   end Test_Resize;

   procedure Test_Shell_Command (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("shell");
      Session : E2E_Rig.Rig;
   begin
      E2E_Files.Write (Root & "/one", "");
      Open (Session, Root);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "one"), "listed");

      --  The command runs with the terminal handed to it, and explore waits
      --  for Enter before taking it back.
      E2E_Rig.Send (Session, "!");
      E2E_Rig.Pump (Session, 50);
      E2E_Rig.Send (Session, "echo ran; touch made" & CR);
      E2E_Rig.Expect (Session, E2E_Rig.Wait_For (Session, "press Enter"), "waits");
      AUnit.Assertions.Assert
        (not E2E_Rig.Modes (Session).Alternate_Screen and then E2E_Rig.Wait_For (Session, "ran"),
         "on the main screen, with the command's output");
      E2E_Rig.Send (Session, "" & CR);
      E2E_Rig.Expect
        (Session,
         E2E_Rig.Wait_For (Session, "made") and then E2E_Rig.Modes (Session).Alternate_Screen,
         "back, with what the command made listed");
      AUnit.Assertions.Assert (Ada.Directories.Exists (Root & "/made"), "made in the directory shown");
      Quit (Session);
   end Test_Shell_Command;

   procedure Test_Start_And_Quit (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := E2E_Rig.Fixture ("start");
      Session : E2E_Rig.Rig;
      Ended   : Boolean;
      Code    : Integer;
   begin
      E2E_Files.Write (Root & "/file", "");
      Open (Session, Root);

      declare
         Now : constant Terminal_Modes := E2E_Rig.Modes (Session);
      begin
         AUnit.Assertions.Assert
           (Now.Alternate_Screen and then Now.Mouse_SGR and then Now.Bracketed_Paste and then Now.Focus_Reporting
            and then Now.In_Band_Resize and then Now.Keyboard_Flags = 1,
            "the alternate screen, mouse, paste, focus, resize reports, and disambiguated keys");
      end;

      AUnit.Assertions.Assert
        (E2E_Rig.Header_Shows (Session, Root) and then E2E_Rig.Wait_For_Header (Session, "/start"),
         "the directory on the first line: " & E2E_Rig.Row (Session, 1));

      E2E_Rig.Send (Session, "q");
      E2E_Rig.Wait_Exit (Session, Ended, Code);

      declare
         After : constant Terminal_Modes := E2E_Rig.Modes (Session);
      begin
         AUnit.Assertions.Assert (Ended and then Code = 0, "quit with status 0");
         AUnit.Assertions.Assert
           (not After.Alternate_Screen and then not After.Mouse_SGR and then not After.Mouse_Button
            and then not After.Bracketed_Paste and then not After.Focus_Reporting and then not After.In_Band_Resize
            and then After.Keyboard_Flags = 0 and then After.Cursor_Visible,
            "every mode turned off again, and the cursor shown");
      end;

      E2E_Rig.Stop (Session);
   end Test_Start_And_Quit;

   procedure Test_Subprocess_Timeout (T : in out Fixture) is
      pragma Unreferenced (T);
      Started   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Timed_Out : Boolean := False;
   begin
      begin
         declare
            Status : constant Integer :=
              E2E_Processes.Run
                (E2E_Bootstrap.Program_Path,
                 E2E_Rig.Testing.Timeout_Child_Argument,
                 Timeout_Ms => 50);
            pragma Unreferenced (Status);
         begin
            null;
         end;
      exception
         when Failure : Program_Error =>
            Timed_Out :=
              Ada.Strings.Fixed.Index
                (Ada.Exceptions.Exception_Message (Failure), "timeout") > 0;
      end;

      AUnit.Assertions.Assert
        (Timed_Out,
         "the supervised subprocess reported its timeout");
      AUnit.Assertions.Assert
        (Ada.Real_Time.Clock - Started < Ada.Real_Time.Seconds (3),
         "the timed-out subprocess was killed and reaped promptly");
   end Test_Subprocess_Timeout;

   function Wait_For_File (Session : in out E2E_Rig.Rig; Path : String) return Boolean is
   begin
      for Step in 1 .. 500 loop
         exit when Ada.Directories.Exists (Path);
         E2E_Rig.Pump (Session, 10);
      end loop;

      return Ada.Directories.Exists (Path);
   end Wait_For_File;
end Session_Tests;
