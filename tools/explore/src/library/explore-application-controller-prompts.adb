with Explore.Application.Controller.Programs;
with Explore.Launch;
with Explore.Line_Editor;
with Explore.Model;
with Explore.Paths;
with Explore.String_Vectors;
with Explore.Words;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;

package body Explore.Application.Controller.Prompts is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;
   package Modes renames Posix_Tools.Text.File_Modes;

   use type Explore.Keymap.Action;
   use type FS.File_Kind;

   --  Carry out what was typed into the prompt the session is in.
   procedure Commit (State : in out Session);

   --  Give the entries in Pending the permissions Text says, octal or
   --  symbolic.
   procedure Commit_Mode (State : in out Session; Text : String);

   --  Rename the entry in Pending to Text, or create Text: a directory when
   --  it ends in a slash, an empty file otherwise.
   procedure Commit_Name (State : in out Session; Text : String)
     with Pre => Text'Length > 0;

   --  Search below the current directory for Text, by name or by content as
   --  the prompt was for, showing the results in the current pane.
   procedure Start_Search (State : in out Session; Text : String);

   procedure Ask_For_Name (State : in out Session; Kind : Explore.Keymap.Action) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Words   : Explore.Words.Word_Set renames State.Config.Words;
   begin
      if Kind /= Explore.Keymap.Create_Entry and then not Model.Has_Selection (Current) then
         return;
      end if;

      State.Interaction.Pending :=
        (if Kind = Explore.Keymap.Rename_Entry
         then Explore.String_Vectors.To_Vector (Model.Selected_Path (Current), 1)
         else Model.Targets (State.Browser));

      if Kind = Explore.Keymap.Rename_Entry then
         --  A search result is named by its path below the search's root; it
         --  is renamed in its own directory, so the prompt starts at its name.
         Open_Prompt (State, Renaming, Words.Rename_Prompt, Explore.Paths.Name_Of (Model.Selected_Name (Current)));
      elsif Kind = Explore.Keymap.Create_Entry then
         Open_Prompt (State, Creating, Words.Create_Prompt);
      else
         Open_Prompt
           (State,
            Changing_Mode,
            Words.Mode_Prompt,
            Modes.Four_Digit_Octal_Image (Model.Selected (Current).Status.Mode mod 8#10000#));
      end if;
   end Ask_For_Name;

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
            Explore.Application.Controller.Programs.Run_Program
              (State,
               Explore.Launch.Shell_Arguments (Folder, Text, State.Interaction.Pending),
               Detach => False,
               Pause  => True);
         when Browsing | Filtering | Question_Mode | Viewing_Jobs =>
            null;
      end case;
   end Commit;

   procedure Commit_Mode (State : in out Session; Text : String) is
      use type Modes.Permission_Mode_Status;

      Parsed : constant Modes.Parsed_Permission_Mode := Modes.Parse_Permission_Mode (Text);
   begin
      for Path of State.Interaction.Pending loop
         declare
            Known   : Boolean;
            Old     : constant Natural := FS.File_Permission_Bits (Path, Known) mod 8#10000#;
            Applied : constant Modes.Symbolic_Mode_Result :=
              (if Parsed.Status = Modes.Octal_Permission_Mode
               then (Valid => True, Mode => Parsed.Mode)
               else Modes.Apply_Symbolic_Mode (Text, Old));
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
      Is_Rename : constant Boolean := State.Interaction.Mode = Renaming;
      Directory : constant Boolean := State.Interaction.Mode = Creating and then Text (Text'Last) = '/';
      Name      : constant String := (if Directory then Text (Text'First .. Text'Last - 1) else Text);
      --  A rename stays in the directory of what it renames, which in search
      --  results is not the directory shown.
      Folder    : constant String :=
        (if Is_Rename then Explore.Paths.Parent_Of (State.Interaction.Pending.First_Element)
         else Unbounded.To_String (Current.Path));
      Target    : constant String := Explore.Paths.Child_Of (Folder, Name);
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
         if Is_Rename then
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

      if Folder = Unbounded.To_String (Current.Path) then
         Current.Wanted := Unbounded.To_Unbounded_String (Name);
      end if;
   end Commit_Name;
   procedure Edit_Prompt (State : in out Session; Item : Explore.Input.Event) is
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
   procedure Start_Search (State : in out Session; Text : String) is
   begin
      --  The searcher is handed it with the workers, as a search begun again is.
      Model.Begin_Search
        (State.Browser,
         Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path),
         Text,
         Contents => State.Interaction.Mode = Finding_Text);
   end Start_Search;
end Explore.Application.Controller.Prompts;
