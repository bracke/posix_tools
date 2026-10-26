with Ada.Strings.Unbounded;
with Explore.Jobs;
with Explore.Render;
with Explore.Settings;
with Explore.String_Vectors;

--  What explore says, put together from the interface text of the user's
--  locale. Each text is looked up once, when the session starts, since a
--  catalog lookup reads the catalog; everything here after that is plain
--  formatting.
package Explore.Words is
   --  Interface text for operations. A field said to be a pattern holds its
   --  placeholders, as "{count}", for the functions below to fill in.
   type Word_Set is record
      Rename_Prompt : Ada.Strings.Unbounded.Unbounded_String;
      Create_Prompt : Ada.Strings.Unbounded.Unbounded_String;
      Mode_Prompt   : Ada.Strings.Unbounded.Unbounded_String;
      Copying       : Ada.Strings.Unbounded.Unbounded_String;
      Moving        : Ada.Strings.Unbounded.Unbounded_String;
      Linking       : Ada.Strings.Unbounded.Unbounded_String;
      Deleting      : Ada.Strings.Unbounded.Unbounded_String;
      --  Patterns of {count}.
      Yanked        : Ada.Strings.Unbounded.Unbounded_String;
      Cut           : Ada.Strings.Unbounded.Unbounded_String;
      Queue_Full    : Ada.Strings.Unbounded.Unbounded_String;
      Cancelled     : Ada.Strings.Unbounded.Unbounded_String;
      Confirm_Quit  : Ada.Strings.Unbounded.Unbounded_String;
      Exists        : Ada.Strings.Unbounded.Unbounded_String;
      Invalid_Mode  : Ada.Strings.Unbounded.Unbounded_String;
      --  Patterns: of {count}; of {done} and {what}; of {verb} and {what},
      --  and {count} too; and of {count} and the {message} of the first.
      Errors        : Ada.Strings.Unbounded.Unbounded_String;
      Done_Line     : Ada.Strings.Unbounded.Unbounded_String;
      Cancel_Line   : Ada.Strings.Unbounded.Unbounded_String;
      Failed_Line   : Ada.Strings.Unbounded.Unbounded_String;
      Errors_First  : Ada.Strings.Unbounded.Unbounded_String;
      Copied        : Ada.Strings.Unbounded.Unbounded_String;
      Moved         : Ada.Strings.Unbounded.Unbounded_String;
      Linked        : Ada.Strings.Unbounded.Unbounded_String;
      Deleted       : Ada.Strings.Unbounded.Unbounded_String;
      Queued        : Ada.Strings.Unbounded.Unbounded_String;
      No_Jobs       : Ada.Strings.Unbounded.Unbounded_String;
      Jobs_Title    : Ada.Strings.Unbounded.Unbounded_String;
      Jump_Prompt   : Ada.Strings.Unbounded.Unbounded_String;
      Names_Prompt  : Ada.Strings.Unbounded.Unbounded_String;
      Text_Prompt   : Ada.Strings.Unbounded.Unbounded_String;
      Searching     : Ada.Strings.Unbounded.Unbounded_String;
      --  Patterns of {count}.
      Found         : Ada.Strings.Unbounded.Unbounded_String;
      Too_Many      : Ada.Strings.Unbounded.Unbounded_String;
      Bookmarked    : Ada.Strings.Unbounded.Unbounded_String;
      No_Bookmark   : Ada.Strings.Unbounded.Unbounded_String;
      Unsaved       : Ada.Strings.Unbounded.Unbounded_String;
      Shell_Prompt  : Ada.Strings.Unbounded.Unbounded_String;
      Press_Enter   : Ada.Strings.Unbounded.Unbounded_String;
      --  A pattern of {status}.
      Exit_Status   : Ada.Strings.Unbounded.Unbounded_String;
      Cannot_Run    : Ada.Strings.Unbounded.Unbounded_String;
      Clipped       : Ada.Strings.Unbounded.Unbounded_String;
      No_Clipboard  : Ada.Strings.Unbounded.Unbounded_String;
      Configuration : Ada.Strings.Unbounded.Unbounded_String;
      Not_TOML      : Ada.Strings.Unbounded.Unbounded_String;
      --  The word before the number of the line a syntax error is on.
      Line          : Ada.Strings.Unbounded.Unbounded_String;
      Unknown       : Ada.Strings.Unbounded.Unbounded_String;
      Bad_Value     : Ada.Strings.Unbounded.Unbounded_String;
      Unreadable    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  The text of operations, and of a frame, in Locale.
   function Load (Locale : String) return Word_Set;
   function Load_Labels (Locale : String) return Explore.Render.Labels;

   --  What a job of Kind is doing, as "copying".
   function Verb_Of (Words : Word_Set; Kind : Explore.Jobs.Job_Kind) return String;

   --  The progress line of a running job.
   function Lane_Line (Words : Word_Set; Lane : Explore.Jobs.Lane_View) return String;

   --  What became of an ended job, as one line.
   function Result_Line (Words : Word_Set; Item : Explore.Jobs.Result_View) return String;

   --  How many errors a job met, as "3 errors".
   function Error_Count (Words : Word_Set; Count : Natural) return String;

   --  How many errors a job met, and Message about the first of them.
   function Errors_With_First (Words : Word_Set; Count : Natural; Message : String) return String;

   --  How many entries were yanked, or cut.
   function Taken (Words : Word_Set; Count : Natural; Cutting : Boolean) return String;

   --  What a program that ended with Status is said to have done.
   function Exit_Line (Words : Word_Set; Status : Natural) return String;

   --  The jobs as the status line shows them: the first running one in full,
   --  and how many more run or wait. Empty when none runs.
   function Job_Line (Words : Word_Set; Now : Explore.Jobs.Snapshot) return String;

   --  The lines of the jobs panel, running jobs first, then waiting ones,
   --  then those that ended, the latest first; and for each line the job it
   --  stands for, zero for a line that stands for none.
   procedure Panel
     (Words : Word_Set;
      Now   : Explore.Jobs.Snapshot;
      Lines : out Explore.String_Vectors.Vector;
      Ids   : out Explore.Render.Id_Vectors.Vector);

   --  The first of Problems, and how many more there are.
   function Configuration_Problem
     (Words    : Word_Set;
      Problems : Explore.Settings.Problem_Vectors.Vector) return String
     with Pre => not Problems.Is_Empty;

   --  How a search that found Found entries ended.
   function Search_Result (Words : Word_Set; Found : Natural; Truncated : Boolean) return String;

   --  The question that confirms deleting Count entries, in Locale.
   function Confirm_Delete (Locale : String; Count : Natural) return String;

   --  The question a job asks about Name, a target that exists, in Locale.
   function Conflict_Question (Locale : String; Name : String) return String;
end Explore.Words;
