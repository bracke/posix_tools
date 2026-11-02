with Explore.Application.Controller.Programs;
with Explore.Application.Controller.Prompts;
with Explore.Application.Display;
with Explore.Jobs;
with Explore.Keymap;
with Explore.Launch;
with Explore.Line_Editor;
with Explore.Model;
with Explore.Modes;
with Explore.Paths;
with Explore.Protocol;
with Explore.Render;
with Explore.Settings.Storage;
with Explore.Tabs;
with Explore.Words;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.File_System;

package body Explore.Application.Controller is
   use Explore.Modes;

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

   --  Answer the question of the job that asks, or cancel it, with Item.
   procedure Answer_Conflict (State : in out Session; Item : Input.Event);

   --  Ask to confirm deleting the entries the next command is for.
   procedure Ask_To_Delete (State : in out Session);

   --  Delete the entries in Pending when Item says yes.
   procedure Confirm_Delete (State : in out Session; Item : Input.Event);

   --  Quits on y; anything else keeps the jobs, and explore, running.
   procedure Confirm_Quit (State : in out Session; Item : Input.Event);

   --  Put the paths of the entries the next command is for on the
   --  clipboard, or only their names, one to a line.
   procedure Copy_Targets (State : in out Session; Names_Only : Boolean);

   --  Put Text on the system clipboard, and say so.
   procedure Copy_Text (State : in out Session; Text : String);

   --  Type Item into the filter, which is applied as it is typed.
   procedure Edit_Filter (State : in out Session; Item : Input.Event);

   --  Go into the selected directory, or open the selected file.
   procedure Enter_Selected (State : in out Session);

   procedure Go_Bookmark (State : in out Session; Letter : Character);

   --  Go to the home directory, as a visit that Back returns from.
   procedure Go_Home (State : in out Session);

   --  Act on a key or a paste, as the mode says.
   procedure Handle_Key (State : in out Session; Item : Input.Event)
     with Pre => Item.Kind in Input.Key_Event | Input.Paste_Event;

   --  The wheel moves the cursor; a click on an entry selects it, and one on
   --  the parent or the preview goes there, unless the filter is being typed.
   procedure Handle_Mouse (State : in out Session; Item : Input.Event)
     with Pre => Item.Kind = Input.Mouse_Event;

   procedure Move_Cursor (State : in out Session; Kind : Movement);

   --  Copy or move what was yanked or cut into the current directory, or
   --  link to it from there.
   procedure Paste (State : in out Session; Links : Boolean);

   --  The commands that go elsewhere: in the directory, to another, or to
   --  another tab.
   subtype Navigation_Action is Keymap.Action
     with Static_Predicate =>
       Navigation_Action in Movement | Keymap.Enter_Directory | Keymap.Leave_Directory | Keymap.Go_Home
         | Keymap.Go_Back | Keymap.Go_Forward | Keymap.Jump_To_Path | Keymap.Set_Bookmark | Keymap.Go_Bookmark
         | Keymap.New_Tab | Keymap.Close_Tab | Keymap.Previous_Tab | Keymap.Next_Tab | Keymap.Switch_Tab;

   --  The commands that change what the current pane lists, or marks.
   subtype Listing_Action is Keymap.Action
     with Static_Predicate =>
       Listing_Action in Keymap.Toggle_Hidden | Keymap.Sort_Entries | Keymap.Start_Filter | Keymap.Clear_Filter
         | Keymap.Search_Names | Keymap.Search_Contents | Keymap.Toggle_Mark | Keymap.Visual_Mode;

   --  The commands that change files, or follow the operations doing so.
   subtype Operation_Action is Keymap.Action range Keymap.Yank .. Keymap.Show_Jobs;

   --  The commands that hand the entries to other programs, or to the
   --  clipboard.
   subtype Program_Action is Keymap.Action range Keymap.Open_Entries .. Keymap.Copy_Name;

   --  Run the command Item, as browsing does: quitting here, and the rest by
   --  what they act on.
   procedure Perform (State : in out Session; Item : Keymap.Command);

   procedure Change_Listing (State : in out Session; Item : Keymap.Command)
     with Pre => Item.Kind in Listing_Action;

   procedure Navigate (State : in out Session; Item : Keymap.Command)
     with Pre => Item.Kind in Navigation_Action;

   procedure Operate (State : in out Session; Item : Keymap.Command)
     with Pre => Item.Kind in Operation_Action;

   procedure Use_Programs (State : in out Session; Item : Keymap.Command)
     with Pre => Item.Kind in Program_Action;

   --  Queue a job; say so in the status line when the queue is full, and
   --  Queued False.
   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job; Queued : out Boolean);

   --  Bookmark the current directory as Letter, keeping the bookmarks.
   procedure Set_Bookmark (State : in out Session; Letter : Character);

   --  Yank or cut the entries the next command is for.
   procedure Take_Clipboard (State : in out Session; Cutting : Boolean);

   --  Move in the jobs panel, cancel the job a line stands for, or close it.
   procedure Use_Panel (State : in out Session; Item : Input.Event);

   procedure Answer_Conflict (State : in out Session; Item : Input.Event) is
      use type Unbounded.Unbounded_String;

      Operations : Explore.Jobs.Board renames State.Workers.Operations.all;
      Now        : constant Explore.Jobs.Snapshot := Operations.Status;
      Lane       : constant Natural := Explore.Jobs.Asking_Lane (Now);
   begin
      --  The job asking now is not about what the screen asks: the question
      --  is shown afresh first, and this key answers nothing.
      if Lane = 0 or else Now.Lanes (Lane).Conflict /= State.Workers.Asked_About then
         return;
      end if;

      --  The board answers only if the lane still asks about that target.
      if Input.Is_Character (Item, 'o') then
         Operations.Answer (Lane, Now.Lanes (Lane).Conflict, Explore.Jobs.Overwrite_One);
      elsif Input.Is_Character (Item, 'O') then
         Operations.Answer (Lane, Now.Lanes (Lane).Conflict, Explore.Jobs.Overwrite_All);
      elsif Input.Is_Character (Item, 's') or else Item.Key = Input.Escape then
         Operations.Answer (Lane, Now.Lanes (Lane).Conflict, Explore.Jobs.Skip_One);
      elsif Input.Is_Character (Item, 'S') then
         Operations.Answer (Lane, Now.Lanes (Lane).Conflict, Explore.Jobs.Skip_All);
      elsif Item.Mods.Control and then Item.Code = 'c' then
         Operations.Cancel (Now.Lanes (Lane).Job.Id);
      end if;
   end Answer_Conflict;

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

   procedure Change_Listing (State : in out Session; Item : Keymap.Command) is
      Words : Explore.Words.Word_Set renames State.Config.Words;
   begin
      case Listing_Action'(Item.Kind) is
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
      end case;
   end Change_Listing;

   procedure Confirm_Delete (State : in out Session; Item : Input.Event) is
      Queued : Boolean;
   begin
      if Input.Is_Character (Item, 'y') or else Input.Is_Character (Item, 'Y') then
         Queue_Job (State, (Explore.Jobs.Delete_Job, State.Interaction.Pending, others => <>), Queued);

         --  A delete the queue had no room for leaves the marks to try again with.
         if Queued then
            Model.Clear_Marks (State.Browser);
         end if;
      end if;

      State.Interaction.Pending.Clear;
      Leave_Mode (State);
   end Confirm_Delete;

   procedure Confirm_Quit (State : in out Session; Item : Input.Event) is
   begin
      if Input.Is_Character (Item, 'y') or else Input.Is_Character (Item, 'Y') then
         State.Quit := True;
      end if;

      Leave_Mode (State);
   end Confirm_Quit;

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
      else
         Send (State, Explore.Launch.Clipboard (Text, State.Terminal.In_Tmux));
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

   procedure Enter_Selected (State : in out Session) is
      use type Posix_Tools.File_Operations.Listing.Entry_Kind;

      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      if Model.Can_Enter (State.Browser) then
         Model.Enter (State.Browser);
      elsif Model.Has_Selection (Current)
        and then Model.Selected (Current).Kind = Posix_Tools.File_Operations.Listing.Regular_Entry
      then
         Programs.Open_Targets (State);
      end if;
   end Enter_Selected;

   procedure Go_Bookmark (State : in out Session; Letter : Character) is
   begin
      if State.Interaction.Bookmarks.Contains (Letter) then
         Prompts.Jump_To (State, Unbounded.To_String (State.Interaction.Bookmarks.Element (Letter)));
      else
         Warn (State, Unbounded.To_String (State.Config.Words.No_Bookmark) & ": " & Letter);
      end if;
   end Go_Bookmark;

   procedure Go_Home (State : in out Session) is
      Home : constant String := Unbounded.To_String (State.Config.Home);
   begin
      if Home'Length > 0 and then FS.Kind (Home) = FS.Directory then
         --  A visit like any other: Back returns to the directory left.
         Model.Jump (State.Browser, FS.Real_Path (Home));
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
            --  A prompt, a question or the jobs panel acts on what it was
            --  opened for: a click must not move the panes from under it.
            if State.Interaction.Mode in Browsing | Filtering then
               Handle_Mouse (State, Item);
            end if;
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
            Prompts.Edit_Prompt (State, Item);
         when Confirming_Delete =>
            Confirm_Delete (State, Item);
         when Confirming_Quit =>
            Confirm_Quit (State, Item);
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
      Shape : constant Explore.Render.Layout := Explore.Application.Display.Shape (State);
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
                        --  Going elsewhere would drop the filter being typed.
                        when Model.Parent_Pane =>
                           if State.Interaction.Mode = Browsing then
                              Model.Leave (State.Browser);
                           end if;
                        when Model.Preview_Pane =>
                           if State.Interaction.Mode = Browsing then
                              Model.Enter (State.Browser);
                           end if;
                     end case;
                  end if;
               end;
            end loop;
         when Input.Middle_Button | Input.Right_Button | Input.No_Button =>
            return;
      end case;

      State.Dirty := True;
   end Handle_Mouse;

   procedure Move_Cursor (State : in out Session; Kind : Movement) is
      Height : constant Positive :=
        Positive'Max (1, Explore.Application.Display.Shape (State).Height);
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

   procedure Navigate (State : in out Session; Item : Keymap.Command) is
   begin
      case Navigation_Action'(Item.Kind) is
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
            Open_Prompt (State, Jumping, State.Config.Words.Jump_Prompt);
         when Keymap.Set_Bookmark =>
            Set_Bookmark (State, Item.Letter);
         when Keymap.Go_Bookmark =>
            Go_Bookmark (State, Item.Letter);
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
      end case;
   end Navigate;

   procedure Operate (State : in out Session; Item : Keymap.Command) is
   begin
      case Operation_Action'(Item.Kind) is
         when Keymap.Yank | Keymap.Cut =>
            Take_Clipboard (State, Cutting => Item.Kind = Keymap.Cut);
         when Keymap.Paste | Keymap.Paste_Links =>
            Paste (State, Links => Item.Kind = Keymap.Paste_Links);
         when Keymap.Delete_Entries =>
            Ask_To_Delete (State);
         when Keymap.Rename_Entry | Keymap.Create_Entry | Keymap.Change_Mode =>
            Prompts.Ask_For_Name (State, Item.Kind);
         when Keymap.Cancel_Job =>
            --  Asked as the board is now, not as the screen last showed it.
            if Explore.Jobs.Any_Running (State.Workers.Operations.Status) then
               State.Workers.Operations.Cancel_Running;
               Say (State, Unbounded.To_String (State.Config.Words.Cancelled));
            end if;
         when Keymap.Show_Jobs =>
            State.Interaction.Mode := Viewing_Jobs;
            State.Frame.Panel_Cursor := 1;
            Explore.Application.Display.Fill_Panel (State, State.Workers.Operations.Status);
      end case;
   end Operate;

   procedure Paste (State : in out Session; Links : Boolean) is
      Held   : Interaction_State renames State.Interaction;
      Queued : Boolean;
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
          Id      => 0),
         Queued);

      --  What was cut is gone from where it was once pasted; a paste the
      --  queue had no room for keeps it, to paste again.
      if Queued and then Held.Cutting and then not Links then
         Held.Clipboard.Clear;
         Held.Cutting := False;
      end if;
   end Paste;

   procedure Perform (State : in out Session; Item : Keymap.Command) is
   begin
      case Item.Kind is
         when Keymap.No_Action =>
            null;
         when Keymap.Quit =>
            --  Quitting stops what is copying, moving or deleting, so ask
            --  first. The board is asked as it is now: a paste typed just
            --  before is on it, though the screen has not shown it yet.
            if Explore.Jobs.Any_Active (State.Workers.Operations.Status) then
               Ask (State, Confirming_Quit, Unbounded.To_String (State.Config.Words.Confirm_Quit));
            else
               State.Quit := True;
            end if;
         when Navigation_Action =>
            Navigate (State, Item);
         when Listing_Action =>
            Change_Listing (State, Item);
         when Operation_Action =>
            Operate (State, Item);
         when Program_Action =>
            Use_Programs (State, Item);
      end case;
   end Perform;

   procedure Queue_Job (State : in out Session; Item : Explore.Jobs.Job; Queued : out Boolean) is
   begin
      State.Workers.Operations.Submit (Item, Queued);

      if not Queued then
         Warn (State, Unbounded.To_String (State.Config.Words.Queue_Full));
      end if;
   end Queue_Job;

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

   procedure Take_Clipboard (State : in out Session; Cutting : Boolean) is
      Held : Interaction_State renames State.Interaction;
   begin
      Held.Clipboard := Model.Targets (State.Browser);
      Held.Cutting := Cutting;
      Model.Clear_Marks (State.Browser);

      if not Held.Clipboard.Is_Empty then
         Say (State, Explore.Words.Taken (State.Config.Words, Natural (Held.Clipboard.Length), Cutting));
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

   procedure Use_Programs (State : in out Session; Item : Keymap.Command) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      case Program_Action'(Item.Kind) is
         when Keymap.Open_Entries =>
            Programs.Open_Targets (State);
         when Keymap.Shell_Command =>
            State.Interaction.Pending := Model.Targets (State.Browser);
            Open_Prompt (State, Shelling, State.Config.Words.Shell_Prompt);
         when Keymap.Spawn_Shell =>
            Programs.Run_Program
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
   end Use_Programs;
end Explore.Application.Controller;
