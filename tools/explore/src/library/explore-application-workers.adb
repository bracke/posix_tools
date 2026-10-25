with Explore.Application.Display;
with Explore.Jobs;
with Explore.Model;
with Explore.Paths;
with Explore.Previews;
with Explore.Search;
with Explore.Words;
with Posix_Tools.Host_Adapters.File_Watches;

package body Explore.Application.Workers is
   package File_Watches renames Posix_Tools.Host_Adapters.File_Watches;
   package Model renames Explore.Model;

   use type Explore.Jobs.Snapshot;
   use type Explore.Jobs.Version_Number;
   use type Explore.Previews.Preview_Kind;

   function Busy (State : Session; Readers : in out Explore.Directory_Readers.Board) return Boolean is
     (Readers.Busy
      or else Explore.Jobs.Any_Running (State.Workers.Last_Job)
      or else State.Workers.Previewer.Busy
      or else State.Workers.Searcher.Busy);

   procedure Collect (State : in out Session; Readers : in out Explore.Directory_Readers.Board) is
      Outcome : Explore.Directory_Readers.Result;
      Found   : Boolean;
   begin
      for Kind in Model.Pane_Kind loop
         Readers.Collect (Kind, Outcome, Found);

         if Found then
            Model.Deliver (State.Browser, Kind, Outcome.Generation, Outcome.Entries, Outcome.Readable);
            State.Dirty := True;
         end if;
      end loop;
   end Collect;

   procedure Release_Watches (State : in out Session) is
   begin
      for Watched in Watched_Pane loop
         File_Watches.Release (State.Workers.Watches (Watched));
         State.Workers.Watching (Watched) := Unbounded.Null_Unbounded_String;
      end loop;
   end Release_Watches;

   procedure Sync (State : in out Session; Readers : in out Explore.Directory_Readers.Board) is
      use type Unbounded.Unbounded_String;
   begin
      if Model.Preview_Changed (State.Browser) then
         State.Dirty := True;
      end if;

      for Kind in Model.Pane_Kind loop
         declare
            Item : Model.Pane renames State.Browser.Panes (Kind);
         begin
            if Item.Pending and then Item.Generation /= State.Workers.Submitted (Kind) then
               Readers.Submit
                 (Kind,
                  (Path       => Item.Path,
                   Generation => Item.Generation,
                   Options    => (Include_Hidden => State.Browser.Show_Hidden, With_Status => True),
                   Order      => State.Browser.Order));
               State.Workers.Submitted (Kind) := Item.Generation;
            end if;
         end;
      end loop;

      for Watched in Watched_Pane loop
         declare
            Path : constant Unbounded.Unbounded_String := State.Browser.Panes (Pane_Of (Watched)).Path;
         begin
            if Path /= State.Workers.Watching (Watched) then
               File_Watches.Release (State.Workers.Watches (Watched));
               State.Workers.Watching (Watched) := Path;

               if Unbounded.Length (Path) > 0 then
                  File_Watches.Watch_Path (State.Workers.Watches (Watched), Unbounded.To_String (Path));
               end if;
            end if;
         end;
      end loop;
   end Sync;

   procedure Watch_Files (State : in out Session) is
   begin
      for Watched in Watched_Pane loop
         if File_Watches.Changed (State.Workers.Watches (Watched)) then
            Model.Reload (State.Browser, Pane_Of (Watched));
         end if;
      end loop;
   end Watch_Files;

   procedure Watch_Jobs (State : in out Session) is
      Version : constant Explore.Jobs.Version_Number := State.Workers.Operations.Version;

      --  Whether a question can be asked now, rather than waiting.
      Can_Ask : constant Boolean := State.Interaction.Mode in Browsing | Filtering | Viewing_Jobs;
      Overdue : constant Boolean := State.Workers.Question_Waiting and then Can_Ask;
   begin
      --  Most passes nothing changed, and the board says so without a
      --  snapshot being taken.
      if Version = State.Workers.Job_Version and then not Overdue then
         return;
      end if;

      State.Workers.Job_Version := Version;

      declare
         Now  : constant Explore.Jobs.Snapshot := State.Workers.Operations.Status;
         Lane : constant Natural := Explore.Jobs.Asking_Lane (Now);
         Mode : constant Interaction_Mode := State.Interaction.Mode;
      begin
         if Now = State.Workers.Last_Job and then not Overdue then
            return;
         end if;

         State.Dirty := True;
         State.Frame.Job_Line := Unbounded.To_Unbounded_String (Explore.Words.Job_Line (State.Config.Words, Now));

         --  A question waits until what is being typed or confirmed is done
         --  with: the job it is about waits for its answer meanwhile. The
         --  filter, which is typed as the panes are browsed, does not keep it
         --  waiting.
         State.Workers.Question_Waiting := Lane > 0 and then not Can_Ask and then Mode /= Answering;

         if Lane > 0 and then (Can_Ask or else Mode = Answering) then
            declare
               Question : constant String :=
                 Explore.Words.Conflict_Question
                   (Unbounded.To_String (State.Config.Locale),
                    Explore.Paths.Name_Of (Unbounded.To_String (Now.Lanes (Lane).Conflict)));
            begin
               --  Already answering: the job was answered and has asked again
               --  before the last question was taken down, so the new one
               --  takes its place.
               if Mode = Answering then
                  State.Frame.Question := Unbounded.To_Unbounded_String (Question);
               else
                  Ask (State, Answering, Question);
               end if;

               State.Workers.Asked_About := Now.Lanes (Lane).Conflict;
            end;
         elsif Lane = 0 and then Mode = Answering then
            Leave_Mode (State);
         end if;

         if Now.Completed /= State.Workers.Last_Job.Completed then
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
                        Warn
                          (State,
                           Explore.Words.Errors_With_First
                             (State.Config.Words, Latest.Errors, Unbounded.To_String (State.Frame.Message)));
                     end if;
                  else
                     Say (State, Explore.Words.Result_Line (State.Config.Words, Latest));
                  end if;
               end;
            end if;
         end if;

         if State.Interaction.Mode = Viewing_Jobs then
            Explore.Application.Display.Fill_Panel (State, Now);
         end if;

         State.Workers.Last_Job := Now;
      end;
   end Watch_Jobs;

   procedure Watch_Preview (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Target  : constant String :=
        (if Model.Has_Selection (Current) and then not Model.Can_Enter (State.Browser)
         then Model.Selected_Path (Current) else "");
      Ready   : Explore.Previews.Preview;
      Found   : Boolean;
   begin
      if Target /= Unbounded.To_String (State.Workers.Previewing) then
         State.Workers.Previewing := Unbounded.To_Unbounded_String (Target);
         State.Frame.Preview := (others => <>);
         Explore.Application.Display.Hide_Image (State);

         if Target'Length > 0 then
            State.Workers.Preview_Generation := State.Workers.Preview_Generation + 1;
            State.Workers.Previewer.Submit
              (Explore.Previews.Only,
               (Path       => Unbounded.To_Unbounded_String (Target),
                Rules      => State.Config.Previewers,
                Thumbnails => State.Config.Thumbnails,
                Generation => State.Workers.Preview_Generation));
         end if;
      end if;

      State.Workers.Previewer.Collect (Explore.Previews.Only, Ready, Found);

      if Found and then Ready.Generation = State.Workers.Preview_Generation then
         State.Frame.Preview := Ready;
         State.Dirty := True;

         if Ready.Kind = Explore.Previews.Image_Preview then
            Explore.Application.Display.Show_Image (State);
         end if;
      end if;
   end Watch_Preview;

   procedure Watch_Search (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Results : Explore.Search.Progress;
      Found   : Boolean;
   begin
      if Current.Is_Search and then State.Browser.Search_Wanted then
         State.Browser.Search_Wanted := False;
         State.Workers.Search_Generation := Current.Generation;
         State.Workers.Search_Found := 0;
         State.Workers.Searcher.Submit
           (Explore.Search.Only,
            (Root           => Current.Path,
             Pattern        => State.Browser.Search_Label,
             Kind           =>
               (if State.Browser.Search_Contents then Explore.Search.By_Content else Explore.Search.By_Name),
             Include_Hidden => State.Browser.Show_Hidden,
             Generation     => Current.Generation));
      end if;

      if not Current.Is_Search or else Current.Generation /= State.Workers.Search_Generation then
         --  Gone elsewhere: what the search would find has nowhere to go.
         if State.Workers.Searcher.Busy then
            State.Workers.Searcher.Cancel (Explore.Search.Only);
         end if;

         return;
      end if;

      State.Workers.Searcher.Collect (Explore.Search.Only, Results, Found);

      if Found and then Results.Generation = State.Workers.Search_Generation then
         State.Workers.Search_Found := State.Workers.Search_Found + Natural (Results.Found.Length);
         Model.Add_Results (State.Browser, Results.Generation, Results.Found, Results.Finished);
         State.Dirty := True;

         if Results.Finished then
            Say
              (State,
               Explore.Words.Search_Result (State.Config.Words, State.Workers.Search_Found, Results.Truncated));
         end if;
      end if;
   end Watch_Search;
end Explore.Application.Workers;
