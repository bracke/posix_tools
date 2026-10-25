with Explore.Application.Display;
with Explore.Application.Terminals;
with Explore.Files;
with Explore.Jobs;
with Explore.Keymap;
with Explore.Launch;
with Explore.Line_Editor;
with Explore.Model;
with Explore.Paths;
with Explore.Previews;
with Explore.Protocol;
with Explore.Render;
with Explore.Search;
with Explore.Settings.Storage;
with Explore.String_Vectors;
with Explore.Tabs;
with Explore.Words;
with Posix_Tools.Arguments;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Processes;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Application.Controller is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Input renames Explore.Input;
   package Keymap renames Explore.Keymap;
   package Model renames Explore.Model;

   use type FS.File_Kind;
   use type Input.Event_Kind;
   use type Input.Key_Kind;
   use type Input.Mouse_Action;
   use type Keymap.Action;

   --  Rows the mouse wheel moves the cursor.
   Wheel_Step : constant := 3;

   --  The commands that move the cursor.
   subtype Movement is Keymap.Action range Keymap.Move_Up .. Keymap.Page_Down;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  Answer the question of the job that asks, or cancel it, with Item.
   procedure Answer_Conflict (State : in out Session; Item : Input.Event);

   --  Open the prompt for Kind -- a rename, a creation, or a permission
   --  change -- when there is something for it to act on.
   procedure Ask_For_Name (State : in out Session; Kind : Keymap.Action)
     with Pre => Kind in Keymap.Rename_Entry | Keymap.Create_Entry | Keymap.Change_Mode;

   --  Ask to confirm deleting the entries the next command is for.
   procedure Ask_To_Delete (State : in out Session);

   --  Carry out what was typed into the prompt the session is in.
   procedure Commit (State : in out Session);

   --  Give the entries in Pending the permissions Text says, octal or
   --  symbolic.
   procedure Commit_Mode (State : in out Session; Text : String);

   --  Rename the entry in Pending to Text, or create Text: a directory when
   --  it ends in a slash, an empty file otherwise.
   procedure Commit_Name (State : in out Session; Text : String);

   --  Delete the entries in Pending when Item says yes.
   procedure Confirm_Delete (State : in out Session; Item : Input.Event);

   --  Put the paths of the entries the next command is for on the
   --  clipboard, or only their names, one to a line.
   procedure Copy_Targets (State : in out Session; Names_Only : Boolean);

   --  Put Text on the system clipboard, and say so.
   procedure Copy_Text (State : in out Session; Text : String);

   --  Type Item into the filter, which is applied as it is typed.
   procedure Edit_Filter (State : in out Session; Item : Input.Event);

   --  Type Item into the prompt, committing it on Enter.
   procedure Edit_Prompt (State : in out Session; Item : Input.Event);

   --  Go into the selected directory, or open the selected file.
   procedure Enter_Selected (State : in out Session);

   procedure Go_Bookmark (State : in out Session; Letter : Character);

   procedure Go_Home (State : in out Session);

   --  Act on a key or a paste, as the mode says.
   procedure Handle_Key (State : in out Session; Item : Input.Event)
     with Pre => Item.Kind in Input.Key_Event | Input.Paste_Event;

   --  The wheel moves the cursor; a click on an entry selects it, and one on
   --  the parent or the preview goes there.
   procedure Handle_Mouse (State : in out Session; Item : Input.Event)
     with Pre => Item.Kind = Input.Mouse_Event;

   --  Go to the directory Text names: absolute, relative to the current
   --  one, or from the home directory with a leading ~; a file is gone to
   --  in its directory, with the cursor on it.
   procedure Jump_To (State : in out Session; Text : String);

   procedure Move_Cursor (State : in out Session; Kind : Movement);

   --  Open the entries the next command is for with their opener, or, when
   --  explore chooses files for another program, write them down and quit.
   procedure Open_Targets (State : in out Session);

   --  Copy or move what was yanked or cut into the current directory, or
   --  link to it from there.
   procedure Paste (State : in out Session; Links : Boolean);

   --  Run the command Item, as browsing does.
   procedure Perform (State : in out Session; Item : Keymap.Command);

   --  Queue a job; say so in the status line when the queue is full.
   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job);

   --  Run the shell with Arguments. Detached, it is left to run on its own;
   --  otherwise the terminal is handed to it until it ends -- with Pause,
   --  until Enter is pressed after that -- and then taken back and redrawn.
   procedure Run_Program
     (State     : in out Session;
      Arguments : Posix_Tools.Arguments.Vector;
      Detach    : Boolean;
      Pause     : Boolean);

   --  Bookmark the current directory as Letter, keeping the bookmarks.
   procedure Set_Bookmark (State : in out Session; Letter : Character);

   --  Search below the current directory for Text, by name or by content as
   --  the prompt was for, showing the results in the current pane.
   procedure Start_Search (State : in out Session; Text : String);

   --  Yank or cut the entries the next command is for.
   procedure Take_Clipboard (State : in out Session; Cutting : Boolean);

   --  Move in the jobs panel, cancel the job a line stands for, or close it.
   procedure Use_Panel (State : in out Session; Item : Input.Event);

   --  Write Targets down for the program explore chooses files for, and quit.
   procedure Write_Choice (State : in out Session; Targets : Explore.String_Vectors.Vector);

   procedure Answer_Conflict (State : in out Session; Item : Input.Event) is
      Operations : Explore.Jobs.Board renames State.Workers.Operations.all;
   begin
      if Input.Is_Character (Item, 'o') then
         Operations.Answer (Explore.Jobs.Overwrite_One);
      elsif Input.Is_Character (Item, 'O') then
         Operations.Answer (Explore.Jobs.Overwrite_All);
      elsif Input.Is_Character (Item, 's') or else Item.Key = Input.Escape then
         Operations.Answer (Explore.Jobs.Skip_One);
      elsif Input.Is_Character (Item, 'S') then
         Operations.Answer (Explore.Jobs.Skip_All);
      elsif Item.Mods.Control and then Item.Code = 'c' then
         declare
            Now  : constant Explore.Jobs.Snapshot := Operations.Status;
            Lane : constant Natural := Explore.Jobs.Asking_Lane (Now);
         begin
            if Lane > 0 then
               Operations.Cancel (Now.Lanes (Lane).Job.Id);
            end if;
         end;
      end if;
   end Answer_Conflict;

   procedure Ask_For_Name (State : in out Session; Kind : Keymap.Action) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Words   : Explore.Words.Word_Set renames State.Config.Words;
   begin
      if Kind /= Keymap.Create_Entry and then not Model.Has_Selection (Current) then
         return;
      end if;

      State.Interaction.Pending :=
        (if Kind = Keymap.Rename_Entry
         then Explore.String_Vectors.To_Vector (Model.Selected_Path (Current), 1)
         else Model.Targets (State.Browser));

      if Kind = Keymap.Rename_Entry then
         Open_Prompt (State, Renaming, Words.Rename_Prompt, Model.Selected_Name (Current));
      elsif Kind = Keymap.Create_Entry then
         Open_Prompt (State, Creating, Words.Create_Prompt);
      else
         Open_Prompt
           (State,
            Changing_Mode,
            Words.Mode_Prompt,
            Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (Model.Selected (Current).Status.Mode mod 8#10000#));
      end if;
   end Ask_For_Name;

   procedure Ask_To_Delete (State : in out Session) is
   begin
      State.Interaction.Pending := Model.Targets (State.Browser);

      if not State.Interaction.Pending.Is_Empty then
         Ask
           (State,
            Confirming_Delete,
            Explore.Words.Confirm_Delete
              (Unbounded.To_String (State.Config.Locale), Natural (State.Interaction.Pending.Length)));
      end if;
   end Ask_To_Delete;

   procedure Commit (State : in out Session) is
      Text   : constant String := Unbounded.To_String (State.Frame.Prompt_Text);
      Folder : constant String := Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path);
   begin
      if Text'Length = 0 then
         return;
      end if;

      case State.Interaction.Mode is
         when Renaming | Creating =>
            Commit_Name (State, Text);
         when Changing_Mode =>
            Commit_Mode (State, Text);
         when Jumping =>
            Jump_To (State, Text);
         when Finding_Names | Finding_Text =>
            Start_Search (State, Text);
         when Shelling =>
            Run_Program
              (State,
               Explore.Launch.Shell_Arguments (Folder, Text, State.Interaction.Pending),
               Detach => False,
               Pause  => True);
         when Browsing | Filtering | Question_Mode | Viewing_Jobs =>
            null;
      end case;
   end Commit;

   procedure Commit_Mode (State : in out Session; Text : String) is
      use type Posix_Tools.Text.File_Modes.Permission_Mode_Status;

      Parsed : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
        Posix_Tools.Text.File_Modes.Parse_Permission_Mode (Text);
   begin
      for Path of State.Interaction.Pending loop
         declare
            Known   : Boolean;
            Old     : constant Natural := FS.File_Permission_Bits (Path, Known) mod 8#10000#;
            Applied : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
              (if Parsed.Status = Posix_Tools.Text.File_Modes.Octal_Permission_Mode
               then (Valid => True, Mode => Parsed.Mode)
               else Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode (Text, Old));
         begin
            if not Applied.Valid then
               Warn (State, Text & ": " & Unbounded.To_String (State.Config.Words.Invalid_Mode));
               return;
            elsif not FS.Set_Permissions (Path, Applied.Mode) then
               Complain (State, Path, Posix_Tools.File_Operations.Cannot_Open);
            end if;
         end;
      end loop;

      Model.Clear_Marks (State.Browser);
      Model.Reload (State.Browser, Model.Current_Pane);
   end Commit_Mode;

   procedure Commit_Name (State : in out Session; Text : String) is
      Current   : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Directory : constant Boolean := State.Interaction.Mode = Creating and then Text (Text'Last) = '/';
      Name      : constant String := (if Directory then Text (Text'First .. Text'Last - 1) else Text);
      Target    : constant String := Explore.Paths.Child_Of (Unbounded.To_String (Current.Path), Name);
      Written   : Boolean := True;
   begin
      if Name'Length = 0 or else Name = "." or else Name = ".." or else (for some C of Name => C = '/') then
         Complain (State, Text, Posix_Tools.File_Operations.Cannot_Open);
         return;
      elsif FS.Exists (Target) or else FS.Is_Link (Target) then
         Warn (State, Name & ": " & Unbounded.To_String (State.Config.Words.Exists));
         return;
      end if;

      begin
         if State.Interaction.Mode = Renaming then
            FS.Rename (State.Interaction.Pending.First_Element, Target);
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
   end Commit_Name;

   procedure Confirm_Delete (State : in out Session; Item : Input.Event) is
   begin
      if Input.Is_Character (Item, 'y') or else Input.Is_Character (Item, 'Y') then
         Queue_Job (State, (Explore.Jobs.Delete_Job, State.Interaction.Pending, others => <>));
         Model.Clear_Marks (State.Browser);
      end if;

      State.Interaction.Pending.Clear;
      Leave_Mode (State);
   end Confirm_Delete;

   procedure Copy_Targets (State : in out Session; Names_Only : Boolean) is
      Text : Unbounded.Unbounded_String;
   begin
      for Path of Model.Targets (State.Browser) loop
         if Unbounded.Length (Text) > 0 then
            Unbounded.Append (Text, Character'Val (10));
         end if;

         Unbounded.Append (Text, (if Names_Only then Explore.Paths.Name_Of (Path) else Path));
      end loop;

      if Unbounded.Length (Text) > 0 then
         Copy_Text (State, Unbounded.To_String (Text));
      end if;
   end Copy_Targets;

   procedure Copy_Text (State : in out Session; Text : String) is
   begin
      if not State.Terminal.Identity.Capabilities (Explore.Protocol.Clipboard) then
         Warn (State, Unbounded.To_String (State.Config.Words.No_Clipboard));
      elsif not Write (Explore.Launch.Clipboard (Text, State.Terminal.In_Tmux)) then
         Lose_Terminal (State);
      else
         Say
           (State,
            Unbounded.To_String (State.Config.Words.Clipped) & ": "
            & (if (for some C of Text => C = Character'Val (10)) then "..." else Text));
      end if;
   end Copy_Text;

   procedure Edit_Filter (State : in out Session; Item : Input.Event) is
      Result : Explore.Line_Editor.Outcome;
   begin
      Explore.Line_Editor.Edit (State.Browser.Filter, Item, Result);

      case Result is
         when Explore.Line_Editor.Accepted =>
            Leave_Mode (State);
         when Explore.Line_Editor.Escaped =>
            Leave_Mode (State);
            State.Browser.Filter := Unbounded.Null_Unbounded_String;
         when Explore.Line_Editor.Typing | Explore.Line_Editor.Interrupted =>
            null;
      end case;

      Model.Apply_Filter (State.Browser);
      State.Dirty := True;
   end Edit_Filter;

   procedure Edit_Prompt (State : in out Session; Item : Input.Event) is
      Result : Explore.Line_Editor.Outcome;
   begin
      Explore.Line_Editor.Edit (State.Frame.Prompt_Text, Item, Result);

      case Result is
         when Explore.Line_Editor.Typing =>
            null;
         when Explore.Line_Editor.Accepted =>
            Commit (State);
            Leave_Mode (State);
         when Explore.Line_Editor.Escaped | Explore.Line_Editor.Interrupted =>
            Leave_Mode (State);
      end case;
   end Edit_Prompt;

   procedure Enter_Selected (State : in out Session) is
      use type Posix_Tools.File_Operations.Listing.Entry_Kind;

      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      if Model.Can_Enter (State.Browser) then
         Model.Enter (State.Browser);
      elsif Model.Has_Selection (Current)
        and then Model.Selected (Current).Kind = Posix_Tools.File_Operations.Listing.Regular_Entry
      then
         Open_Targets (State);
      end if;
   end Enter_Selected;

   procedure Go_Bookmark (State : in out Session; Letter : Character) is
   begin
      if State.Interaction.Bookmarks.Contains (Letter) then
         Jump_To (State, Unbounded.To_String (State.Interaction.Bookmarks.Element (Letter)));
      else
         Warn (State, Unbounded.To_String (State.Config.Words.No_Bookmark) & ": " & Letter);
      end if;
   end Go_Bookmark;

   procedure Go_Home (State : in out Session) is
      Home : constant String := Unbounded.To_String (State.Config.Home);
   begin
      if Home'Length > 0 and then FS.Kind (Home) = FS.Directory then
         Model.Open (State.Browser, FS.Real_Path (Home));
      end if;
   end Go_Home;

   procedure Handle (State : in out Session; Item : Input.Event) is
   begin
      case Item.Kind is
         when Input.Key_Event | Input.Paste_Event =>
            --  What was said is shown until the next key.
            Say (State, "");
            State.Dirty := True;
            Handle_Key (State, Item);
         when Input.Mouse_Event =>
            Handle_Mouse (State, Item);
         when Input.Resize_Event =>
            if Item.Rows > 0 and then Item.Columns > 0 then
               if Item.Pixel_Width >= Item.Columns and then Item.Pixel_Height >= Item.Rows then
                  State.Terminal.Cell_Width := Item.Pixel_Width / Item.Columns;
                  State.Terminal.Cell_Height := Item.Pixel_Height / Item.Rows;
               end if;

               Explore.Application.Display.Resize (State, Item.Rows, Item.Columns);
            end if;
         when Input.Focus_Event =>
            --  Whatever happened to the screen meanwhile, put it right.
            if Item.Focused then
               State.Terminal.Repaint := True;
               State.Dirty := True;
            end if;
         when Input.Reply_Event =>
            null;
      end case;
   end Handle;

   procedure Handle_Key (State : in out Session; Item : Input.Event) is
      Command : Keymap.Command;
   begin
      case State.Interaction.Mode is
         when Browsing =>
            if Item.Kind = Input.Key_Event then
               Keymap.Translate (State.Interaction.Keys, Item, Command);
               Perform (State, Command);
            end if;
         when Filtering =>
            Edit_Filter (State, Item);
         when Prompt_Mode =>
            Edit_Prompt (State, Item);
         when Confirming_Delete =>
            Confirm_Delete (State, Item);
         when Answering =>
            if Item.Kind = Input.Key_Event then
               Answer_Conflict (State, Item);
            end if;
         when Viewing_Jobs =>
            if Item.Kind = Input.Key_Event then
               Use_Panel (State, Item);
            end if;
      end case;
   end Handle_Key;

   procedure Handle_Mouse (State : in out Session; Item : Input.Event) is
      Shape : constant Explore.Render.Layout :=
        Explore.Render.Layout_For (State.Terminal.Size.Rows, State.Terminal.Size.Columns);
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

   procedure Jump_To (State : in out Session; Text : String) is
      Current : constant String := Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path);
      Home    : constant String := Unbounded.To_String (State.Config.Home);
      Path    : constant String :=
        (if Text = "~" then Home
         elsif Text'Length >= 2 and then Text (Text'First .. Text'First + 1) = "~/"
         then Explore.Paths.Child_Of (Home, Text (Text'First + 2 .. Text'Last))
         elsif Text (Text'First) = '/' then Text
         else Explore.Paths.Child_Of (Current, Text));
   begin
      if FS.Kind (Path) = FS.Directory then
         Model.Jump (State.Browser, FS.Real_Path (Path));
      elsif FS.Exists (Path) then
         declare
            Real : constant String := FS.Real_Path (Path);
         begin
            Model.Jump (State.Browser, Explore.Paths.Parent_Of (Real), Explore.Paths.Name_Of (Real));
         end;
      else
         Complain (State, Text, Posix_Tools.File_Operations.Not_A_Directory);
      end if;
   exception
      when others =>
         Complain (State, Text, Posix_Tools.File_Operations.Cannot_Open);
   end Jump_To;

   procedure Move_Cursor (State : in out Session; Kind : Movement) is
      Height : constant Positive :=
        Positive'Max (1, Explore.Render.Layout_For (State.Terminal.Size.Rows, State.Terminal.Size.Columns).Height);
      Half   : constant Positive := Positive'Max (1, Height / 2);
   begin
      case Kind is
         when Keymap.Move_Up =>
            Model.Move (State.Browser, -1);
         when Keymap.Move_Down =>
            Model.Move (State.Browser, 1);
         when Keymap.Move_Top =>
            Model.Move_To (State.Browser, 1);
         when Keymap.Move_Bottom =>
            Model.Move_To (State.Browser, Model.Shown_Count (State.Browser.Panes (Model.Current_Pane)));
         when Keymap.Half_Page_Up =>
            Model.Move (State.Browser, -Half);
         when Keymap.Half_Page_Down =>
            Model.Move (State.Browser, Half);
         when Keymap.Page_Up =>
            Model.Move (State.Browser, -Height);
         when Keymap.Page_Down =>
            Model.Move (State.Browser, Height);
      end case;
   end Move_Cursor;

   procedure Open_Targets (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Targets : constant Explore.String_Vectors.Vector := Model.Targets (State.Browser);
   begin
      if Targets.Is_Empty then
         return;
      elsif Unbounded.Length (State.Config.Chooser_File) > 0 then
         Write_Choice (State, Targets);
         return;
      end if;

      declare
         First  : constant String := Targets.First_Element;
         Head   : Unbounded.Unbounded_String;
         Read   : Boolean;
         Opener : Explore.Launch.Opener;
      begin
         --  Only a plain file is looked into: reading a pipe or a device
         --  could wait for ever, and this is the screen's own thread.
         if FS.Kind (First) /= FS.Special_File then
            Explore.Files.Read_Head (First, 4096, Head, Read);
         else
            Read := False;
         end if;

         Opener :=
           Explore.Launch.Opener_For
             (State.Config.Openers,
              Explore.Paths.Name_Of (First),
              Read and then Explore.Previews.Is_Text (Unbounded.To_String (Head)));
         Run_Program
           (State,
            Explore.Launch.Shell_Arguments
              (Unbounded.To_String (Current.Path), Unbounded.To_String (Opener.Run), Targets, Opener.Detach),
            Detach => Opener.Detach,
            Pause  => False);
      end;

      Model.Clear_Marks (State.Browser);
   end Open_Targets;

   procedure Paste (State : in out Session; Links : Boolean) is
      Held : Interaction_State renames State.Interaction;
   begin
      if Held.Clipboard.Is_Empty then
         return;
      end if;

      Queue_Job
        (State,
         (Kind    =>
            (if Links then Explore.Jobs.Link_Job
             elsif Held.Cutting then Explore.Jobs.Move_Job
             else Explore.Jobs.Copy_Job),
          Sources => Held.Clipboard,
          Target  => State.Browser.Panes (Model.Current_Pane).Path,
          Id      => 0));

      --  What was cut is gone from where it was once pasted.
      if Held.Cutting and then not Links then
         Held.Clipboard.Clear;
         Held.Cutting := False;
      end if;
   end Paste;

   procedure Perform (State : in out Session; Item : Keymap.Command) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Words   : Explore.Words.Word_Set renames State.Config.Words;
   begin
      case Item.Kind is
         when Keymap.No_Action =>
            null;
         when Keymap.Quit =>
            State.Quit := True;
         when Movement =>
            Move_Cursor (State, Item.Kind);
         when Keymap.Enter_Directory =>
            Enter_Selected (State);
         when Keymap.Leave_Directory =>
            Model.Leave (State.Browser);
         when Keymap.Go_Back =>
            Model.Go_Back (State.Browser);
         when Keymap.Go_Forward =>
            Model.Go_Forward (State.Browser);
         when Keymap.Go_Home =>
            Go_Home (State);
         when Keymap.Jump_To_Path =>
            Open_Prompt (State, Jumping, Words.Jump_Prompt);
         when Keymap.Set_Bookmark =>
            Set_Bookmark (State, Item.Letter);
         when Keymap.Go_Bookmark =>
            Go_Bookmark (State, Item.Letter);

         when Keymap.Toggle_Hidden =>
            State.Browser.Show_Hidden := not State.Browser.Show_Hidden;
            Model.Reload_All (State.Browser);
         when Keymap.Sort_Entries =>
            State.Browser.Order.Key := Item.Key;
            State.Browser.Order.Descending := Item.Descending;
            Model.Reload_All (State.Browser);
         when Keymap.Start_Filter =>
            State.Interaction.Mode := Filtering;
         when Keymap.Clear_Filter =>
            State.Browser.Filter := Unbounded.Null_Unbounded_String;
            Model.Apply_Filter (State.Browser);
            Model.End_Visual (State.Browser);
            Model.Clear_Marks (State.Browser);
         when Keymap.Search_Names =>
            Open_Prompt (State, Finding_Names, Words.Names_Prompt);
         when Keymap.Search_Contents =>
            Open_Prompt (State, Finding_Text, Words.Text_Prompt);

         when Keymap.Toggle_Mark =>
            Model.Toggle_Mark (State.Browser);
            Model.Move (State.Browser, 1);
         when Keymap.Visual_Mode =>
            if Model.In_Visual (State.Browser) then
               Model.End_Visual (State.Browser);
            else
               Model.Start_Visual (State.Browser);
            end if;

         when Keymap.Yank | Keymap.Cut =>
            Take_Clipboard (State, Cutting => Item.Kind = Keymap.Cut);
         when Keymap.Paste | Keymap.Paste_Links =>
            Paste (State, Links => Item.Kind = Keymap.Paste_Links);
         when Keymap.Delete_Entries =>
            Ask_To_Delete (State);
         when Keymap.Rename_Entry | Keymap.Create_Entry | Keymap.Change_Mode =>
            Ask_For_Name (State, Item.Kind);
         when Keymap.Cancel_Job =>
            if Explore.Jobs.Any_Running (State.Workers.Last_Job) then
               State.Workers.Operations.Cancel_Running;
               Say (State, Unbounded.To_String (Words.Cancelled));
            end if;
         when Keymap.Show_Jobs =>
            State.Interaction.Mode := Viewing_Jobs;
            State.Frame.Panel_Cursor := 1;
            Explore.Application.Display.Fill_Panel (State, State.Workers.Operations.Status);

         when Keymap.New_Tab =>
            Explore.Tabs.Open_Tab (State.Tabs, State.Browser);
         when Keymap.Close_Tab =>
            Explore.Tabs.Close_Tab (State.Tabs, State.Browser);
         when Keymap.Previous_Tab =>
            Explore.Tabs.Switch_To (State.Tabs, State.Browser, Explore.Tabs.Previous (State.Tabs));
         when Keymap.Next_Tab =>
            Explore.Tabs.Switch_To (State.Tabs, State.Browser, Explore.Tabs.Next (State.Tabs));
         when Keymap.Switch_Tab =>
            if Item.Number in 1 .. Explore.Tabs.Count (State.Tabs) then
               Explore.Tabs.Switch_To (State.Tabs, State.Browser, Item.Number);
            end if;

         when Keymap.Open_Entries =>
            Open_Targets (State);
         when Keymap.Shell_Command =>
            State.Interaction.Pending := Model.Targets (State.Browser);
            Open_Prompt (State, Shelling, Words.Shell_Prompt);
         when Keymap.Spawn_Shell =>
            Run_Program
              (State,
               Explore.Launch.Shell_Arguments
                 (Unbounded.To_String (Current.Path), Explore.Launch.Interactive_Shell, Model.Targets (State.Browser)),
               Detach => False,
               Pause  => False);
         when Keymap.Copy_Path | Keymap.Copy_Name =>
            Copy_Targets (State, Names_Only => Item.Kind = Keymap.Copy_Name);
         when Keymap.Copy_Directory =>
            Copy_Text (State, Unbounded.To_String (Current.Path));
      end case;
   end Perform;

   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job) is
      Accepted : Boolean;
   begin
      State.Workers.Operations.Submit (Item, Accepted);

      if not Accepted then
         Warn (State, Unbounded.To_String (State.Config.Words.Queue_Full));
      end if;
   end Queue_Job;

   procedure Run_Program
     (State     : in out Session;
      Arguments : Posix_Tools.Arguments.Vector;
      Detach    : Boolean;
      Pause     : Boolean)
   is
      Status : Integer;
      Ran    : Boolean;
   begin
      if Detach then
         Ran := Posix_Tools.Host_Adapters.Processes.Run (Explore.Launch.Shell, Arguments, Status);
      else
         declare
            Kept : Explore.Application.Terminals.Program_Dispositions;
            Ok   : Boolean;
         begin
            Explore.Application.Terminals.Suspend (State, Kept, Ok);

            if not Ok then
               return;
            end if;

            Ran := Posix_Tools.Host_Adapters.Processes.Run (Explore.Launch.Shell, Arguments, Status);

            if Pause then
               Explore.Application.Terminals.Wait_For_Enter (State);
            end if;

            Explore.Application.Terminals.Resume (State, Kept, Ok);

            if not Ok then
               return;
            end if;
         end;
      end if;

      --  A shell that a signal ended, or that could not be started, has no
      --  status of its own to report.
      if not Ran then
         Warn (State, Unbounded.To_String (State.Config.Words.Cannot_Run));
      elsif Status /= 0 then
         Warn (State, Unbounded.To_String (State.Config.Words.Exit_Status) & " " & Image (Natural'Max (0, Status)));
      end if;

      Model.Reload_All (State.Browser);
      State.Dirty := True;
   end Run_Program;

   procedure Set_Bookmark (State : in out Session; Letter : Character) is
      Path : constant Unbounded.Unbounded_String := State.Browser.Panes (Model.Current_Pane).Path;
      File : constant String := Unbounded.To_String (State.Config.Marks_File);
      Kept : Boolean;
   begin
      State.Interaction.Bookmarks.Include (Letter, Path);
      Say
        (State,
         Unbounded.To_String (State.Config.Words.Bookmarked) & " " & Letter & ": " & Unbounded.To_String (Path));

      if File'Length > 0 then
         Explore.Settings.Storage.Write_Bookmarks (File, State.Interaction.Bookmarks, Kept);

         if not Kept then
            Warn (State, Unbounded.To_String (State.Config.Words.Unsaved));
         end if;
      end if;
   end Set_Bookmark;

   procedure Start_Search (State : in out Session; Text : String) is
      Root : constant String := Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path);
   begin
      Model.Begin_Search (State.Browser, Root, Text, State.Workers.Search_Generation);
      State.Workers.Search_Found := 0;
      State.Workers.Searcher.Submit
        ((Root           => Unbounded.To_Unbounded_String (Root),
          Pattern        => Unbounded.To_Unbounded_String (Text),
          Kind           =>
            (if State.Interaction.Mode = Finding_Names then Explore.Search.By_Name else Explore.Search.By_Content),
          Include_Hidden => State.Browser.Show_Hidden,
          Generation     => State.Workers.Search_Generation));
   end Start_Search;

   procedure Take_Clipboard (State : in out Session; Cutting : Boolean) is
      Held : Interaction_State renames State.Interaction;
   begin
      Held.Clipboard := Model.Targets (State.Browser);
      Held.Cutting := Cutting;
      Model.Clear_Marks (State.Browser);

      if not Held.Clipboard.Is_Empty then
         Say
           (State,
            Image (Natural (Held.Clipboard.Length)) & " "
            & Unbounded.To_String (if Cutting then State.Config.Words.Cut else State.Config.Words.Yanked));
      end if;
   end Take_Clipboard;

   procedure Use_Panel (State : in out Session; Item : Input.Event) is
      Rows   : constant Natural := Natural (State.Frame.Panel_Ids.Length);
      Cursor : Natural renames State.Frame.Panel_Cursor;
   begin
      if Input.Is_Character (Item, 'j') or else Item.Key = Input.Down then
         Cursor := Natural'Min (Rows, Cursor + 1);
      elsif Input.Is_Character (Item, 'k') or else Item.Key = Input.Up then
         Cursor := Natural'Max (1, Cursor - 1);
      elsif Input.Is_Character (Item, 'x') or else (Item.Mods.Control and then Item.Code = 'c') then
         if Cursor in 1 .. Rows and then State.Frame.Panel_Ids (Cursor) > 0 then
            State.Workers.Operations.Cancel (State.Frame.Panel_Ids (Cursor));
         end if;
      elsif Input.Is_Character (Item, 'w') or else Input.Is_Character (Item, 'q') or else Item.Key = Input.Escape then
         Leave_Mode (State);
      end if;

      Explore.Application.Display.Fill_Panel (State, State.Workers.Operations.Status);
   end Use_Panel;

   procedure Write_Choice (State : in out Session; Targets : Explore.String_Vectors.Vector) is
      File : constant String := Unbounded.To_String (State.Config.Chooser_File);
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      for Path of Targets loop
         Unbounded.Append (Text, Path & Character'Val (10));
      end loop;

      FS.Write_File (File, Unbounded.To_String (Text), False, Ok);

      if Ok then
         State.Quit := True;
      else
         Complain (State, File, Posix_Tools.File_Operations.Cannot_Open);
      end if;
   end Write_Choice;
end Explore.Application.Controller;
