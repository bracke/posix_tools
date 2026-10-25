with Ada.Strings.Unbounded;
with Explore.Application.Controller;
with Explore.Application.Display;
with Explore.Application.Options;
with Explore.Application.Sessions;
with Explore.Application.Terminals;
with Explore.Application.Workers;
with Explore.Directory_Readers;
with Explore.Input;
with Explore.Jobs;
with Explore.Model;
with Explore.Previews;
with Explore.Search;
with Explore.Settings;
with Explore.Settings.Storage;
with Explore.Tabs;
with Explore.Words;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Host_Adapters.Terminal_IO;

--  The parts of a session, and who does what:
--
--  Sessions     what the session knows, and the status line and modes.
--  Terminals    signals, the handshake, input, and the screen taken and given.
--  Display      drawing the frame, the jobs panel, and the preview's image.
--  Workers      the readers, jobs, search, previewer and watches, in step.
--  Controller   what keys and clicks do.
--  Options      the command line.
--
--  This body only puts them together and runs the session's life.
package body Explore.Application is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;
   package Terminal_IO renames Posix_Tools.Host_Adapters.Terminal_IO;
   package Unbounded renames Ada.Strings.Unbounded;

   use Explore.Application.Sessions;

   use type FS.File_Kind;

   --  How long one read waits before the loop looks at signals, watches, and
   --  finished directory reads again. A lone ESC also waits this long for the
   --  rest of a sequence.
   Idle_Poll_Ms : constant := 100;

   --  The wait while directories are being read, so results show promptly.
   Busy_Poll_Ms : constant := 15;

   --  How the session ended, for the caller to report once the screen is the
   --  user's again.
   type Session_Outcome is (Session_Ended, Session_Signalled, Raw_Mode_Refused, Terminal_Unsupported, Output_Failed);

   --  Take the locale's text, the environment, and the configuration at
   --  Config_Path, or at its usual place when that is empty, into State. A
   --  problem with the configuration is shown until the first key, and the
   --  configuration is used as far as it could be read.
   procedure Configure
     (State       : in out Session;
      Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config_Path : String);

   --  Read events and act on them until the session ends, keeping the panes,
   --  the workers and the screen in step between reads.
   procedure Main_Loop (State : in out Session; Readers : in out Explore.Directory_Readers.Board);

   --  Take the terminal over, start the workers, run the session, and give it
   --  all back -- on every way out, an exception included.
   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome);

   procedure Configure
     (State       : in out Session;
      Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config_Path : String)
   is
      Locale   : constant String := Context.Effective_Locale;
      Home     : constant String := Context.Environment_Value ("HOME");
      Path     : constant String :=
        (if Config_Path'Length > 0 then Config_Path
         else Explore.Settings.Configuration_Path (Context.Environment_Value ("XDG_CONFIG_HOME"), Home));
      Loaded   : Explore.Settings.Settings;
      Problems : Explore.Settings.Problem_Vectors.Vector;
   begin
      State.Terminal.In_Tmux := Context.Environment_Defined ("TMUX");
      State.Frame.Text := Explore.Words.Load_Labels (Locale);
      State.Config.Words := Explore.Words.Load (Locale);
      State.Config.Locale := Unbounded.To_Unbounded_String (Locale);
      State.Config.Home := Unbounded.To_Unbounded_String (Home);

      Explore.Settings.Storage.Load (Path, Loaded, Problems);
      State.Browser.Show_Hidden := Loaded.Show_Hidden;
      State.Browser.Order.Key := Loaded.Sort_Key;
      State.Browser.Order.Descending := Loaded.Descending;
      State.Frame.Colors := Loaded.Colors;
      State.Interaction.Keys := Loaded.Keys;
      State.Config.Openers := Loaded.Openers;
      State.Config.Previewers := Loaded.Previewers;
      State.Config.Thumbnails := Loaded.Thumbnails;

      if not Problems.Is_Empty then
         Warn (State, Explore.Words.Configuration_Problem (State.Config.Words, Problems));
      end if;

      State.Config.Marks_File :=
        Unbounded.To_Unbounded_String
          (Explore.Settings.Bookmarks_Path (Context.Environment_Value ("XDG_STATE_HOME"), Home));
      State.Interaction.Bookmarks :=
        Explore.Settings.Storage.Read_Bookmarks (Unbounded.To_String (State.Config.Marks_File));
   end Configure;

   procedure Main_Loop (State : in out Session; Readers : in out Explore.Directory_Readers.Board) is
      Item  : Explore.Input.Event;
      Found : Boolean;
      Ended : Boolean;
      Ok    : Boolean;
   begin
      Model.Open (State.Browser, Unbounded.To_String (State.Config.Directory));
      Explore.Tabs.Start (State.Tabs, State.Browser);

      while not State.Quit loop
         Explore.Application.Terminals.Watch_Signals (State, Ended);
         exit when Ended;

         Explore.Application.Workers.Watch_Files (State);
         Explore.Application.Workers.Collect (State, Readers);
         Explore.Application.Workers.Watch_Jobs (State);
         Explore.Application.Workers.Watch_Search (State);
         Explore.Application.Workers.Watch_Preview (State);
         Explore.Application.Workers.Sync (State, Readers);

         if State.Dirty then
            Explore.Application.Display.Draw (State, Ok);

            if not Ok then
               State.Terminal_Lost := True;
               return;
            end if;
         end if;

         Explore.Application.Terminals.Read_Into_Decoder
           (State,
            (if Explore.Application.Workers.Busy (State, Readers) then Busy_Poll_Ms else Idle_Poll_Ms),
            Ended);
         exit when Ended;

         loop
            Explore.Input.Next (State.Terminal.Decoder, Item, Found);
            exit when not Found;
            Explore.Application.Controller.Handle (State, Item);
         end loop;
      end loop;
   end Main_Loop;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      State   : Session;
      Given   : Explore.Application.Options.Option_Set;
      Ok      : Boolean;
      Outcome : Session_Outcome;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Result.Status := Posix_Tools.Exit_Status.Success;
      Explore.Application.Options.Parse (Context, Result, Given, Ok);

      if not Ok then
         return;
      end if;

      State.Config.Cwd_File := Given.Cwd_File;
      State.Config.Chooser_File := Given.Chooser_File;

      declare
         Path : constant String :=
           (if Unbounded.Length (Given.Directory) > 0 then Unbounded.To_String (Given.Directory)
            else Context.Physical_Current_Directory);
      begin
         if FS.Kind (Path) /= FS.Directory then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.explore.diagnostic.not_a_directory", "not a directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         State.Config.Directory := Unbounded.To_Unbounded_String (FS.Real_Path (Path));
      end;

      if not Context.Standard_Input_Is_Terminal or else not Context.Standard_Output_Is_Terminal then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context,
            "posix_tools.explore.diagnostic.not_a_terminal",
            "standard input and standard output must be a terminal");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Configure (State, Context, Unbounded.To_String (Given.Config_Path));

      if not Terminal_IO.Size (State.Terminal.Size) then
         State.Terminal.Size := (Rows => 24, Columns => 80);
      end if;

      Run_Session (State, Outcome);

      case Outcome is
         when Session_Ended =>
            --  The directory last shown, for a shell to change to.
            if Unbounded.Length (State.Config.Cwd_File) > 0 then
               FS.Write_File
                 (Unbounded.To_String (State.Config.Cwd_File),
                  Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path), False, Ok);

               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Unbounded.To_String (State.Config.Cwd_File),
                     "posix_tools.explore.diagnostic.cwd_file", "cannot write the directory");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               end if;
            end if;
         when Session_Signalled =>
            --  Reported the way a shell reports a program the signal ended.
            Result.Status :=
              Posix_Tools.Exit_Status.Code (128 + Posix_Tools.Host_Adapters.Signals.Number (State.Ended_By));
         when Raw_Mode_Refused =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.explore.diagnostic.raw_mode_refused", "cannot put the terminal into raw mode");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         when Terminal_Unsupported =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.explore.diagnostic.unsupported_terminal",
               "this terminal did not identify itself as bracke-terminal, the only one explore runs in");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         when Output_Failed =>
            Context.Mark_Output_Failure;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end case;
   end Run;

   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome) is
      package Terminals renames Explore.Application.Terminals;

      Saved_Signals : Terminals.Session_Dispositions;
      Entered       : Boolean := False;
   begin
      Terminals.Take_Signals (Saved_Signals);

      if not Terminal_IO.Enter_Raw (State.Terminal.Saved_Mode) then
         Terminals.Give_Back_Signals (Saved_Signals);
         Outcome := Raw_Mode_Refused;
         return;
      end if;

      if not Terminals.Identify (State) then
         Terminals.Hand_Back (State, Entered => False, Saved => Saved_Signals);
         Outcome := Terminal_Unsupported;
         return;
      end if;

      Entered := True;

      if not Terminals.Enter_Screen then
         Terminals.Hand_Back (State, Entered => True, Saved => Saved_Signals);
         Outcome := Output_Failed;
         return;
      end if;

      declare
         Readers    : aliased Explore.Directory_Readers.Board;
         Workers    : array (1 .. Explore.Directory_Readers.Worker_Count) of Explore.Directory_Readers.Worker
           (Readers'Access);
         Operations : aliased Explore.Jobs.Board;
         Operators  : array (Explore.Jobs.Lane_Index) of Explore.Jobs.Worker (Operations'Access);
         Previewer  : aliased Explore.Previews.Board;
         Builder    : Explore.Previews.Worker (Previewer'Access);
         Searcher   : aliased Explore.Search.Board;
         Finder     : Explore.Search.Worker (Searcher'Access);
         pragma Unreferenced (Workers, Operators, Builder, Finder);

         procedure Stop_Workers;

         --  The workers must end before this block can be left. A file
         --  operation still running is stopped where it is.
         procedure Stop_Workers is
         begin
            Operations.Shut_Down;
            Previewer.Shut_Down;
            Searcher.Shut_Down;
            Readers.Shut_Down;
            Explore.Application.Workers.Release_Watches (State);
            State.Workers.Operations := null;
            State.Workers.Previewer := null;
            State.Workers.Searcher := null;
         end Stop_Workers;
      begin
         --  The session outlives neither board: Stop_Workers forgets it.
         State.Workers.Operations := Operations'Unchecked_Access;
         State.Workers.Previewer := Previewer'Unchecked_Access;
         State.Workers.Searcher := Searcher'Unchecked_Access;
         Explore.Application.Display.Resize (State, State.Terminal.Size.Rows, State.Terminal.Size.Columns);

         begin
            Main_Loop (State, Readers);
         exception
            when others =>
               Stop_Workers;
               raise;
         end;

         Stop_Workers;
      end;

      Terminals.Hand_Back (State, Entered, Saved_Signals);
      Outcome :=
        (if State.Signalled then Session_Signalled
         elsif State.Terminal_Lost then Output_Failed
         else Session_Ended);
   exception
      when others =>
         Terminals.Hand_Back (State, Entered, Saved_Signals);
         raise;
   end Run_Session;
end Explore.Application;
