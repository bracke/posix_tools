with Explore.Application.Controller.Programs;
with Explore.Files;
with Explore.Launch;
with Explore.Line_Editor;
with Explore.Model;
with Explore.Modes;
with Explore.Paths;
with Explore.String_Vectors;
with Explore.Words;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;

package body Explore.Application.Controller.Prompts is
   use Explore.Modes;

   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;
   package Modes renames Posix_Tools.Text.File_Modes;

   use type Explore.Keymap.Action;

   --  Carry out what was typed into the prompt the session is in.
   procedure Commit (State : in out Session);

   --  Give the entries in Pending the permissions Text says, octal or
   --  symbolic.
   procedure Commit_Mode (State : in out Session; Text : String);

   --  Rename the entry in Pending to Text, or create Text: a directory when
   --  it ends in a slash, an empty file otherwise.
   procedure Commit_Name (State : in out Session; Text : String)
     with Pre => Text'Length > 0;

   --  Whether a running or waiting operation touches any of Paths; if one
   --  does, the status line says so.
   function In_Use (State : in out Session; Paths : Explore.String_Vectors.Vector) return Boolean;

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
      Octal  : constant Boolean := Parsed.Status = Modes.Octal_Permission_Mode;
   begin
      if Parsed.Status = Modes.Invalid_Permission_Mode then
         Warn (State, Text & ": " & Unbounded.To_String (State.Config.Words.Invalid_Mode));
         return;
      elsif In_Use (State, State.Interaction.Pending) then
         return;
      end if;

      for Path of State.Interaction.Pending loop
         declare
            Known : Boolean;
            Old   : constant Natural := FS.File_Permission_Bits (Path, Known) mod 8#10000#;
         begin
            --  A symbolic mode changes the mode there is: one that cannot be
            --  read is not taken to be zero.
            if not Octal and then not Known then
               Complain (State, Path, Posix_Tools.File_Operations.Cannot_Read);
            else
               declare
                  Applied : constant Modes.Symbolic_Mode_Result :=
                    (if Octal then (Valid => True, Mode => Parsed.Mode) else Modes.Apply_Symbolic_Mode (Text, Old));
               begin
                  if not Applied.Valid then
                     Warn (State, Text & ": " & Unbounded.To_String (State.Config.Words.Invalid_Mode));
                     return;
                  elsif not FS.Set_Permissions (Path, Applied.Mode) then
                     Complain (State, Path, Posix_Tools.File_Operations.Cannot_Open);
                  end if;
               end;
            end if;
         end;
      end loop;

      Model.Clear_Marks (State.Browser);
      Model.Reload (State.Browser, Model.Current_Pane);
   end Commit_Mode;

   procedure Commit_Name (State : in out Session; Text : String) is
      Current   : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Root      : constant String := Unbounded.To_String (Current.Path);
      Is_Rename : constant Boolean := State.Interaction.Mode = Renaming;
      Directory : constant Boolean := State.Interaction.Mode = Creating and then Text (Text'Last) = '/';
      Name      : constant String := (if Directory then Text (Text'First .. Text'Last - 1) else Text);
      Source    : constant String := (if Is_Rename then State.Interaction.Pending.First_Element else "");
      --  A rename stays in the directory of what it renames, which in search
      --  results is not the directory shown.
      Folder    : constant String := (if Is_Rename then Explore.Paths.Parent_Of (Source) else Root);
      Target    : constant String := Explore.Paths.Child_Of (Folder, Name);
      Touched   : Explore.String_Vectors.Vector := Explore.String_Vectors.To_Vector (Target, 1);
      Written   : Boolean := True;
   begin
      if Is_Rename then
         Touched.Append (Source);
      end if;

      if not Explore.Paths.Is_Plain_Name (Name) then
         Complain (State, Text, Posix_Tools.File_Operations.Cannot_Open);
         return;
      elsif FS.Exists (Target) or else FS.Is_Link (Target) then
         Warn (State, Name & ": " & Unbounded.To_String (State.Config.Words.Exists));
         return;
      elsif In_Use (State, Touched) then
         return;
      end if;

      if Is_Rename then
         Written := FS.Rename (Source, Target);
      elsif Directory then
         Written := FS.Create_Path (Target);
      else
         FS.Write_File (Target, "", Append_Mode => True, Ok => Written);
      end if;

      if not Written then
         Complain (State, Target, Posix_Tools.File_Operations.Cannot_Open);
         return;
      end if;

      --  A search result is shown by its new name at once, and looked up
      --  again with the rest once its search has ended.
      if Is_Rename then
         Model.Rename_Result (State.Browser, Explore.Paths.Below (Source, Root), Explore.Paths.Below (Target, Root));
      end if;

      --  The cursor goes to what was made once the directory is read again.
      Model.Reload (State.Browser, Model.Current_Pane);

      if Folder = Root then
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

   function In_Use (State : in out Session; Paths : Explore.String_Vectors.Vector) return Boolean is
   begin
      if not State.Workers.Operations.Touches (Paths) then
         return False;
      end if;

      Warn
        (State,
         Explore.Paths.Name_Of (Paths.First_Element) & ": " & Unbounded.To_String (State.Config.Words.In_Use));
      return True;
   end In_Use;

   procedure Jump_To (State : in out Session; Text : String) is
      Path      : constant String :=
        Explore.Paths.Resolve
          (Text,
           Current => Unbounded.To_String (State.Browser.Panes (Model.Current_Pane).Path),
           Home    => Unbounded.To_String (State.Config.Home));
      Directory : Unbounded.Unbounded_String;
      Name      : Unbounded.Unbounded_String;
      Found     : Boolean;
   begin
      Explore.Files.Locate (Path, Directory, Name, Found);

      if Found then
         Model.Jump (State.Browser, Unbounded.To_String (Directory), Unbounded.To_String (Name));
      else
         Complain (State, Text, Posix_Tools.File_Operations.Not_A_Directory);
      end if;
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
