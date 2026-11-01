with Explore.Application.Display;
with Explore.Jobs;
with Explore.Model;
with Explore.Paths;
with Explore.Previews;
with Explore.Search;
with Explore.String_Vectors;
with Explore.Words;
with Posix_Tools.Host_Adapters.File_Watches;

package body Explore.Application.Workers is
   package File_Watches renames Posix_Tools.Host_Adapters.File_Watches;
   package Model renames Explore.Model;

   use type Explore.Jobs.Question_Step;
   use type Explore.Jobs.Snapshot;
   use type Explore.Jobs.Version_Number;
   use type Explore.Previews.Preview_Kind;

   --  Ask, ask again, or take down the question of the job that asks in Now,
   --  as Explore.Jobs.Question_Step_For says.
   procedure Follow_Question (State : in out Session; Now : Explore.Jobs.Snapshot; Can_Ask : Boolean);

   --  The names of Item's entries, in their order.
   function Names_Of (Item : Model.Pane) return Explore.String_Vectors.Vector;

   --  Read again what the jobs changed, and say how the latest that ended
   --  went.
   procedure Report_Ended (State : in out Session; Now : Explore.Jobs.Snapshot);

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

   procedure Follow_Question (State : in out Session; Now : Explore.Jobs.Snapshot; Can_Ask : Boolean) is
      Lane : constant Natural := Explore.Jobs.Asking_Lane (Now);
      Step : constant Explore.Jobs.Question_Step :=
        Explore.Jobs.Question_Step_For
          (Asking => Lane > 0, Can_Ask => Can_Ask, Answering => State.Interaction.Mode = Answering);
   begin
      State.Workers.Question_Waiting := Step = Explore.Jobs.Hold;

      case Step is
         when Explore.Jobs.Ask_Now | Explore.Jobs.Ask_Again =>
            declare
               Question : constant String :=
                 Explore.Words.Conflict_Question
                   (Unbounded.To_String (State.Config.Locale),
                    Explore.Paths.Name_Of (Unbounded.To_String (Now.Lanes (Lane).Conflict)));
            begin
               if Step = Explore.Jobs.Ask_Again then
                  State.Frame.Question := Unbounded.To_Unbounded_String (Question);
               else
                  Ask (State, Answering, Question);
               end if;

               State.Workers.Asked_About := Now.Lanes (Lane).Conflict;
            end;
         when Explore.Jobs.Take_Down =>
            Leave_Mode (State);
         when Explore.Jobs.Leave_Alone | Explore.Jobs.Hold =>
            null;
      end case;
   end Follow_Question;

   function Names_Of (Item : Model.Pane) return Explore.String_Vectors.Vector is
   begin
      return Result : Explore.String_Vectors.Vector do
         for Listed of Item.Entries loop
            Result.Append (Unbounded.To_String (Listed.Name));
         end loop;
      end return;
   end Names_Of;

   procedure Release_Watches (State : in out Session) is
   begin
      for Watched in Watched_Pane loop
         File_Watches.Release (State.Workers.Watches (Watched));
         State.Workers.Watching (Watched) := Unbounded.Null_Unbounded_String;
      end loop;
   end Release_Watches;

   procedure Report_Ended (State : in out Session; Now : Explore.Jobs.Snapshot) is
      use type Explore.Jobs.Outcome;
   begin
      Model.Reload_All (State.Browser);

      if Now.History.Is_Empty then
         return;
      end if;

      declare
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
   end Report_Ended;

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
                   Order      => State.Browser.Order,
                   Look_Again => Item.Is_Search,
                   Names      => (if Item.Is_Search then Names_Of (Item) else Explore.String_Vectors.Empty_Vector)));
               State.Workers.Submitted (Kind) := Item.Generation;
            elsif not Item.Pending and then State.Workers.Submitted (Kind) /= 0 then
               --  Nothing is waited for: a read still running, as for a pane
               --  that went empty or was replaced, is stopped, and what it
               --  would hand back is dropped.
               Readers.Cancel (Kind);
               State.Workers.Submitted (Kind) := 0;
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

      --  Whether a question can be asked now, rather than waiting. The
      --  filter, which is typed as the panes are browsed, does not keep it
      --  waiting.
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
         Now : constant Explore.Jobs.Snapshot := State.Workers.Operations.Status;
      begin
         if Now = State.Workers.Last_Job and then not Overdue then
            return;
         end if;

         State.Dirty := True;
         State.Frame.Job_Line := Unbounded.To_Unbounded_String (Explore.Words.Job_Line (State.Config.Words, Now));
         Follow_Question (State, Now, Can_Ask);

         --  Whatever the jobs changed is read again, and the latest one to
         --  end says how it went.
         if Now.Completed /= State.Workers.Last_Job.Completed then
            Report_Ended (State, Now);
         end if;

         if State.Interaction.Mode = Viewing_Jobs then
            Explore.Application.Display.Fill_Panel (State, Now);
         end if;

         State.Workers.Last_Job := Now;
      end;
   end Watch_Jobs;

   procedure Watch_Preview (State : in out Session) is
      use type Unbounded.Unbounded_String;

      Shown  : Model.Pane renames State.Browser.Panes (Model.Preview_Pane);
      Wanted : constant Natural := Model.File_Preview (State.Browser);
      Ready  : Explore.Previews.Preview;
      Found  : Boolean;
   begin
      if Wanted /= State.Workers.Preview_Asked then
         State.Workers.Preview_Asked := Wanted;

         --  The same file's preview stays shown while it is built again;
         --  another file's is not shown in its place meanwhile.
         if Wanted = 0 or else State.Frame.Preview.Path /= Shown.Path then
            State.Frame.Preview := (others => <>);
            Explore.Application.Display.Hide_Image (State);
         end if;

         if Wanted = 0 then
            --  A preview no longer wanted is stopped, a previewer it runs too.
            State.Workers.Previewer.Cancel (Explore.Previews.Only);
         else
            State.Workers.Previewer.Submit
              (Explore.Previews.Only,
               (Path       => Shown.Path,
                Rules      => State.Config.Previewers,
                Thumbnails => State.Config.Thumbnails,
                Generation => Wanted));
         end if;
      end if;

      State.Workers.Previewer.Collect (Explore.Previews.Only, Ready, Found);

      if Found and then Wanted > 0 and then Ready.Generation = Wanted then
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
      --  The search runs for the current pane's generation, whose results it
      --  takes; a newer one, as when a tab is gone back to, replaces it.
      if Current.Is_Search and then State.Browser.Search_Wanted then
         State.Browser.Search_Wanted := False;
         State.Workers.Searcher.Submit
           (Explore.Search.Only,
            (Root           => Current.Path,
             Pattern        => State.Browser.Search_Label,
             Kind           =>
               (if State.Browser.Search_Contents then Explore.Search.By_Content else Explore.Search.By_Name),
             Include_Hidden => State.Browser.Show_Hidden,
             Generation     => Current.Generation));
      end if;

      if not Model.Search_Running (State.Browser) then
         --  Gone elsewhere, or ended: what the search would find has nowhere
         --  to go.
         if State.Workers.Searcher.Busy then
            State.Workers.Searcher.Cancel (Explore.Search.Only);
         end if;

         return;
      end if;

      State.Workers.Searcher.Collect (Explore.Search.Only, Results, Found);

      if Found and then Results.Generation = Current.Generation then
         Model.Add_Results (State.Browser, Results.Generation, Results.Found, Results.Finished);
         State.Dirty := True;

         if Results.Finished then
            Say
              (State,
               Explore.Words.Search_Result
                 (State.Config.Words, Natural (Current.Entries.Length), Results.Truncated));
         end if;
      end if;
   end Watch_Search;
end Explore.Application.Workers;
