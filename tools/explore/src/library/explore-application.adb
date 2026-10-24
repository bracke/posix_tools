with Ada.Containers.Ordered_Maps;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Explore.Images;
with Explore.Input;
with Explore.Jobs;
with Explore.Keymap;
with Explore.Model;
with Explore.Previews;
with Explore.Protocol;
with Explore.Render;
with Explore.Screen;
with Explore.Tasks;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.File_Watches;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Host_Adapters.Terminal_IO;
with Posix_Tools.Localization;
with Posix_Tools.Text.File_Modes;

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
   use type Explore.Jobs.Snapshot;
   use type Explore.Keymap.Action;
   use type Explore.Previews.Preview_Kind;
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

   type Board_Access is access all Explore.Jobs.Board;
   type Preview_Board_Access is access all Explore.Previews.Board;

   --  What the next key means, beyond browsing.
   type Interaction is
     (Browsing,
      Renaming,          --  Typing a new name for the selected entry.
      Creating,          --  Typing the name of a file, or of a directory with a slash.
      Changing_Mode,     --  Typing permissions, octal or symbolic.
      Confirming_Delete, --  y deletes the entries in Pending, anything else does not.
      Answering,         --  A running job asks about a target that exists.
      Viewing_Jobs);     --  The jobs panel is open.

   --  Interface text for operations, looked up once.
   type Operation_Labels is record
      Rename_Prompt : Unbounded.Unbounded_String;
      Create_Prompt : Unbounded.Unbounded_String;
      Mode_Prompt   : Unbounded.Unbounded_String;
      Copying       : Unbounded.Unbounded_String;
      Moving        : Unbounded.Unbounded_String;
      Linking       : Unbounded.Unbounded_String;
      Deleting      : Unbounded.Unbounded_String;
      Yanked        : Unbounded.Unbounded_String;
      Cut           : Unbounded.Unbounded_String;
      Queue_Full    : Unbounded.Unbounded_String;
      Cancelled     : Unbounded.Unbounded_String;
      Exists        : Unbounded.Unbounded_String;
      Invalid_Mode  : Unbounded.Unbounded_String;
      Errors        : Unbounded.Unbounded_String;
      Copied        : Unbounded.Unbounded_String;
      Moved         : Unbounded.Unbounded_String;
      Linked        : Unbounded.Unbounded_String;
      Deleted       : Unbounded.Unbounded_String;
      Queued        : Unbounded.Unbounded_String;
      No_Jobs       : Unbounded.Unbounded_String;
      Jobs_Title    : Unbounded.Unbounded_String;
   end record;

   --  The images the terminal holds, kept so that showing one again needs no
   --  second transfer. An empty slot has Id zero.
   Image_Cache_Slots : constant := 8;
   Image_Cache_Bytes : constant := 32 * 1024 * 1024;

   type Cached_Image is record
      Path     : Unbounded.Unbounded_String;
      Modified : Long_Long_Integer := 0;
      Size     : Long_Long_Integer := 0;
      Id       : Natural range 0 .. 255 := 0;
      Columns  : Natural := 0;
      Rows     : Natural := 0;
      Bytes    : Natural := 0;
      --  When it was last shown, for evicting the least recently used.
      Used     : Natural := 0;
   end record;

   type Image_Cache is array (1 .. Image_Cache_Slots) of Cached_Image;

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

      Locale    : Unbounded.Unbounded_String;
      Words     : Operation_Labels;
      Operations : Board_Access;
      Last_Job  : Explore.Jobs.Snapshot;
      Mode      : Interaction := Browsing;
      --  Yanked or cut entries, waiting to be pasted.
      Clipboard : Model.Path_Vectors.Vector;
      Cutting   : Boolean := False;
      --  The entries a delete waits to be confirmed for.
      Pending   : Model.Path_Vectors.Vector;

      Previewer  : Preview_Board_Access;
      --  The file whose preview was asked for, and for which generation.
      Previewing : Unbounded.Unbounded_String;
      Preview_Generation : Natural := 0;
      --  A cell's size in pixels, from the terminal's size reports.
      Cell_Width  : Positive := 8;
      Cell_Height : Positive := 16;
      Images      : Image_Cache;
      Image_Clock : Natural := 0;
   end record;

   function Write (Text : String) return Boolean renames Terminal_IO.Write;

   --  Take the terminal over, run the session, and give it back. Outcome says
   --  what went wrong, if anything, for the caller to report once the screen
   --  is the user's again.
   type Session_Outcome is (Session_Ended, Session_Signalled, Raw_Mode_Refused, Terminal_Unsupported, Output_Failed);

   function Image (Value : Natural) return String is (Natural'Image (Value) (2 .. Natural'Image (Value)'Last));

   function Verb_Of (State : Session; Kind : Explore.Jobs.Job_Kind) return String is
     (Unbounded.To_String
        (case Kind is
           when Explore.Jobs.Copy_Job => State.Words.Copying,
           when Explore.Jobs.Move_Job => State.Words.Moving,
           when Explore.Jobs.Link_Job => State.Words.Linking,
           when Explore.Jobs.Delete_Job => State.Words.Deleting));

   procedure Collect (State : in out Session; Jobs : in out Explore.Tasks.Board);

   --  Carry out what was typed for Renaming, Creating, or Changing_Mode.
   procedure Commit (State : in out Session);

   --  Show Error about Path in the status line.
   procedure Complain (State : in out Session; Path : String; Error : Posix_Tools.File_Operations.Operation_Error);

   procedure Draw (State : in out Session; Ok : out Boolean);

   procedure Edit_Filter (State : in out Session; Item : Input.Event);

   --  Edit Text with Item: typing, Backspace, and paste. Done when Enter was
   --  pressed, Abandoned when Escape was.
   procedure Edit_Line
     (Text      : in out Unbounded.Unbounded_String;
      Item      : Input.Event;
      Done      : out Boolean;
      Abandoned : out Boolean);

   --  Fill the jobs panel's lines from the board, keeping its cursor in them.
   procedure Fill_Panel (State : in out Session);

   procedure Give_Back_Signals (Saved : Saved_Dispositions);

   procedure Handle (State : in out Session; Item : Input.Event);

   procedure Handle_Mouse (State : in out Session; Item : Input.Event);

   --  Stop showing the preview's image; the terminal keeps it for later.
   procedure Hide_Image (State : in out Session);

   function Identify (State : in out Session) return Boolean;

   --  The progress line of a running job.
   function Lane_Line (State : Session; Lane : Explore.Jobs.Lane_View) return String;

   --  Interface text, looked up once: a catalog lookup reads the catalog.
   function Load_Labels (Locale : String) return Explore.Render.Labels;

   function Load_Words (Locale : String) return Operation_Labels;

   procedure Main_Loop (State : in out Session; Jobs : in out Explore.Tasks.Board);

   function Name_For (Names : in out Name_Maps.Map; Id : Natural; Group : Boolean) return String;

   procedure Perform (State : in out Session; Item : Keymap.Command);

   --  Queue a job; say so in the status line when the queue is full.
   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job);

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean);

   procedure Release_Watches (State : in out Session);

   procedure Resize (State : in out Session; Rows, Columns : Natural);

   --  What became of an ended job, as one line.
   function Result_Line (State : Session; Item : Explore.Jobs.Result_View) return String;

   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome);

   --  Send the preview's image to the terminal, placed to fit the pane, in
   --  place of any image sent before.
   procedure Show_Image (State : in out Session);

   procedure Sync (State : in out Session; Jobs : in out Explore.Tasks.Board);

   procedure Take_Signals (Saved : out Saved_Dispositions);

   --  Follow the jobs: their progress line, their questions, and what they
   --  changed.
   procedure Watch_Jobs (State : in out Session);

   --  Point the preview at the selected file, and take a preview that is
   --  ready.
   procedure Watch_Preview (State : in out Session);

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

   procedure Commit (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Text    : constant String := Unbounded.To_String (State.Frame.Prompt_Text);
      Folder  : constant String := Unbounded.To_String (Current.Path);
   begin
      if Text'Length = 0 then
         return;
      end if;

      case State.Mode is
         when Renaming | Creating =>
            declare
               Directory : constant Boolean := State.Mode = Creating and then Text (Text'Last) = '/';
               Name      : constant String := (if Directory then Text (Text'First .. Text'Last - 1) else Text);
               Target    : constant String := Model.Child_Of (Folder, Name);
               Written   : Boolean := True;
            begin
               if Name'Length = 0 or else Name = "." or else Name = ".."
                 or else (for some C of Name => C = '/')
               then
                  Complain (State, Text, Posix_Tools.File_Operations.Cannot_Open);
                  return;
               elsif FS.Exists (Target) or else FS.Is_Link (Target) then
                  State.Frame.Message :=
                    Unbounded.To_Unbounded_String (Name & ": " & Unbounded.To_String (State.Words.Exists));
                  State.Frame.Message_Is_Error := True;
                  return;
               end if;

               begin
                  if State.Mode = Renaming then
                     FS.Rename (Model.Selected_Path (Current), Target);
                  elsif Directory then
                     FS.Create_Path (Target);
                  else
                     FS.Write_File (Target, "", Append_Mode => True, Ok => Written);
                  end if;
               exception
                  when others =>
                     Written := False;
               end;

               if not Written then
                  Complain (State, Target, Posix_Tools.File_Operations.Cannot_Open);
                  return;
               end if;

               --  The cursor goes to what was made once the directory is read again.
               Model.Reload (State.Browser, Model.Current_Pane);
               Current.Wanted := Unbounded.To_Unbounded_String (Name);
            end;
         when Changing_Mode =>
            declare
               Parsed : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
                 Posix_Tools.Text.File_Modes.Parse_Permission_Mode (Text);
            begin
               for Path of Model.Targets (State.Browser) loop
                  declare
                     use type Posix_Tools.Text.File_Modes.Permission_Mode_Status;

                     Known   : Boolean;
                     Old     : constant Natural := FS.File_Permission_Bits (Path, Known) mod 8#10000#;
                     Applied : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
                       (if Parsed.Status = Posix_Tools.Text.File_Modes.Octal_Permission_Mode
                        then (Valid => True, Mode => Parsed.Mode)
                        else Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode (Text, Old));
                  begin
                     if not Applied.Valid then
                        State.Frame.Message :=
                          Unbounded.To_Unbounded_String (Text & ": " & Unbounded.To_String (State.Words.Invalid_Mode));
                        State.Frame.Message_Is_Error := True;
                        return;
                     elsif not FS.Set_Permissions (Path, Applied.Mode) then
                        Complain (State, Path, Posix_Tools.File_Operations.Cannot_Open);
                     end if;
                  end;
               end loop;

               Model.Clear_Marks (State.Browser);
               Model.Reload (State.Browser, Model.Current_Pane);
            end;
         when Browsing | Confirming_Delete | Answering | Viewing_Jobs =>
            null;
      end case;
   end Commit;

   procedure Complain (State : in out Session; Path : String; Error : Posix_Tools.File_Operations.Operation_Error) is
   begin
      State.Frame.Message :=
        Unbounded.To_Unbounded_String
          (Path & ": "
           & Posix_Tools.Localization.Text
               (Unbounded.To_String (State.Locale),
                Posix_Tools.File_Operations.Message_Key (Error),
                Posix_Tools.File_Operations.Default_Message (Error)));
      State.Frame.Message_Is_Error := True;
   end Complain;

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

   procedure Edit_Line
     (Text      : in out Unbounded.Unbounded_String;
      Item      : Input.Event;
      Done      : out Boolean;
      Abandoned : out Boolean)
   is
   begin
      Done := False;
      Abandoned := False;

      case Item.Kind is
         when Input.Key_Event =>
            case Item.Key is
               when Input.Enter =>
                  Done := True;
               when Input.Escape =>
                  Abandoned := True;
               when Input.Backspace =>
                  --  Drop the last character, all of its bytes.
                  while Unbounded.Length (Text) > 0 loop
                     declare
                        Last : constant Character := Unbounded.Element (Text, Unbounded.Length (Text));
                     begin
                        Unbounded.Delete (Text, Unbounded.Length (Text), Unbounded.Length (Text));
                        exit when Character'Pos (Last) not in 16#80# .. 16#BF#;
                     end;
                  end loop;
               when Input.Character_Key =>
                  if Item.Mods.Control and then Item.Code = 'c' then
                     Abandoned := True;
                  elsif not Item.Mods.Control and then not Item.Mods.Alt then
                     Unbounded.Append (Text, Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode ([1 => Item.Code]));
                  end if;
               when others =>
                  null;
            end case;
         when Input.Paste_Event =>
            Unbounded.Append (Text, Item.Text);
         when others =>
            null;
      end case;
   end Edit_Line;

   procedure Fill_Panel (State : in out Session) is
      Now : constant Explore.Jobs.Snapshot := State.Operations.Status;
   begin
      State.Frame.Panel_Lines.Clear;
      State.Frame.Panel_Ids.Clear;

      for Running of Now.Lanes loop
         if Running.Running then
            State.Frame.Panel_Lines.Append ("> " & Lane_Line (State, Running));
            State.Frame.Panel_Ids.Append (Running.Job.Id);
         end if;
      end loop;

      for Waiting of Now.Queued loop
         State.Frame.Panel_Lines.Append
           ("  " & Unbounded.To_String (State.Words.Queued) & ": " & Verb_Of (State, Waiting.Kind) & " "
            & Unbounded.To_String (Waiting.First)
            & (if Waiting.Total > 1 then " +" & Image (Waiting.Total - 1) else ""));
         State.Frame.Panel_Ids.Append (Waiting.Id);
      end loop;

      for I in reverse 1 .. Natural (Now.History.Length) loop
         State.Frame.Panel_Lines.Append ("  " & Result_Line (State, Now.History (I)));
         State.Frame.Panel_Ids.Append (0);
      end loop;

      if State.Frame.Panel_Lines.Is_Empty then
         State.Frame.Panel_Lines.Append ("  " & Unbounded.To_String (State.Words.No_Jobs));
         State.Frame.Panel_Ids.Append (0);
      end if;

      State.Frame.Panel_Cursor :=
        Natural'Max (1, Natural'Min (State.Frame.Panel_Cursor, Natural (State.Frame.Panel_Lines.Length)));
      State.Frame.Panel_Title := State.Words.Jobs_Title;
      State.Dirty := True;
   end Fill_Panel;

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
            State.Frame.Message := Unbounded.Null_Unbounded_String;
            State.Dirty := True;

            case State.Mode is
               when Browsing =>
                  if State.Frame.Editing then
                     Edit_Filter (State, Item);
                  elsif Item.Kind = Input.Key_Event then
                     Keymap.Translate (State.Keys, Item, Command);
                     Perform (State, Command);
                  end if;
               when Renaming | Creating | Changing_Mode =>
                  declare
                     Done, Abandoned : Boolean;
                  begin
                     Edit_Line (State.Frame.Prompt_Text, Item, Done, Abandoned);

                     if Done or else Abandoned then
                        if Done then
                           Commit (State);
                        end if;

                        State.Mode := Browsing;
                        State.Frame.Prompting := False;
                     end if;
                  end;
               when Confirming_Delete =>
                  if Input.Is_Character (Item, 'y') or else Input.Is_Character (Item, 'Y') then
                     Queue_Job (State, (Explore.Jobs.Delete_Job, State.Pending, others => <>));
                     Model.Clear_Marks (State.Browser);
                  end if;

                  State.Pending.Clear;
                  State.Frame.Question := Unbounded.Null_Unbounded_String;
                  State.Mode := Browsing;
               when Answering =>
                  if Item.Kind = Input.Key_Event then
                     if Input.Is_Character (Item, 'o') then
                        State.Operations.Answer (Explore.Jobs.Overwrite_One);
                     elsif Input.Is_Character (Item, 'O') then
                        State.Operations.Answer (Explore.Jobs.Overwrite_All);
                     elsif Input.Is_Character (Item, 's') or else Item.Key = Input.Escape then
                        State.Operations.Answer (Explore.Jobs.Skip_One);
                     elsif Input.Is_Character (Item, 'S') then
                        State.Operations.Answer (Explore.Jobs.Skip_All);
                     elsif Item.Mods.Control and then Item.Code = 'c' then
                        declare
                           Now  : constant Explore.Jobs.Snapshot := State.Operations.Status;
                           Lane : constant Natural := Explore.Jobs.Asking_Lane (Now);
                        begin
                           if Lane > 0 then
                              State.Operations.Cancel (Now.Lanes (Lane).Job.Id);
                           end if;
                        end;
                     end if;
                  end if;
               when Viewing_Jobs =>
                  if Item.Kind = Input.Key_Event then
                     declare
                        Rows : constant Natural := Natural (State.Frame.Panel_Ids.Length);
                     begin
                        if Input.Is_Character (Item, 'j') or else Item.Key = Input.Down then
                           State.Frame.Panel_Cursor := Natural'Min (Rows, State.Frame.Panel_Cursor + 1);
                        elsif Input.Is_Character (Item, 'k') or else Item.Key = Input.Up then
                           State.Frame.Panel_Cursor := Natural'Max (1, State.Frame.Panel_Cursor - 1);
                        elsif Input.Is_Character (Item, 'x')
                          or else (Item.Mods.Control and then Item.Code = 'c')
                        then
                           if State.Frame.Panel_Cursor in 1 .. Rows
                             and then State.Frame.Panel_Ids (State.Frame.Panel_Cursor) > 0
                           then
                              State.Operations.Cancel (State.Frame.Panel_Ids (State.Frame.Panel_Cursor));
                           end if;
                        elsif Input.Is_Character (Item, 'w') or else Input.Is_Character (Item, 'q')
                          or else Item.Key = Input.Escape
                        then
                           State.Mode := Browsing;
                           State.Frame.Panel_Open := False;
                        end if;
                     end;

                     Fill_Panel (State);
                  end if;
            end case;
         when Input.Mouse_Event =>
            Handle_Mouse (State, Item);
         when Input.Resize_Event =>
            if Item.Rows > 0 and then Item.Columns > 0 then
               if Item.Pixel_Width >= Item.Columns and then Item.Pixel_Height >= Item.Rows then
                  State.Cell_Width := Item.Pixel_Width / Item.Columns;
                  State.Cell_Height := Item.Pixel_Height / Item.Rows;
               end if;

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

   procedure Hide_Image (State : in out Session) is
   begin
      if State.Frame.Image_Id > 0 then
         State.Frame.Image_Id := 0;
         State.Dirty := True;
      end if;
   end Hide_Image;

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

   function Lane_Line (State : Session; Lane : Explore.Jobs.Lane_View) return String is
      Percent : constant String :=
        (if Lane.Size > 0
         then " " & Image (Natural (Long_Long_Integer'Min (100, Lane.Copied * 100 / Lane.Size))) & "%"
         else "");
   begin
      return Verb_Of (State, Lane.Job.Kind) & " " & Image (Natural'Min (Lane.Done + 1, Lane.Job.Total)) & "/"
        & Image (Lane.Job.Total) & " " & Model.Name_Of (Unbounded.To_String (Lane.Current)) & Percent;
   end Lane_Line;

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
         Filter     => Label ("filter", "filter"),
         Marked     => Label ("marked", "marked"));
   end Load_Labels;

   function Load_Words (Locale : String) return Operation_Labels is
      function Word (Key, Default : String) return Unbounded.Unbounded_String is
        (Unbounded.To_Unbounded_String
           (Posix_Tools.Localization.Text (Locale, "posix_tools.explore.ui." & Key, Default)));
   begin
      return
        (Rename_Prompt => Word ("prompt.rename", "rename to"),
         Create_Prompt => Word ("prompt.create", "create (end with / for a directory)"),
         Mode_Prompt   => Word ("prompt.mode", "permissions"),
         Copying       => Word ("job.copying", "copying"),
         Moving        => Word ("job.moving", "moving"),
         Linking       => Word ("job.linking", "linking"),
         Deleting      => Word ("job.deleting", "deleting"),
         Yanked        => Word ("yanked", "yanked"),
         Cut           => Word ("cut", "cut"),
         Queue_Full    => Word ("queue_full", "too many operations waiting"),
         Cancelled     => Word ("cancelled", "cancelled"),
         Exists        => Word ("exists", "already exists"),
         Invalid_Mode  => Word ("invalid_mode", "not a valid permission mode"),
         Errors        => Word ("errors", "errors"),
         Copied        => Word ("job.copied", "copied"),
         Moved         => Word ("job.moved", "moved"),
         Linked        => Word ("job.linked", "linked"),
         Deleted       => Word ("job.deleted", "deleted"),
         Queued        => Word ("job.queued", "waiting"),
         No_Jobs       => Word ("job.none", "no operations"),
         Jobs_Title    => Word ("job.title", "operations: j/k move, x cancel, w close"));
   end Load_Words;

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
         Watch_Jobs (State);
         Watch_Preview (State);
         Sync (State, Jobs);

         if State.Dirty then
            Draw (State, Ok);

            if not Ok then
               return;
            end if;
         end if;

         Read_Into_Decoder
           (State,
            (if Jobs.Busy or else Explore.Jobs.Any_Running (State.Last_Job) or else State.Previewer.Busy
             then Busy_Poll_Ms
             else Idle_Poll_Ms),
            Ended);
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
            Model.Clear_Marks (State.Browser);
         when Keymap.Toggle_Mark =>
            Model.Toggle_Mark (State.Browser);
            Model.Move (State.Browser, 1);
         when Keymap.Yank | Keymap.Cut =>
            State.Clipboard := Model.Targets (State.Browser);
            State.Cutting := Item.Kind = Keymap.Cut;
            Model.Clear_Marks (State.Browser);

            if not State.Clipboard.Is_Empty then
               State.Frame.Message :=
                 Unbounded.To_Unbounded_String
                   (Natural'Image (Natural (State.Clipboard.Length)) & " "
                    & Unbounded.To_String (if State.Cutting then State.Words.Cut else State.Words.Yanked));
            end if;
         when Keymap.Paste | Keymap.Paste_Links =>
            if not State.Clipboard.Is_Empty then
               Queue_Job
                 (State,
                  (Kind    =>
                     (if Item.Kind = Keymap.Paste_Links then Explore.Jobs.Link_Job
                      elsif State.Cutting then Explore.Jobs.Move_Job
                      else Explore.Jobs.Copy_Job),
                   Sources => State.Clipboard,
                   Target  => Current.Path,
                   Id      => 0));

               --  What was cut is gone from where it was once pasted.
               if State.Cutting and then Item.Kind = Keymap.Paste then
                  State.Clipboard.Clear;
                  State.Cutting := False;
               end if;
            end if;
         when Keymap.Delete_Entries =>
            State.Pending := Model.Targets (State.Browser);

            if not State.Pending.Is_Empty then
               declare
                  Count : constant String := Natural'Image (Natural (State.Pending.Length));
               begin
                  State.Frame.Question :=
                    Unbounded.To_Unbounded_String
                      (Posix_Tools.Localization.Text_1
                         (Unbounded.To_String (State.Locale),
                          "posix_tools.explore.ui.confirm_delete",
                          "count",
                          Count (Count'First + 1 .. Count'Last),
                          "delete " & Count (Count'First + 1 .. Count'Last) & "? y/n"));
               end;
               State.Mode := Confirming_Delete;
            end if;
         when Keymap.Rename_Entry | Keymap.Create_Entry | Keymap.Change_Mode =>
            if Item.Kind = Keymap.Create_Entry or else Model.Has_Selection (Current) then
               State.Mode :=
                 (case Item.Kind is
                    when Keymap.Rename_Entry => Renaming,
                    when Keymap.Create_Entry => Creating,
                    when others => Changing_Mode);
               State.Frame.Prompting := True;
               State.Frame.Prompt_Label :=
                 (case State.Mode is
                    when Renaming => State.Words.Rename_Prompt,
                    when Creating => State.Words.Create_Prompt,
                    when others => State.Words.Mode_Prompt);
               State.Frame.Prompt_Text :=
                 (case State.Mode is
                    when Renaming => Unbounded.To_Unbounded_String (Model.Selected_Name (Current)),
                    when Changing_Mode =>
                      Unbounded.To_Unbounded_String
                        (Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image
                           (Model.Selected (Current).Status.Mode mod 8#10000#)),
                    when others => Unbounded.Null_Unbounded_String);
            end if;
         when Keymap.Cancel_Job =>
            if Explore.Jobs.Any_Running (State.Last_Job) then
               State.Operations.Cancel_Running;
               State.Frame.Message := State.Words.Cancelled;
            end if;
         when Keymap.Show_Jobs =>
            State.Mode := Viewing_Jobs;
            State.Frame.Panel_Open := True;
            State.Frame.Panel_Cursor := 1;
            Fill_Panel (State);
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

   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job) is
      Accepted : Boolean;
   begin
      State.Operations.Submit (Item, Accepted);

      if not Accepted then
         State.Frame.Message := State.Words.Queue_Full;
         State.Frame.Message_Is_Error := True;
      end if;
   end Queue_Job;

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

      --  The pane changed size; the image is placed afresh to fit it.
      if State.Frame.Image_Id > 0 then
         Show_Image (State);
      end if;
   end Resize;

   function Result_Line (State : Session; Item : Explore.Jobs.Result_View) return String is
      Done : constant String :=
        (case Item.Job.Kind is
           when Explore.Jobs.Copy_Job => Unbounded.To_String (State.Words.Copied),
           when Explore.Jobs.Move_Job => Unbounded.To_String (State.Words.Moved),
           when Explore.Jobs.Link_Job => Unbounded.To_String (State.Words.Linked),
           when Explore.Jobs.Delete_Job => Unbounded.To_String (State.Words.Deleted));
      What : constant String :=
        Unbounded.To_String (Item.Job.First) & (if Item.Job.Total > 1 then " +" & Image (Item.Job.Total - 1) else "");
   begin
      case Item.Ended is
         when Explore.Jobs.Succeeded =>
            return Done & " " & What;
         when Explore.Jobs.Cancelled =>
            return Verb_Of (State, Item.Job.Kind) & " " & What & ": " & Unbounded.To_String (State.Words.Cancelled);
         when Explore.Jobs.Failed =>
            return Verb_Of (State, Item.Job.Kind) & " " & What & ": " & Image (Item.Errors) & " "
              & Unbounded.To_String (State.Words.Errors);
      end case;
   end Result_Line;

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
      State.Words := Load_Words (Context.Effective_Locale);
      State.Locale := Unbounded.To_Unbounded_String (Context.Effective_Locale);
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
               Written : constant Boolean :=
                 Write
                   ((if State.Identity.Capabilities (Explore.Protocol.Kitty_Graphics)
                     then Explore.Images.Delete_All (State.In_Tmux) else "")
                    & Explore.Protocol.Leave_Screen);
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
         Jobs       : aliased Explore.Tasks.Board;
         Workers    : array (1 .. Explore.Tasks.Worker_Count) of Explore.Tasks.Worker (Jobs'Access);
         Operations : aliased Explore.Jobs.Board;
         Operators  : array (Explore.Jobs.Lane_Index) of Explore.Jobs.Worker (Operations'Access);
         Previewer  : aliased Explore.Previews.Board;
         Builder    : Explore.Previews.Worker (Previewer'Access);
         pragma Unreferenced (Workers, Operators, Builder);

         procedure Stop_Workers;

         --  The workers must end before this block can be left. A file
         --  operation still running is stopped where it is.
         procedure Stop_Workers is
         begin
            Operations.Shut_Down;
            Previewer.Shut_Down;
            Jobs.Shut_Down;
            Release_Watches (State);
            State.Operations := null;
            State.Previewer := null;
         end Stop_Workers;
      begin
         --  The session outlives neither board: Stop_Workers forgets it.
         State.Operations := Operations'Unchecked_Access;
         State.Previewer := Previewer'Unchecked_Access;
         Resize (State, State.Size.Rows, State.Size.Columns);

         begin
            Main_Loop (State, Jobs);
         exception
            when others =>
               Stop_Workers;
               raise;
         end;

         Stop_Workers;
      end;

      Hand_Back;
      Outcome := (if State.Signalled then Session_Signalled else Session_Ended);
   exception
      when others =>
         Hand_Back;
         raise;
   end Run_Session;

   procedure Show_Image (State : in out Session) is
      use type Explore.Images.Image_Format;
      use type Unbounded.Unbounded_String;

      Preview : Explore.Previews.Preview renames State.Frame.Preview;
      Content : constant Explore.Render.Area :=
        Explore.Render.Content_Area (Explore.Render.Layout_For (State.Size.Rows, State.Size.Columns));
      Caps    : Explore.Protocol.Capability_Set renames State.Identity.Capabilities;
      Bytes   : constant Natural := Unbounded.Length (Preview.Image);
      Slot    : Natural := 0;
      Columns, Rows : Positive;

      function Fresh_Id return Positive;

      --  Free the least recently shown image other than the one at Keep.
      procedure Evict (Keep : Natural);

      procedure Evict (Keep : Natural) is
         Oldest : Natural := 0;
      begin
         for I in State.Images'Range loop
            if I /= Keep and then State.Images (I).Id > 0
              and then (Oldest = 0 or else State.Images (I).Used < State.Images (Oldest).Used)
            then
               Oldest := I;
            end if;
         end loop;

         if Oldest > 0 then
            if not Write (Explore.Images.Delete (State.Images (Oldest).Id, State.In_Tmux)) then
               State.Quit := True;
            end if;

            State.Images (Oldest) := (others => <>);
         end if;
      end Evict;

      function Fresh_Id return Positive is
      begin
         for Id in 1 .. 255 loop
            if (for all Item of State.Images => Item.Id /= Id) then
               return Id;
            end if;
         end loop;

         return 1;
      end Fresh_Id;
   begin
      Hide_Image (State);

      if Preview.Kind /= Explore.Previews.Image_Preview
        or else not Caps (Explore.Protocol.Kitty_Graphics)
        or else (Preview.Format = Explore.Images.JPEG_Format and then not Caps (Explore.Protocol.Kitty_Graphics_JPEG))
        or else (Preview.Format = Explore.Images.GIF_Format and then not Caps (Explore.Protocol.Kitty_Graphics_GIF))
        or else Content.Rows = 0
        or else Content.Columns = 0
        or else Preview.Width = 0
        or else Preview.Height = 0
      then
         return;
      end if;

      Explore.Images.Fit
        (Preview.Width, Preview.Height, State.Cell_Width, State.Cell_Height,
         Natural'Min (Content.Columns, Explore.Images.Diacritic_Count),
         Natural'Min (Content.Rows, Explore.Images.Diacritic_Count),
         Columns, Rows);
      State.Image_Clock := State.Image_Clock + 1;

      for I in State.Images'Range loop
         if State.Images (I).Id > 0
           and then State.Images (I).Path = Preview.Path
           and then State.Images (I).Modified = Preview.Modified
           and then State.Images (I).Size = Preview.File_Size
         then
            Slot := I;
         end if;
      end loop;

      if Slot > 0 then
         --  Already there: placed afresh only when the pane changed size.
         if State.Images (Slot).Columns /= Columns or else State.Images (Slot).Rows /= Rows then
            if not Write (Explore.Images.Place (State.Images (Slot).Id, Columns, Rows, State.In_Tmux)) then
               State.Quit := True;
               return;
            end if;
         end if;
      else
         --  Room by count, then by bytes, freeing the least recently shown.
         for I in State.Images'Range loop
            if State.Images (I).Id = 0 then
               Slot := I;
               exit;
            end if;
         end loop;

         if Slot = 0 then
            Evict (Keep => 0);

            for I in State.Images'Range loop
               if State.Images (I).Id = 0 then
                  Slot := I;
                  exit;
               end if;
            end loop;
         end if;

         while (for some Item of State.Images => Item.Id > 0)
           and then Bytes + [for Item of State.Images => Item.Bytes]'Reduce ("+", 0) > Image_Cache_Bytes
         loop
            Evict (Keep => 0);
         end loop;

         State.Images (Slot) :=
           (Path     => Preview.Path,
            Modified => Preview.Modified,
            Size     => Preview.File_Size,
            Id       => Fresh_Id,
            Bytes    => Bytes,
            others   => <>);

         if not Write
           (Explore.Images.Transmit
              (State.Images (Slot).Id, Preview.Format, Unbounded.To_String (Preview.Image), Columns, Rows,
               State.In_Tmux))
         then
            State.Quit := True;
            return;
         end if;
      end if;

      State.Images (Slot).Columns := Columns;
      State.Images (Slot).Rows := Rows;
      State.Images (Slot).Used := State.Image_Clock;
      State.Frame.Image_Id := State.Images (Slot).Id;
      State.Frame.Image_Columns := Columns;
      State.Frame.Image_Rows := Rows;
      State.Dirty := True;
   end Show_Image;

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

   procedure Watch_Jobs (State : in out Session) is
      Now   : constant Explore.Jobs.Snapshot := State.Operations.Status;
      Lane  : constant Natural := Explore.Jobs.Asking_Lane (Now);
      Shown : Natural := 0;
      Line  : Unbounded.Unbounded_String;
   begin
      if Now = State.Last_Job then
         return;
      end if;

      State.Dirty := True;

      --  The first running job in full, and how many more run or wait.
      for Running of Now.Lanes loop
         if Running.Running then
            Shown := Shown + 1;

            if Shown = 1 then
               Line := Unbounded.To_Unbounded_String (Lane_Line (State, Running));
            end if;
         end if;
      end loop;

      if Shown + Natural (Now.Queued.Length) > 1 and then Shown > 0 then
         Unbounded.Append (Line, " +" & Image (Shown - 1 + Natural (Now.Queued.Length)));
      end if;

      State.Frame.Job_Line := Line;

      if Lane > 0 and then State.Mode /= Answering then
         State.Mode := Answering;
         State.Frame.Panel_Open := False;
         State.Frame.Question :=
           Unbounded.To_Unbounded_String
             (Posix_Tools.Localization.Text_1
                (Unbounded.To_String (State.Locale),
                 "posix_tools.explore.ui.conflict",
                 "path",
                 Model.Name_Of (Unbounded.To_String (Now.Lanes (Lane).Conflict)),
                 Model.Name_Of (Unbounded.To_String (Now.Lanes (Lane).Conflict))
                 & " exists: o overwrite, s skip, O overwrite all, S skip all"));
      elsif Lane = 0 and then State.Mode = Answering then
         State.Mode := Browsing;
         State.Frame.Question := Unbounded.Null_Unbounded_String;
      end if;

      if Now.Completed /= State.Last_Job.Completed then
         --  Whatever the jobs changed is read again, and the latest one to
         --  end says how it went.
         Model.Reload_All (State.Browser);

         if not Now.History.Is_Empty then
            declare
               use type Explore.Jobs.Outcome;

               Latest : constant Explore.Jobs.Result_View := Now.History.Last_Element;
            begin
               if Latest.Ended = Explore.Jobs.Failed then
                  Complain (State, Unbounded.To_String (Latest.Error_Path), Latest.Error);

                  if Latest.Errors > 1 then
                     State.Frame.Message :=
                       Unbounded.To_Unbounded_String
                         (Image (Latest.Errors) & " " & Unbounded.To_String (State.Words.Errors) & ", "
                          & Unbounded.To_String (State.Frame.Message));
                  end if;
               else
                  State.Frame.Message := Unbounded.To_Unbounded_String (Result_Line (State, Latest));
                  State.Frame.Message_Is_Error := False;
               end if;
            end;
         end if;
      end if;

      if State.Frame.Panel_Open then
         Fill_Panel (State);
      end if;

      State.Last_Job := Now;
   end Watch_Jobs;

   procedure Watch_Preview (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Target  : constant String :=
        (if Model.Has_Selection (Current) and then not Model.Can_Enter (State.Browser)
         then Model.Selected_Path (Current) else "");
      Ready   : Explore.Previews.Preview;
      Found   : Boolean;
   begin
      if Target /= Unbounded.To_String (State.Previewing) then
         State.Previewing := Unbounded.To_Unbounded_String (Target);
         State.Frame.Preview := (others => <>);
         Hide_Image (State);

         if Target'Length > 0 then
            State.Preview_Generation := State.Preview_Generation + 1;
            State.Previewer.Submit (Target, State.Preview_Generation);
         end if;
      end if;

      State.Previewer.Collect (Ready, Found);

      if Found and then Ready.Generation = State.Preview_Generation then
         State.Frame.Preview := Ready;
         State.Dirty := True;

         if Ready.Kind = Explore.Previews.Image_Preview then
            Show_Image (State);
         end if;
      end if;
   end Watch_Preview;

end Explore.Application;
