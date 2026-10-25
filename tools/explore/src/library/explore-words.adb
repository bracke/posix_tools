with Ada.Strings.Fixed;
with Explore.Paths;
with Posix_Tools.Localization;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Words is
   package Unbounded renames Ada.Strings.Unbounded;

   use type Explore.Settings.Problem_Kind;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  Pattern with each placeholder "{Name_N}" given its Value_N, in one
   --  pass: a value is never looked into for placeholders of its own, and a
   --  placeholder not named is left as it is.
   function Fill
     (Pattern : Unbounded.Unbounded_String;
      Name_1  : String;
      Value_1 : String;
      Name_2  : String := "";
      Value_2 : String := "";
      Name_3  : String := "";
      Value_3 : String := "") return String;

   --  Which job, by its first entry, and how many more it has.
   function What_Of (Item : Explore.Jobs.Job_View) return String is
     (Unbounded.To_String (Item.First) & (if Item.Total > 1 then " +" & Image (Item.Total - 1) else ""));

   function Configuration_Problem
     (Words    : Word_Set;
      Problems : Explore.Settings.Problem_Vectors.Vector) return String
   is
      First : constant Explore.Settings.Problem := Problems.First_Element;
   begin
      return Unbounded.To_String (Words.Configuration) & ": "
        & Unbounded.To_String
            (case First.Kind is
               when Explore.Settings.Unreadable_File => Words.Unreadable,
               when Explore.Settings.Syntax_Error => Words.Not_TOML,
               when Explore.Settings.Unknown_Setting => Words.Unknown,
               when Explore.Settings.Bad_Value => Words.Bad_Value)
        & " "
        & (if First.Kind = Explore.Settings.Syntax_Error
           then Unbounded.To_String (Words.Line) & " " & Image (First.Line)
           else Unbounded.To_String (First.Where))
        & (if Problems.Last_Index > 1 then " (+" & Image (Problems.Last_Index - 1) & ")" else "");
   end Configuration_Problem;

   function Confirm_Delete (Locale : String; Count : Natural) return String is
   begin
      return Posix_Tools.Localization.Text_1
        (Locale, "posix_tools.explore.ui.confirm_delete", "count", Image (Count),
         "delete " & Image (Count) & "? y/n");
   end Confirm_Delete;

   function Conflict_Question (Locale : String; Name : String) return String is
   begin
      return Posix_Tools.Localization.Text_1
        (Locale, "posix_tools.explore.ui.conflict", "path", Name,
         Name & " exists: o overwrite, s skip, O overwrite all, S skip all");
   end Conflict_Question;

   function Error_Count (Words : Word_Set; Count : Natural) return String is
     (Fill (Words.Errors, "count", Image (Count)));

   function Errors_With_First (Words : Word_Set; Count : Natural; Message : String) return String is
     (Fill (Words.Errors_First, "count", Image (Count), "message", Message));

   function Exit_Line (Words : Word_Set; Status : Natural) return String is
     (Fill (Words.Exit_Status, "status", Image (Status)));

   function Fill
     (Pattern : Unbounded.Unbounded_String;
      Name_1  : String;
      Value_1 : String;
      Name_2  : String := "";
      Value_2 : String := "";
      Name_3  : String := "";
      Value_3 : String := "") return String
   is
      Text   : constant String := Unbounded.To_String (Pattern);
      Result : Unbounded.Unbounded_String;
      I      : Positive := Text'First;
   begin
      while I <= Text'Last loop
         declare
            Close : constant Natural :=
              (if Text (I) = '{' then Ada.Strings.Fixed.Index (Text (I .. Text'Last), "}") else 0);
            Name  : constant String := (if Close > 0 then Text (I + 1 .. Close - 1) else "");
         begin
            if Close > 0 and then Name'Length > 0 and then Name in Name_1 | Name_2 | Name_3 then
               Unbounded.Append
                 (Result, (if Name = Name_1 then Value_1 elsif Name = Name_2 then Value_2 else Value_3));
               I := Close + 1;
            else
               Unbounded.Append (Result, Text (I));
               I := I + 1;
            end if;
         end;
      end loop;

      return Unbounded.To_String (Result);
   end Fill;

   function Job_Line (Words : Word_Set; Now : Explore.Jobs.Snapshot) return String is
      Running : Natural := 0;
      Line    : Unbounded.Unbounded_String;
      Waiting : constant Natural := Natural (Now.Queued.Length);
   begin
      for Lane of Now.Lanes loop
         if Lane.Running then
            Running := Running + 1;

            if Running = 1 then
               Line := Unbounded.To_Unbounded_String (Lane_Line (Words, Lane));
            end if;
         end if;
      end loop;

      if Running + Waiting > 1 and then Running > 0 then
         Unbounded.Append (Line, " +" & Image (Running - 1 + Waiting));
      end if;

      return Unbounded.To_String (Line);
   end Job_Line;

   function Lane_Line (Words : Word_Set; Lane : Explore.Jobs.Lane_View) return String is
      Percent : constant String :=
        (if Lane.Size > 0
         then " " & Image (Natural (Long_Long_Integer'Min (100, Lane.Copied * 100 / Lane.Size))) & "%"
         else "");
   begin
      return Verb_Of (Words, Lane.Job.Kind) & " " & Image (Natural'Min (Lane.Done + 1, Lane.Job.Total)) & "/"
        & Image (Lane.Job.Total) & " " & Explore.Paths.Name_Of (Unbounded.To_String (Lane.Current)) & Percent;
   end Lane_Line;

   function Load (Locale : String) return Word_Set is
      function Word (Key, Default : String) return Unbounded.Unbounded_String is
        (Unbounded.To_Unbounded_String
           (Posix_Tools.Localization.Text (Locale, "posix_tools.explore.ui." & Key, Default)));

      --  A text with the placeholders Names in it, to fill in later.
      function Pattern (Key, Names, Default : String) return Unbounded.Unbounded_String is
        (Unbounded.To_Unbounded_String
           (Posix_Tools.Localization.Pattern (Locale, "posix_tools.explore.ui." & Key, Names, Default)));
   begin
      return
        (Rename_Prompt => Word ("prompt.rename", "rename to"),
         Create_Prompt => Word ("prompt.create", "create (end with / for a directory)"),
         Mode_Prompt   => Word ("prompt.mode", "permissions"),
         Copying       => Word ("job.copying", "copying"),
         Moving        => Word ("job.moving", "moving"),
         Linking       => Word ("job.linking", "linking"),
         Deleting      => Word ("job.deleting", "deleting"),
         Yanked        => Pattern ("yanked", "count", "{count} yanked"),
         Cut           => Pattern ("cut", "count", "{count} cut"),
         Queue_Full    => Word ("queue_full", "too many operations waiting"),
         Cancelled     => Word ("cancelled", "cancelled"),
         Exists        => Word ("exists", "already exists"),
         Invalid_Mode  => Word ("invalid_mode", "not a valid permission mode"),
         Errors        => Pattern ("errors", "count", "{count} errors"),
         Done_Line     => Pattern ("job.done", "done what", "{done} {what}"),
         Cancel_Line   => Pattern ("job.cancelled", "verb what", "{verb} {what}: cancelled"),
         Failed_Line   => Pattern ("job.failed", "verb what count", "{verb} {what}: {count} errors"),
         Errors_First  => Pattern ("job.errors_first", "count message", "{count} errors, {message}"),
         Copied        => Word ("job.copied", "copied"),
         Moved         => Word ("job.moved", "moved"),
         Linked        => Word ("job.linked", "linked"),
         Deleted       => Word ("job.deleted", "deleted"),
         Queued        => Word ("job.queued", "waiting"),
         No_Jobs       => Word ("job.none", "no operations"),
         Jobs_Title    => Word ("job.title", "operations: j/k move, x cancel, w close"),
         Jump_Prompt   => Word ("prompt.jump", "go to"),
         Names_Prompt  => Word ("prompt.find_names", "find names (globs with * ? [ ])"),
         Text_Prompt   => Word ("prompt.find_text", "find text in files"),
         Searching     => Word ("searching", "searching"),
         Found         => Pattern ("found", "count", "{count} found"),
         Too_Many      => Pattern ("too_many", "count", "{count} found, more than were kept"),
         Bookmarked    => Word ("bookmarked", "bookmarked"),
         No_Bookmark   => Word ("no_bookmark", "no such bookmark"),
         Unsaved       => Word ("bookmarks_unsaved", "bookmarks could not be saved"),
         Shell_Prompt  => Word ("prompt.shell", "shell command"),
         Press_Enter   => Word ("press_enter", "press Enter to return to explore"),
         Exit_Status   => Pattern ("exit_status", "status", "exited with status {status}"),
         Cannot_Run    => Word ("cannot_run", "the command did not run to its end"),
         Clipped       => Word ("copied_text", "copied to the clipboard"),
         No_Clipboard  => Word ("no_clipboard", "the terminal offers no clipboard"),
         Configuration => Word ("configuration", "configuration"),
         Not_TOML      => Word ("config.syntax", "not valid TOML at"),
         Line          => Word ("config.line", "line"),
         Unknown       => Word ("config.unknown", "unknown setting"),
         Bad_Value     => Word ("config.bad_value", "invalid value for"),
         Unreadable    => Word ("config.unreadable", "cannot read"));
   end Load;

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

   procedure Panel
     (Words : Word_Set;
      Now   : Explore.Jobs.Snapshot;
      Lines : out Explore.String_Vectors.Vector;
      Ids   : out Explore.Render.Id_Vectors.Vector)
   is
   begin
      Lines.Clear;
      Ids.Clear;

      for Lane of Now.Lanes loop
         if Lane.Running then
            Lines.Append ("> " & Lane_Line (Words, Lane));
            Ids.Append (Lane.Job.Id);
         end if;
      end loop;

      for Waiting of Now.Queued loop
         Lines.Append
           ("  " & Unbounded.To_String (Words.Queued) & ": " & Verb_Of (Words, Waiting.Kind) & " " & What_Of (Waiting));
         Ids.Append (Waiting.Id);
      end loop;

      for I in reverse 1 .. Natural (Now.History.Length) loop
         Lines.Append ("  " & Result_Line (Words, Now.History (I)));
         Ids.Append (0);
      end loop;

      if Lines.Is_Empty then
         Lines.Append ("  " & Unbounded.To_String (Words.No_Jobs));
         Ids.Append (0);
      end if;
   end Panel;

   function Result_Line (Words : Word_Set; Item : Explore.Jobs.Result_View) return String is
      Done : constant String :=
        Unbounded.To_String
          (case Item.Job.Kind is
             when Explore.Jobs.Copy_Job => Words.Copied,
             when Explore.Jobs.Move_Job => Words.Moved,
             when Explore.Jobs.Link_Job => Words.Linked,
             when Explore.Jobs.Delete_Job => Words.Deleted);
      What : constant String := What_Of (Item.Job);
   begin
      case Item.Ended is
         when Explore.Jobs.Succeeded =>
            return Fill (Words.Done_Line, "done", Done, "what", What);
         when Explore.Jobs.Cancelled =>
            return Fill (Words.Cancel_Line, "verb", Verb_Of (Words, Item.Job.Kind), "what", What);
         when Explore.Jobs.Failed =>
            return Fill
              (Words.Failed_Line, "verb", Verb_Of (Words, Item.Job.Kind), "what", What, "count", Image (Item.Errors));
      end case;
   end Result_Line;

   function Search_Result (Words : Word_Set; Found : Natural; Truncated : Boolean) return String is
     (Fill ((if Truncated then Words.Too_Many else Words.Found), "count", Image (Found)));

   function Taken (Words : Word_Set; Count : Natural; Cutting : Boolean) return String is
     (Fill ((if Cutting then Words.Cut else Words.Yanked), "count", Image (Count)));

   function Verb_Of (Words : Word_Set; Kind : Explore.Jobs.Job_Kind) return String is
     (Unbounded.To_String
        (case Kind is
           when Explore.Jobs.Copy_Job => Words.Copying,
           when Explore.Jobs.Move_Job => Words.Moving,
           when Explore.Jobs.Link_Job => Words.Linking,
           when Explore.Jobs.Delete_Job => Words.Deleting));
end Explore.Words;
