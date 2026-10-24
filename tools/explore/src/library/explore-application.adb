with Ada.Containers.Ordered_Maps;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Explore.Input;
with Explore.Keymap;
with Explore.Model;
with Explore.Protocol;
with Explore.Render;
with Explore.Screen;
with Explore.Tasks;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.File_Watches;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Host_Adapters.Terminal_IO;
with Posix_Tools.Localization;

package body Explore.Application is

   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Signals renames Posix_Tools.Host_Adapters.Signals;
   package Terminal_IO renames Posix_Tools.Host_Adapters.Terminal_IO;
   package Unbounded renames Ada.Strings.Unbounded;
   package Input renames Explore.Input;
   package Keymap renames Explore.Keymap;
   package Model renames Explore.Model;

   use type Ada.Streams.Stream_Element_Offset;
   use type FS.File_Kind;
   use type Signals.Disposition;
   use type Explore.Input.Event_Kind;
   use type Explore.Input.Key_Kind;
   use type Explore.Input.Mouse_Action;
   use type Explore.Input.Mouse_Button;
   use type Explore.Input.Reply_Kind;
   use type Explore.Model.Pane_Kind;
   use type Terminal_IO.Read_Outcome;

   --  How long one read waits before the loop looks at signals, watches, and
   --  finished directory reads again. A lone ESC also waits this long for the
   --  rest of a sequence.
   Idle_Poll_Ms : constant := 100;

   --  The wait while directories are being read, so results show promptly.
   Busy_Poll_Ms : constant := 15;

   --  Rows the mouse wheel moves the cursor.
   Wheel_Step : constant := 3;

   --  How long the terminal has to answer the identity query.
   Handshake_Reads   : constant := 10;
   Handshake_Read_Ms : constant := 50;

   --  The signals a session takes over: the two that end it, and the resize
   --  notice for terminals that do not report sizes in band.
   type Watched_Signal is (Watch_Terminate, Watch_Hangup, Watch_Window_Change);

   Signal_Of : constant array (Watched_Signal) of Signals.Signal :=
     [Watch_Terminate     => Signals.Terminate_Signal,
      Watch_Hangup        => Signals.Hangup,
      Watch_Window_Change => Signals.Window_Change];

   Ending_Signals : constant array (Positive range <>) of Signals.Signal :=
     [Signals.Terminate_Signal, Signals.Hangup];

   type Saved_Dispositions is array (Watched_Signal) of Signals.Disposition;

   package Name_Maps is new Ada.Containers.Ordered_Maps (Natural, Unbounded.Unbounded_String, "<", Unbounded."=");

   --  The panes whose directories are watched for changes.
   type Watched_Pane is (Watch_Parent, Watch_Current);

   Pane_Of : constant array (Watched_Pane) of Model.Pane_Kind :=
     [Watch_Parent => Model.Parent_Pane, Watch_Current => Model.Current_Pane];

   type Watch_Array is array (Watched_Pane) of Posix_Tools.Host_Adapters.File_Watches.Watch;
   type Path_Array is array (Watched_Pane) of Unbounded.Unbounded_String;
   type Generation_Array is array (Model.Pane_Kind) of Natural;

   type Session is record
      Directory : Unbounded.Unbounded_String;
      Home      : Unbounded.Unbounded_String;
      In_Tmux   : Boolean := False;
      Size      : Terminal_IO.Window_Size;
      Decoder   : Input.Decoder;
      Identity  : Explore.Protocol.Identity;
      Quit      : Boolean := False;
      --  The signal that ended the session, when one did.
      Ended_By  : Signals.Signal := Signals.Terminate_Signal;
      Signalled : Boolean := False;

      Browser   : Model.Browser;
      Keys      : Keymap.State;
      Frame     : Explore.Render.Frame_Context;
      --  What the terminal shows, and what the next frame should show.
      Shown     : Explore.Screen.Grid;
      Wanted    : Explore.Screen.Grid;
      Dirty     : Boolean := True;
      --  Repaint every cell, not only those that changed.
      Repaint   : Boolean := True;
      --  The generation last handed to the readers, per pane.
      Submitted : Generation_Array := [others => 0];
      Watches   : Watch_Array;
      Watching  : Path_Array;
      Users     : Name_Maps.Map;
      Groups    : Name_Maps.Map;
   end record;

   --  Interface text, looked up once: a catalog lookup reads the catalog.

   function Write (Text : String) return Boolean renames Terminal_IO.Write;

   --  Take the terminal over, run the session, and give it back. Outcome says
   --  what went wrong, if anything, for the caller to report once the screen
   --  is the user's again.
   type Session_Outcome is (Session_Ended, Session_Signalled, Raw_Mode_Refused, Terminal_Unsupported, Output_Failed);

   procedure Collect (State : in out Session; Jobs : in out Explore.Tasks.Board);

   procedure Draw (State : in out Session; Ok : out Boolean);

   procedure Edit_Filter (State : in out Session; Item : Input.Event);

   procedure Give_Back_Signals (Saved : Saved_Dispositions);

   procedure Handle (State : in out Session; Item : Input.Event);

   procedure Handle_Mouse (State : in out Session; Item : Input.Event);

   function Identify (State : in out Session) return Boolean;

   function Load_Labels (Locale : String) return Explore.Render.Labels;

   procedure Main_Loop (State : in out Session; Jobs : in out Explore.Tasks.Board);

   function Name_For (Names : in out Name_Maps.Map; Id : Natural; Group : Boolean) return String;

   procedure Perform (State : in out Session; Item : Keymap.Command);

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean);

   procedure Release_Watches (State : in out Session);

   procedure Resize (State : in out Session; Rows, Columns : Natural);

   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome);

   procedure Sync (State : in out Session; Jobs : in out Explore.Tasks.Board);

   procedure Take_Signals (Saved : out Saved_Dispositions);

   procedure Collect (State : in out Session; Jobs : in out Explore.Tasks.Board) is
      Outcome : Explore.Tasks.Result;
      Found   : Boolean;
   begin
      for Kind in Model.Pane_Kind loop
         Jobs.Collect (Kind, Outcome, Found);

         if Found then
            Model.Deliver (State.Browser, Kind, Outcome.Generation, Outcome.Entries, Outcome.Readable);
            State.Dirty := True;
         end if;
      end loop;
   end Collect;

   procedure Draw (State : in out Session; Ok : out Boolean) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      State.Frame.Prefix := Unbounded.To_Unbounded_String (Keymap.Pending (State.Keys));
      State.Frame.Owner := Unbounded.Null_Unbounded_String;

      if Model.Has_Selection (Current) and then Model.Selected (Current).Status.Available then
         declare
            Status : constant FS.Entry_Status := Model.Selected (Current).Status;
         begin
            State.Frame.Owner :=
              Unbounded.To_Unbounded_String
                (Name_For (State.Users, Status.User, Group => False) & ":"
                 & Name_For (State.Groups, Status.Group, Group => True));
         end;
      end if;

      Explore.Render.Draw (State.Wanted, State.Browser, State.Frame);
      Ok := Write
        (Explore.Protocol.Begin_Frame
         & Explore.Screen.Render (State.Shown, State.Wanted, Full => State.Repaint)
         & Explore.Protocol.End_Frame);
      State.Dirty := False;
      State.Repaint := False;
   end Draw;

   procedure Edit_Filter (State : in out Session; Item : Input.Event) is
      Filter : Unbounded.Unbounded_String renames State.Browser.Filter;
   begin
      case Item.Kind is
         when Input.Key_Event =>
            case Item.Key is
               when Input.Enter =>
                  State.Frame.Editing := False;
               when Input.Escape =>
                  State.Frame.Editing := False;
                  Filter := Unbounded.Null_Unbounded_String;
               when Input.Backspace =>
                  --  Drop the last character, all of its bytes.
                  while Unbounded.Length (Filter) > 0 loop
                     declare
                        Last : constant Character := Unbounded.Element (Filter, Unbounded.Length (Filter));
                     begin
                        Unbounded.Delete (Filter, Unbounded.Length (Filter), Unbounded.Length (Filter));
                        exit when Character'Pos (Last) not in 16#80# .. 16#BF#;
                     end;
                  end loop;
               when Input.Character_Key =>
                  if not Item.Mods.Control and then not Item.Mods.Alt then
                     Unbounded.Append
                       (Filter, Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ([1 => Item.Code]));
                  end if;
               when others =>
                  null;
            end case;
         when Input.Paste_Event =>
            Unbounded.Append (Filter, Item.Text);
         when others =>
            return;
      end case;

      Model.Apply_Filter (State.Browser);
      State.Dirty := True;
   end Edit_Filter;

   procedure Give_Back_Signals (Saved : Saved_Dispositions) is
   begin
      for Item in Watched_Signal loop
         if Saved (Item) /= Signals.Unknown_Disposition then
            declare
               --  A disposition that cannot be put back leaves the recording
               --  one, which is harmless once the session is over.
               Restored : constant Boolean := Signals.Set_Disposition (Signal_Of (Item), Saved (Item));
               pragma Unreferenced (Restored);
            begin
               null;
            end;
         end if;
      end loop;
   end Give_Back_Signals;

   procedure Handle (State : in out Session; Item : Input.Event) is
      Command : Keymap.Command;
   begin
      case Item.Kind is
         when Input.Key_Event | Input.Paste_Event =>
            if State.Frame.Editing then
               Edit_Filter (State, Item);
            elsif Item.Kind = Input.Key_Event then
               Keymap.Translate (State.Keys, Item, Command);
               Perform (State, Command);
               State.Dirty := True;
            end if;
         when Input.Mouse_Event =>
            Handle_Mouse (State, Item);
         when Input.Resize_Event =>
            if Item.Rows > 0 and then Item.Columns > 0 then
               Resize (State, Item.Rows, Item.Columns);
            end if;
         when Input.Focus_Event =>
            --  Whatever happened to the screen meanwhile, put it right.
            if Item.Focused then
               State.Repaint := True;
               State.Dirty := True;
            end if;
         when Input.Reply_Event =>
            null;
      end case;
   end Handle;

   procedure Handle_Mouse (State : in out Session; Item : Input.Event) is
      Shape : constant Explore.Render.Layout :=
        Explore.Render.Layout_For (State.Size.Rows, State.Size.Columns);
   begin
      case Item.Button is
         when Input.Wheel_Up =>
            Model.Move (State.Browser, -Wheel_Step);
         when Input.Wheel_Down =>
            Model.Move (State.Browser, Wheel_Step);
         when Input.Left_Button =>
            if Item.Action /= Input.Press or else Item.Row < Shape.First_Row
              or else Item.Row >= Shape.First_Row + Shape.Height
            then
               return;
            end if;

            for Kind in Model.Pane_Kind loop
               declare
                  Place : constant Explore.Render.Pane_Place := Shape.Places (Kind);
               begin
                  if Place.Shown and then Item.Column in Place.Column .. Place.Column + Place.Width - 1 then
                     case Kind is
                        when Model.Current_Pane =>
                           Model.Move_To
                             (State.Browser,
                              State.Browser.Panes (Model.Current_Pane).Top + Item.Row - Shape.First_Row);
                        when Model.Parent_Pane =>
                           Model.Leave (State.Browser);
                        when Model.Preview_Pane =>
                           Model.Enter (State.Browser);
                     end case;
                  end if;
               end;
            end loop;
         when Input.Middle_Button | Input.Right_Button | Input.No_Button =>
            return;
      end case;

      State.Dirty := True;
   end Handle_Mouse;

   --  Ask the terminal who it is. True when it answered the private identity
   --  query before its device attributes, which every terminal answers.
   function Identify (State : in out Session) return Boolean is
      Item       : Explore.Input.Event;
      Found      : Boolean;
      Ended      : Boolean;
      Identified : Boolean := False;
   begin
      if not Write (Explore.Protocol.Identity_Query (State.In_Tmux)) then
         return False;
      end if;

      for Attempt in 1 .. Handshake_Reads loop
         Read_Into_Decoder (State, Handshake_Read_Ms, Ended);

         if Ended then
            return False;
         end if;

         loop
            Explore.Input.Next (State.Decoder, Item, Found);
            exit when not Found;

            if Item.Kind = Explore.Input.Reply_Event then
               case Item.Reply is
                  when Explore.Input.Identity_Reply =>
                     Explore.Protocol.Parse_Identity
                       (Unbounded.To_String (Item.Payload), State.Identity, Identified);
                  when Explore.Input.Device_Attributes_Reply =>
                     return Identified;
                  when Explore.Input.Version_Reply =>
                     null;
               end case;
            end if;
         end loop;
      end loop;

      return Identified;
   end Identify;

   function Load_Labels (Locale : String) return Explore.Render.Labels is
      function Label (Key, Default : String) return Unbounded.Unbounded_String is
        (Unbounded.To_Unbounded_String
           (Posix_Tools.Localization.Text (Locale, "posix_tools.explore.ui." & Key, Default)));
   begin
      return
        (Quit_Hint  => Label ("quit_hint", "q quit"),
         Loading    => Label ("loading", "loading"),
         Unreadable => Label ("unreadable", "cannot read this directory"),
         Empty      => Label ("empty", "empty"),
         Filter     => Label ("filter", "filter"));
   end Load_Labels;

   procedure Main_Loop (State : in out Session; Jobs : in out Explore.Tasks.Board) is
      Item  : Input.Event;
      Found : Boolean;
      Ended : Boolean;
      Ok    : Boolean;
   begin
      Model.Open (State.Browser, Unbounded.To_String (State.Directory));

      while not State.Quit loop
         for Ending of Ending_Signals loop
            if Signals.Take (Ending) then
               State.Ended_By := Ending;
               State.Signalled := True;
               return;
            end if;
         end loop;

         if Signals.Take (Signals.Window_Change) then
            declare
               Measured : Terminal_IO.Window_Size;
            begin
               if Terminal_IO.Size (Measured) then
                  Resize (State, Measured.Rows, Measured.Columns);
               end if;
            end;
         end if;

         for Watched in Watched_Pane loop
            if Posix_Tools.Host_Adapters.File_Watches.Changed (State.Watches (Watched)) then
               Model.Reload (State.Browser, Pane_Of (Watched));
            end if;
         end loop;

         Collect (State, Jobs);
         Sync (State, Jobs);

         if State.Dirty then
            Draw (State, Ok);

            if not Ok then
               return;
            end if;
         end if;

         Read_Into_Decoder (State, (if Jobs.Busy then Busy_Poll_Ms else Idle_Poll_Ms), Ended);
         exit when Ended;

         loop
            Input.Next (State.Decoder, Item, Found);
            exit when not Found;
            Handle (State, Item);
         end loop;
      end loop;
   end Main_Loop;

   function Name_For (Names : in out Name_Maps.Map; Id : Natural; Group : Boolean) return String is
      Position : constant Name_Maps.Cursor := Names.Find (Id);
   begin
      if Name_Maps.Has_Element (Position) then
         return Unbounded.To_String (Name_Maps.Element (Position));
      end if;

      declare
         Found : constant String := (if Group then FS.Group_Name_For_Id (Id) else FS.User_Name_For_Id (Id));
         Image : constant String := Natural'Image (Id);
         Name  : constant String := (if Found'Length > 0 then Found else Image (Image'First + 1 .. Image'Last));
      begin
         Names.Insert (Id, Unbounded.To_Unbounded_String (Name));
         return Name;
      end;
   end Name_For;

   procedure Perform (State : in out Session; Item : Keymap.Command) is
      Height  : constant Positive :=
        Positive'Max (1, Explore.Render.Layout_For (State.Size.Rows, State.Size.Columns).Height);
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      case Item.Kind is
         when Keymap.No_Action =>
            null;
         when Keymap.Quit =>
            State.Quit := True;
         when Keymap.Move_Up =>
            Model.Move (State.Browser, -1);
         when Keymap.Move_Down =>
            Model.Move (State.Browser, 1);
         when Keymap.Move_Top =>
            Model.Move_To (State.Browser, 1);
         when Keymap.Move_Bottom =>
            Model.Move_To (State.Browser, Model.Shown_Count (Current));
         when Keymap.Half_Page_Up =>
            Model.Move (State.Browser, -Positive'Max (1, Height / 2));
         when Keymap.Half_Page_Down =>
            Model.Move (State.Browser, Positive'Max (1, Height / 2));
         when Keymap.Page_Up =>
            Model.Move (State.Browser, -Height);
         when Keymap.Page_Down =>
            Model.Move (State.Browser, Height);
         when Keymap.Enter_Directory =>
            Model.Enter (State.Browser);
         when Keymap.Leave_Directory =>
            Model.Leave (State.Browser);
         when Keymap.Toggle_Hidden =>
            State.Browser.Show_Hidden := not State.Browser.Show_Hidden;
            Model.Reload_All (State.Browser);
         when Keymap.Start_Filter =>
            State.Frame.Editing := True;
         when Keymap.Clear_Filter =>
            State.Browser.Filter := Unbounded.Null_Unbounded_String;
            Model.Apply_Filter (State.Browser);
         when Keymap.Sort_Entries =>
            State.Browser.Order.Key := Item.Key;
            State.Browser.Order.Descending := Item.Descending;
            Model.Reload_All (State.Browser);
         when Keymap.Go_Home =>
            if Unbounded.Length (State.Home) > 0
              and then FS.Kind (Unbounded.To_String (State.Home)) = FS.Directory
            then
               Model.Open (State.Browser, FS.Real_Path (Unbounded.To_String (State.Home)));
            end if;
      end case;
   end Perform;

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean) is
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Terminal_IO.Read_Outcome;
   begin
      Terminal_IO.Read (Buffer, Last, Timeout_Ms, Outcome);
      Ended := Outcome = Terminal_IO.Read_End_Of_File or else Outcome = Terminal_IO.Read_Failed;

      if Outcome = Terminal_IO.Read_Data then
         declare
            Text : String (1 .. Natural (Last));
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (Buffer (Ada.Streams.Stream_Element_Offset (I)));
            end loop;

            Explore.Input.Feed (State.Decoder, Text);
         end;
      elsif Outcome = Terminal_IO.Read_Timeout then
         Explore.Input.Flush (State.Decoder);
      end if;
   end Read_Into_Decoder;

   procedure Release_Watches (State : in out Session) is
   begin
      for Watched in Watched_Pane loop
         Posix_Tools.Host_Adapters.File_Watches.Release (State.Watches (Watched));
         State.Watching (Watched) := Unbounded.Null_Unbounded_String;
      end loop;
   end Release_Watches;

   procedure Resize (State : in out Session; Rows, Columns : Natural) is
   begin
      State.Size := (Rows => Rows, Columns => Columns);
      Explore.Screen.Resize (State.Wanted, Rows, Columns);
      State.Repaint := True;
      State.Dirty := True;
   end Resize;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      State     : Session;
      Directory : Unbounded.Unbounded_String;
      Outcome   : Session_Outcome;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Result.Status := Posix_Tools.Exit_Status.Success;

      for I in 1 .. Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (I);
         begin
            if Argument'Length > 1 and then Argument (Argument'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Argument & "'");
               return;
            elsif Unbounded.Length (Directory) > 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Argument & "'");
               return;
            end if;

            Directory := Unbounded.To_Unbounded_String (Argument);
         end;
      end loop;

      if Unbounded.Length (Directory) = 0 then
         Directory := Unbounded.To_Unbounded_String (Context.Physical_Current_Directory);
      end if;

      declare
         Path : constant String := Unbounded.To_String (Directory);
      begin
         if FS.Kind (Path) /= FS.Directory then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.explore.diagnostic.not_a_directory", "not a directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         State.Directory := Unbounded.To_Unbounded_String (FS.Real_Path (Path));
      end;

      if not Context.Standard_Input_Is_Terminal or else not Context.Standard_Output_Is_Terminal then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context,
            "posix_tools.explore.diagnostic.not_a_terminal",
            "standard input and standard output must be a terminal");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      State.In_Tmux := Context.Environment_Defined ("TMUX");
      State.Frame.Text := Load_Labels (Context.Effective_Locale);
      State.Home := Unbounded.To_Unbounded_String (Context.Environment_Value ("HOME"));

      if not Terminal_IO.Size (State.Size) then
         State.Size := (Rows => 24, Columns => 80);
      end if;

      Run_Session (State, Outcome);

      case Outcome is
         when Session_Ended =>
            null;
         when Session_Signalled =>
            --  Reported the way a shell reports a program the signal ended.
            Result.Status := Posix_Tools.Exit_Status.Code (128 + Signals.Number (State.Ended_By));
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
      Saved_Mode    : Terminal_IO.Saved_Mode;
      Saved_Signals : Saved_Dispositions;
      Entered       : Boolean := False;

      procedure Hand_Back;

      procedure Hand_Back is
      begin
         if Entered then
            declare
               --  A terminal that no longer takes output can still have its
               --  settings restored.
               Written : constant Boolean := Write (Explore.Protocol.Leave_Screen);
               pragma Unreferenced (Written);
            begin
               null;
            end;
         end if;

         Terminal_IO.Restore (Saved_Mode);
         Give_Back_Signals (Saved_Signals);
      end Hand_Back;
   begin
      Take_Signals (Saved_Signals);

      if not Terminal_IO.Enter_Raw (Saved_Mode) then
         Give_Back_Signals (Saved_Signals);
         Outcome := Raw_Mode_Refused;
         return;
      end if;

      if not Identify (State) then
         Hand_Back;
         Outcome := Terminal_Unsupported;
         return;
      end if;

      Entered := True;

      if not Write (Explore.Protocol.Enter_Screen) then
         Hand_Back;
         Outcome := Output_Failed;
         return;
      end if;

      declare
         Jobs    : aliased Explore.Tasks.Board;
         Workers : array (1 .. Explore.Tasks.Worker_Count) of Explore.Tasks.Worker (Jobs'Access);
         pragma Unreferenced (Workers);
      begin
         Resize (State, State.Size.Rows, State.Size.Columns);

         begin
            Main_Loop (State, Jobs);
         exception
            when others =>
               --  The readers must end before this block can be left.
               Jobs.Shut_Down;
               Release_Watches (State);
               raise;
         end;

         Jobs.Shut_Down;
         Release_Watches (State);
      end;

      Hand_Back;
      Outcome := (if State.Signalled then Session_Signalled else Session_Ended);
   exception
      when others =>
         Hand_Back;
         raise;
   end Run_Session;

   --  Bring the readers and the watches in line with the panes: point the
   --  preview at the selection, ask for each pane's entries that are wanted
   --  and not yet asked for, and watch the directories on screen.
   procedure Sync (State : in out Session; Jobs : in out Explore.Tasks.Board) is
      use type Unbounded.Unbounded_String;
   begin
      if Model.Preview_Changed (State.Browser) then
         State.Dirty := True;
      end if;

      for Kind in Model.Pane_Kind loop
         declare
            Item : Model.Pane renames State.Browser.Panes (Kind);
         begin
            if Item.Pending and then Item.Generation /= State.Submitted (Kind) then
               Jobs.Submit
                 (Kind,
                  (Path       => Item.Path,
                   Generation => Item.Generation,
                   Options    => (Include_Hidden => State.Browser.Show_Hidden, With_Status => True),
                   Order      => State.Browser.Order));
               State.Submitted (Kind) := Item.Generation;
            end if;
         end;
      end loop;

      for Watched in Watched_Pane loop
         declare
            Path : constant Unbounded.Unbounded_String := State.Browser.Panes (Pane_Of (Watched)).Path;
         begin
            if Path /= State.Watching (Watched) then
               Posix_Tools.Host_Adapters.File_Watches.Release (State.Watches (Watched));
               State.Watching (Watched) := Path;

               if Unbounded.Length (Path) > 0 then
                  Posix_Tools.Host_Adapters.File_Watches.Watch_Path
                    (State.Watches (Watched), Unbounded.To_String (Path));
               end if;
            end if;
         end;
      end loop;
   end Sync;

   procedure Take_Signals (Saved : out Saved_Dispositions) is
   begin
      for Item in Watched_Signal loop
         if not Signals.Current_Disposition (Signal_Of (Item), Saved (Item)) then
            Saved (Item) := Signals.Unknown_Disposition;
         end if;

         --  A terminate or hangup the session was started ignoring stays
         --  ignored, as nohup intends.
         if Saved (Item) /= Signals.Ignore_Disposition
           and then Signals.Can_Record (Signal_Of (Item))
           and then Signals.Set_Disposition (Signal_Of (Item), Signals.Record_Disposition)
         then
            declare
               --  An arrival recorded by an earlier session is not this one's.
               Stale : constant Boolean := Signals.Take (Signal_Of (Item));
               pragma Unreferenced (Stale);
            begin
               null;
            end;
         end if;
      end loop;
   end Take_Signals;

end Explore.Application;
