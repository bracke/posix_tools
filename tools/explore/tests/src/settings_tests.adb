with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Explore.Files;
with Explore.Input;
with Explore.Keymap;
with Explore.Launch;
with Explore.Previews;
with Explore.Screen;
with Explore.Settings;
with Explore.String_Vectors;
with Explore.Themes;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Host_Adapters.Processes;

package body Settings_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Keymap renames Explore.Keymap;
   package Settings renames Explore.Settings;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Keymap.Action;
   use type Explore.Screen.Color;
   use type Explore.Settings.Problem_Kind;
   use type Posix_Tools.File_Operations.Listing.Sort_Key;

   LF  : constant Character := Character'Val (10);
   ESC : constant Character := Character'Val (27);

   function Key (Code : Wide_Wide_Character; Control : Boolean := False) return Explore.Input.Event is
     (Kind   => Explore.Input.Key_Event,
      Key    => Explore.Input.Character_Key,
      Code   => Code,
      Number => 0,
      Mods   => (Control => Control, others => False));

   --  What the keys Keys mean, one after another, from State.
   function Meaning (State : in out Keymap.State; Keys : Wide_Wide_String) return Keymap.Action;

   function Meaning (State : in out Keymap.State; Keys : Wide_Wide_String) return Keymap.Action is
      Result : Keymap.Command;
   begin
      for Code of Keys loop
         Keymap.Translate (State, Key (Code), Result);
      end loop;

      return Result.Kind;
   end Meaning;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("settings:bindings", Test_Bindings'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("settings:configuration", Test_Configuration'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("settings:problems", Test_Problems'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("settings:bookmarks", Test_Bookmarks'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("launch:openers", Test_Openers'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("launch:shell", Test_Shell'Access));
      return Result;
   end Suite;

   procedure Test_Bindings (T : in out Fixture) is
      pragma Unreferenced (T);
      State   : Keymap.State;
      Command : Keymap.Command;
      Ok      : Boolean;
      First, Second : Keymap.Key_Spec;
      Has_Second    : Boolean;
   begin
      AUnit.Assertions.Assert (Meaning (State, "j") = Keymap.Move_Down, "the default j");
      AUnit.Assertions.Assert (Meaning (State, "gg") = Keymap.Move_Top, "the default gg");
      AUnit.Assertions.Assert (Meaning (State, "cc") = Keymap.Copy_Path, "cc copies paths");

      Keymap.Bind (State, "j", "move_up", Ok);
      AUnit.Assertions.Assert (Ok and then Meaning (State, "j") = Keymap.Move_Up, "a bound key comes first");
      Keymap.Bind (State, "j", "none", Ok);
      AUnit.Assertions.Assert (Ok and then Meaning (State, "j") = Keymap.No_Action, "a key bound to nothing");
      Keymap.Bind (State, "g h", "go_home", Ok);
      AUnit.Assertions.Assert (Ok and then Meaning (State, "gh") = Keymap.Go_Home, "a bound sequence");
      AUnit.Assertions.Assert
        (Meaning (State, "gg") = Keymap.Move_Top and then Keymap.Pending (State) = "",
         "the default sequence of the same prefix still works");

      Keymap.Bind (State, "g h", "go_back", Ok);
      AUnit.Assertions.Assert (Meaning (State, "gh") = Keymap.Go_Back, "binding the same keys again replaces");

      Keymap.Bind (State, "ctrl-E", "sort_entries:size_descending", Ok);
      Keymap.Translate (State, Key ('e', Control => True), Command);
      AUnit.Assertions.Assert
        (Ok and then Command.Kind = Keymap.Sort_Entries
         and then Command.Key = Posix_Tools.File_Operations.Listing.By_Size and then Command.Descending,
         "a control key with its unshifted letter, and a sort with its order");

      Keymap.Parse_Command ("switch_tab:3", Command, Ok);
      AUnit.Assertions.Assert (Ok and then Command.Number = 3, "a tab number");
      Keymap.Parse_Command ("go_bookmark:x", Command, Ok);
      AUnit.Assertions.Assert (Ok and then Command.Letter = 'x', "a bookmark letter");

      Keymap.Parse_Command ("Move_Down", Command, Ok);
      AUnit.Assertions.Assert (not Ok, "names are lower case");
      Keymap.Parse_Command ("move_down:2", Command, Ok);
      AUnit.Assertions.Assert (not Ok, "no argument where none is taken");
      Keymap.Parse_Command ("sort_entries:colour", Command, Ok);
      AUnit.Assertions.Assert (not Ok, "an unknown sort key");
      Keymap.Parse_Command ("no_action", Command, Ok);
      AUnit.Assertions.Assert (not Ok, "no_action is spelled none");

      Keymap.Parse_Keys ("alt-f5", First, Second, Has_Second, Ok);
      AUnit.Assertions.Assert
        (Ok and then not Has_Second and then First.Alt and then First.Number = 5
         and then Explore.Input."=" (First.Key, Explore.Input.Function_Key),
         "a named key with a modifier");
      Keymap.Parse_Keys ("space ä", First, Second, Has_Second, Ok);
      AUnit.Assertions.Assert
        (Ok and then Has_Second and then First.Code = ' ' and then Second.Code = Wide_Wide_Character'Val (16#E4#),
         "space by name, and a character beyond ASCII");
      Keymap.Parse_Keys ("ctrl-", First, Second, Has_Second, Ok);
      AUnit.Assertions.Assert (not Ok, "a modifier without a key");
      Keymap.Parse_Keys ("f13", First, Second, Has_Second, Ok);
      AUnit.Assertions.Assert (not Ok, "no thirteenth function key");
   end Test_Bindings;

   procedure Test_Bookmarks (T : in out Fixture) is
      pragma Unreferenced (T);
      Root  : constant String := Ada.Directories.Current_Directory & "/obj/bookmark-fixture";
      Marks : Settings.Bookmark_Maps.Map;
      Ok    : Boolean;
   begin
      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;

      Marks.Include ('b', Unbounded.To_Unbounded_String ("/usr/lib"));
      Marks.Include ('a', Unbounded.To_Unbounded_String ("/home/user/with space"));
      AUnit.Assertions.Assert
        (Settings.Bookmarks_Image (Marks) = "a /home/user/with space" & LF & "b /usr/lib" & LF, "one line each, in order");
      AUnit.Assertions.Assert
        (Settings.Bookmark_Maps."=" (Settings.Bookmarks_Value ("a /home/user/with space" & LF & "junk" & LF & "% /x" & LF
                                                 & "b /usr/lib"), Marks),
         "read back, skipping lines that are not bookmarks, the last without its line feed");

      Settings.Write_Bookmarks (Root & "/deep/explore/bookmarks", Marks, Ok);
      AUnit.Assertions.Assert (Ok, "written, its directories made");
      AUnit.Assertions.Assert
        (Settings.Bookmark_Maps."=" (Settings.Read_Bookmarks (Root & "/deep/explore/bookmarks"), Marks), "and read again");
      AUnit.Assertions.Assert (Settings.Read_Bookmarks (Root & "/missing").Is_Empty, "no file, no bookmarks");

      AUnit.Assertions.Assert
        (Settings.Bookmarks_Path ("/state", "/home/u") = "/state/explore/bookmarks"
         and then Settings.Bookmarks_Path ("", "/home/u") = "/home/u/.local/state/explore/bookmarks"
         and then Settings.Bookmarks_Path ("relative", "/home/u") = "/home/u/.local/state/explore/bookmarks"
         and then Settings.Bookmarks_Path ("", "") = "",
         "the state directory, by XDG");
      AUnit.Assertions.Assert
        (Settings.Configuration_Path ("/cfg", "/home/u") = "/cfg/explore/config.toml"
         and then Settings.Configuration_Path ("", "/home/u") = "/home/u/.config/explore/config.toml",
         "the configuration directory, by XDG");
   end Test_Bookmarks;

   procedure Test_Configuration (T : in out Fixture) is
      pragma Unreferenced (T);
      Loaded   : Settings.Settings;
      Problems : Settings.Problem_Vectors.Vector;
   begin
      Settings.Parse
        ("[options]" & LF
         & "show_hidden = true" & LF
         & "sort = ""modified""" & LF
         & "sort_descending = true" & LF
         & "thumbnails = false" & LF
         & "[keys]" & LF
         & """J"" = ""move_bottom""" & LF
         & "[theme]" & LF
         & "directory = { fg = ""bright_green"", bg = 17, underline = true }" & LF
         & "[[open]]" & LF
         & "match = [""*.pdf"", ""*.epub""]" & LF
         & "run = 'zathura ""$@""'" & LF
         & "detach = true" & LF
         & "[[preview]]" & LF
         & "match = ""*.md""" & LF
         & "run = 'glow ""$1""'" & LF,
         Loaded, Problems);

      AUnit.Assertions.Assert (Problems.Is_Empty, "read without problems");
      AUnit.Assertions.Assert
        (Loaded.Show_Hidden and then Loaded.Descending and then not Loaded.Thumbnails
         and then Loaded.Sort_Key = Posix_Tools.File_Operations.Listing.By_Modified,
         "options");
      AUnit.Assertions.Assert
        (Loaded.Colors (Explore.Themes.Directory_Role).Foreground = 10
         and then Loaded.Colors (Explore.Themes.Directory_Role).Background = 17
         and then Loaded.Colors (Explore.Themes.Directory_Role).Underline
         and then not Loaded.Colors (Explore.Themes.Directory_Role).Bold,
         "a theme entry replaces the role's style");
      AUnit.Assertions.Assert
        (Explore.Screen."=" (Loaded.Colors (Explore.Themes.Link_Role),
                             Explore.Themes.Default_Theme (Explore.Themes.Link_Role)),
         "roles left out keep their defaults");
      AUnit.Assertions.Assert
        (Explore.Themes.Role_Name (Explore.Themes.Header_Role) = "header"
         and then Explore.Themes.Role_Name (Explore.Themes.Inactive_Cursor_Role) = "inactive_cursor",
         "roles are named without their suffix");
      AUnit.Assertions.Assert (Meaning (Loaded.Keys, "J") = Keymap.Move_Bottom, "keys");
      AUnit.Assertions.Assert
        (Natural (Loaded.Openers.Length) = 1 and then Natural (Loaded.Openers (1).Patterns.Length) = 2
         and then Loaded.Openers (1).Detach
         and then Unbounded.To_String (Loaded.Openers (1).Run) = "zathura ""$@""",
         "an opener");
      AUnit.Assertions.Assert
        (Natural (Loaded.Previewers.Length) = 1 and then Loaded.Previewers (1).Patterns (1) = "*.md", "a previewer");

      Settings.Parse ("", Loaded, Problems);
      AUnit.Assertions.Assert
        (Problems.Is_Empty and then not Loaded.Show_Hidden and then Loaded.Thumbnails, "an empty file is the defaults");
   end Test_Configuration;

   procedure Test_Openers (T : in out Fixture) is
      pragma Unreferenced (T);
      Openers : Explore.Launch.Opener_Vectors.Vector;
      Pdf     : Explore.Launch.Opener := (Run => Unbounded.To_Unbounded_String ("zathura"), Detach => True, others => <>);
   begin
      Pdf.Patterns.Append ("*.pdf");
      Openers.Append (Pdf);

      AUnit.Assertions.Assert
        (Unbounded.To_String (Explore.Launch.Opener_For (Openers, "Paper.PDF", False).Run) = "zathura",
         "a pattern matches whatever the case");
      AUnit.Assertions.Assert
        (Unbounded.To_String (Explore.Launch.Opener_For (Openers, "notes.txt", True).Run) = Explore.Launch.Text_Opener
         and then not Explore.Launch.Opener_For (Openers, "notes.txt", True).Detach,
         "text goes to the editor, in the terminal");
      AUnit.Assertions.Assert
        (Unbounded.To_String (Explore.Launch.Opener_For (Openers, "photo.raw", False).Run)
         = Explore.Launch.Other_Opener and then Explore.Launch.Opener_For (Openers, "photo.raw", False).Detach,
         "anything else to the desktop, apart");

      AUnit.Assertions.Assert
        (Explore.Launch.Clipboard ("hi", In_Tmux => False) = ESC & "]52;c;aGk=" & ESC & "\", "OSC 52");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Explore.Launch.Clipboard ("hi", In_Tmux => True), ESC & "Ptmux;") = 1,
         "passed through tmux");

      AUnit.Assertions.Assert
        (Explore.Previews.Without_Controls ("a" & ESC & "[1;31mb" & ESC & "]0;title" & Character'Val (7) & "c"
                                            & Character'Val (8) & ESC & "]8;;x" & ESC & "\d" & LF)
         = "abcd" & LF,
         "colours, titles, links, and backspaces are taken out");
   end Test_Openers;

   procedure Test_Problems (T : in out Fixture) is
      pragma Unreferenced (T);
      Loaded   : Settings.Settings;
      Problems : Settings.Problem_Vectors.Vector;

      function Has (Kind : Settings.Problem_Kind; Where : String) return Boolean is
        (for some Item of Problems => Item.Kind = Kind and then Unbounded.To_String (Item.Where) = Where);
   begin
      Settings.Parse ("[options" & LF, Loaded, Problems);
      AUnit.Assertions.Assert (Has (Settings.Syntax_Error, "line 1"), "not TOML, with its line");

      Settings.Parse
        ("colour = 1" & LF
         & "[options]" & LF
         & "show_hidden = ""yes""" & LF
         & "sort = ""size_descending""" & LF
         & "speed = 3" & LF
         & "[keys]" & LF
         & """ctrl-x"" = ""fly""" & LF
         & """k"" = ""move_up""" & LF
         & "[theme]" & LF
         & "sky = { fg = ""blue"" }" & LF
         & "cursor = { fg = ""mauve"", bold = true }" & LF
         & "[[open]]" & LF
         & "match = ""*.x""" & LF
         & "[[preview]]" & LF
         & "run = ""cat""" & LF,
         Loaded, Problems);

      AUnit.Assertions.Assert (Has (Settings.Unknown_Setting, "colour"), "an unknown table");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "options.show_hidden"), "a string for a boolean");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "options.sort"), "the order is its own option");
      AUnit.Assertions.Assert (Has (Settings.Unknown_Setting, "options.speed"), "an unknown option");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "keys.ctrl-x"), "an unknown action");
      AUnit.Assertions.Assert (Has (Settings.Unknown_Setting, "theme.sky"), "an unknown role");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "theme.cursor.fg"), "an unknown colour");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "open[1].run"), "an opener without a command");
      AUnit.Assertions.Assert (Has (Settings.Bad_Value, "preview[1].match"), "a previewer for every file");
      AUnit.Assertions.Assert (Natural (Problems.Length) = 9, "nothing else");
      AUnit.Assertions.Assert
        (Meaning (Loaded.Keys, "k") = Keymap.Move_Up and then Loaded.Colors (Explore.Themes.Cursor_Role).Bold
         and then Loaded.Openers.Is_Empty and then Loaded.Previewers.Is_Empty,
         "what could be read is kept");
   end Test_Problems;

   procedure Test_Shell (T : in out Fixture) is
      pragma Unreferenced (T);
      Root   : constant String := Ada.Directories.Current_Directory & "/obj/shell fixture";
      Files  : Explore.String_Vectors.Vector;
      Status : Integer;
      Text   : Unbounded.Unbounded_String;
      Ok     : Boolean;
   begin
      Ada.Directories.Create_Path (Root);
      Files.Append ("it's ""quoted""");
      Files.Append ("$(touch pwned) and spaces");

      AUnit.Assertions.Assert
        (Posix_Tools.Host_Adapters.Processes.Run
           (Explore.Launch.Shell,
            Explore.Launch.Shell_Arguments (Root, "printf '%s|' ""$#"" ""$@"" > out", Files),
            Status)
         and then Status = 0,
         "run in the shell");

      Explore.Files.Read_Head (Root & "/out", 1024, Text, Ok);
      AUnit.Assertions.Assert
        (Ok and then Unbounded.To_String (Text) = "2|it's ""quoted""|$(touch pwned) and spaces|",
         "in the directory, the files as parameters, never as text of the command");
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Root & "/pwned"), "nothing in a name runs");

      Ok := Posix_Tools.Host_Adapters.Processes.Run
        (Explore.Launch.Shell, Explore.Launch.Shell_Arguments (Root & "/missing", "true", Files), Status);
      AUnit.Assertions.Assert
        (not Ok and then Status = 126, "a directory that cannot be entered runs nothing, as a shell reports it");
   end Test_Shell;
end Settings_Tests;
