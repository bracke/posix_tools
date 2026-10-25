with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Jobs;
with Explore.Render;
with Explore.Settings;
with Explore.String_Vectors;
with Explore.Words;

package body Words_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Jobs renames Explore.Jobs;
   package Unbounded renames Ada.Strings.Unbounded;

   function "+" (Text : String) return Unbounded.Unbounded_String renames Unbounded.To_Unbounded_String;

   Words : constant Explore.Words.Word_Set :=
     (Copying       => +"copying",
      Deleting      => +"deleting",
      Copied        => +"copied",
      Deleted       => +"deleted",
      Cancelled     => +"cancelled",
      Errors        => +"errors",
      Queued        => +"waiting",
      No_Jobs       => +"no operations",
      Configuration => +"configuration",
      Unknown       => +"unknown setting",
      others        => +"?");

   function Running (Id, Total, Done : Natural; Current : String; Copied, Size : Long_Long_Integer := 0)
     return Jobs.Lane_View
   is ((Running => True,
        Job     => (Id => Id, Kind => Jobs.Copy_Job, First => +"first", Total => Total),
        Done    => Done,
        Current => +Current,
        Copied  => Copied,
        Size    => Size,
        others  => <>));

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("words:lane line", Test_Lane_Line'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("words:result line", Test_Result_Line'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("words:job line", Test_Job_Line'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("words:panel", Test_Panel'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("words:configuration problem", Test_Configuration_Problem'Access));
      return Result;
   end Suite;

   procedure Test_Configuration_Problem (T : in out Fixture) is
      pragma Unreferenced (T);
      Problems : Explore.Settings.Problem_Vectors.Vector;
   begin
      Problems.Append
        (Explore.Settings.Problem'(Kind => Explore.Settings.Unknown_Setting, Where => +"options.colour"));
      AUnit.Assertions.Assert
        (Explore.Words.Configuration_Problem (Words, Problems) = "configuration: unknown setting options.colour",
         "one problem: " & Explore.Words.Configuration_Problem (Words, Problems));
      Problems.Append (Explore.Settings.Problem'(Kind => Explore.Settings.Bad_Value, Where => +"keys.x"));
      Problems.Append (Explore.Settings.Problem'(Kind => Explore.Settings.Bad_Value, Where => +"keys.y"));
      AUnit.Assertions.Assert
        (Explore.Words.Configuration_Problem (Words, Problems)
         = "configuration: unknown setting options.colour (+2)",
         "the first, and how many more: " & Explore.Words.Configuration_Problem (Words, Problems));
   end Test_Configuration_Problem;

   procedure Test_Job_Line (T : in out Fixture) is
      pragma Unreferenced (T);
      Now : Jobs.Snapshot;
   begin
      AUnit.Assertions.Assert (Explore.Words.Job_Line (Words, Now) = "", "nothing runs");
      Now.Lanes (2) := Running (1, 3, 0, "/a/one");
      AUnit.Assertions.Assert (Explore.Words.Job_Line (Words, Now) = "copying 1/3 one", "one runs");
      Now.Lanes (1) := Running (2, 1, 0, "/b/two");
      Now.Queued.Append (Jobs.Job_View'(Id => 3, Kind => Jobs.Delete_Job, First => +"x", Total => 1));
      AUnit.Assertions.Assert
        (Explore.Words.Job_Line (Words, Now) = "copying 1/1 two +2",
         "the first in full, and how many more run or wait: " & Explore.Words.Job_Line (Words, Now));
      Now.Lanes := [others => <>];
      AUnit.Assertions.Assert (Explore.Words.Job_Line (Words, Now) = "", "waiting alone is not running");
   end Test_Job_Line;

   procedure Test_Lane_Line (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Explore.Words.Lane_Line (Words, Running (1, 4, 1, "/src/big.iso", 250, 1000)) = "copying 2/4 big.iso 25%",
         "with progress: " & Explore.Words.Lane_Line (Words, Running (1, 4, 1, "/src/big.iso", 250, 1000)));
      AUnit.Assertions.Assert
        (Explore.Words.Lane_Line (Words, Running (1, 2, 2, "/src/last")) = "copying 2/2 last",
         "the count stops at the total, and no size means no percentage");
   end Test_Lane_Line;

   procedure Test_Panel (T : in out Fixture) is
      pragma Unreferenced (T);
      Now   : Jobs.Snapshot;
      Lines : Explore.String_Vectors.Vector;
      Ids   : Explore.Render.Id_Vectors.Vector;
   begin
      Explore.Words.Panel (Words, Now, Lines, Ids);
      AUnit.Assertions.Assert
        (Natural (Lines.Length) = 1 and then Lines (1) = "  no operations" and then Ids (1) = 0, "no jobs");

      Now.Lanes (1) := Running (7, 1, 0, "/a/f");
      Now.Queued.Append (Jobs.Job_View'(Id => 8, Kind => Jobs.Delete_Job, First => +"old", Total => 3));
      Now.History.Append
        (Jobs.Result_View'(Job => (Id => 5, Kind => Jobs.Copy_Job, First => +"x", Total => 1), others => <>));
      Now.History.Append
        (Jobs.Result_View'
           (Job => (Id => 6, Kind => Jobs.Delete_Job, First => +"y", Total => 1), Ended => Jobs.Cancelled,
            others => <>));
      Explore.Words.Panel (Words, Now, Lines, Ids);
      AUnit.Assertions.Assert (Natural (Lines.Length) = 4, "a line for each job");
      AUnit.Assertions.Assert (Lines (1) = "> copying 1/1 f" and then Ids (1) = 7, "running: " & Lines (1));
      AUnit.Assertions.Assert (Lines (2) = "  waiting: deleting old +2" and then Ids (2) = 8, "waiting: " & Lines (2));
      AUnit.Assertions.Assert
        (Lines (3) = "  deleting y: cancelled" and then Ids (3) = 0, "the latest ended first: " & Lines (3));
      AUnit.Assertions.Assert (Lines (4) = "  copied x" and then Ids (4) = 0, "then the one before: " & Lines (4));
   end Test_Panel;

   procedure Test_Result_Line (T : in out Fixture) is
      pragma Unreferenced (T);
      Job : constant Jobs.Job_View := (Id => 1, Kind => Jobs.Delete_Job, First => +"a", Total => 3);
   begin
      AUnit.Assertions.Assert
        (Explore.Words.Result_Line (Words, (Job => Job, Ended => Jobs.Succeeded, others => <>)) = "deleted a +2",
         "succeeded");
      AUnit.Assertions.Assert
        (Explore.Words.Result_Line (Words, (Job => Job, Ended => Jobs.Cancelled, others => <>))
         = "deleting a +2: cancelled",
         "cancelled");
      AUnit.Assertions.Assert
        (Explore.Words.Result_Line (Words, (Job => Job, Ended => Jobs.Failed, Errors => 4, others => <>))
         = "deleting a +2: 4 errors",
         "failed");
   end Test_Result_Line;
end Words_Tests;
