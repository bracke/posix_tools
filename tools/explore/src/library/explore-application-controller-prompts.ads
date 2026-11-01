with Explore.Input;
with Explore.Keymap;

--  The line typed at the foot of the screen, and what Enter does with it:
--  rename, create, change permissions, go to a path, search, or run a shell
--  command. Renaming, creating and changing permissions happen at once, on
--  the screen's thread, but never to a path a running or waiting operation
--  touches.
private package Explore.Application.Controller.Prompts is
   --  Open the prompt for Kind -- a rename, a creation, or a permission
   --  change -- when there is something for it to act on.
   procedure Ask_For_Name (State : in out Session; Kind : Explore.Keymap.Action)
     with Pre => Kind in Explore.Keymap.Rename_Entry | Explore.Keymap.Create_Entry | Explore.Keymap.Change_Mode;

   --  Type Item into the prompt, committing it on Enter.
   procedure Edit_Prompt (State : in out Session; Item : Explore.Input.Event);

   --  Go to the directory Text names: absolute, relative to the current
   --  one, or from the home directory with a leading ~; a file is gone to
   --  in its directory, with the cursor on it.
   procedure Jump_To (State : in out Session; Text : String)
     with Pre => Text'Length > 0;
end Explore.Application.Controller.Prompts;
