with Explore.Application.Sessions;
with Explore.Directory_Readers;

--  Keeping the workers and the screen in step: handing the readers the
--  directories the panes want, taking what the readers, the jobs, the search
--  and the previewer have done, and watching the directories on screen for
--  changes. Each is called once a pass of the main loop, and costs little
--  when nothing changed.
private package Explore.Application.Workers is
   use Explore.Application.Sessions;

   --  Whether any worker has something in hand, so the loop looks again soon.
   function Busy (State : Session; Readers : in out Explore.Directory_Readers.Board) return Boolean;

   --  Hand the panes the entries the readers have read.
   procedure Collect (State : in out Session; Readers : in out Explore.Directory_Readers.Board);

   --  Bring the readers and the watches in line with the panes: point the
   --  preview at the selection, ask for each pane's entries that are wanted
   --  and not yet asked for, and watch the directories on screen.
   procedure Sync (State : in out Session; Readers : in out Explore.Directory_Readers.Board);

   --  Read again a watched directory that changed.
   procedure Watch_Files (State : in out Session);

   --  Stop watching any directory.
   procedure Release_Watches (State : in out Session);

   --  Follow the jobs: their progress line, their questions, and what they
   --  changed.
   procedure Watch_Jobs (State : in out Session);

   --  Point the preview at the selected file, and take a preview that is
   --  ready.
   procedure Watch_Preview (State : in out Session);

   --  Start the search the current pane wants, take the results it has
   --  found, and stop it once the current pane no longer shows it.
   procedure Watch_Search (State : in out Session);
end Explore.Application.Workers;
