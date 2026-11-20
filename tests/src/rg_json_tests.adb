with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Rg.Json;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Json_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String := "") return Run_Outcome;
   function Natural_Image (Value : Natural) return String;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String := "") return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Json_Output (T : in out Fixture) is
      pragma Unreferenced (T);
      LF   : constant Character := ASCII.LF;
      Path : constant String := Test_Support.Work_Path ("rg-json.txt");
      Byte_Path : constant String := Test_Support.Work_Path ("rg-json-") & Character'Val (255);
      UTF8_Path : constant String := Test_Support.Work_Path ("rg-json-utf8.txt");
   begin
      Test_Support.Write_File (Path, "hit one" & LF & "middle" & LF & "hit hit" & LF);
      Test_Support.Write_File (Byte_Path, "hit" & LF);
      Test_Support.Write_File
        (UTF8_Path, "caf" & Character'Val (16#C3#) & Character'Val (16#A9#) & " hit" & LF);

      declare
         Normal : constant Run_Outcome := Run_Rg (["--json", "hit", Path]);
         Text   : constant String := To_String (Normal.Output);
         First_Submatch : constant String :=
           Posix_Tools.Commands.Rg.Json.Submatch ("hit", 0, 3);
         Two_Submatches : constant String :=
           First_Submatch & ',' & Posix_Tools.Commands.Rg.Json.Submatch ("hit", 4, 7);
         Expected_Printed : constant Natural :=
           Posix_Tools.Commands.Rg.Json.Begin_Event (Path)'Length + 1
           + Posix_Tools.Commands.Rg.Json.Line_Event
             ("match", Path, "hit one", True, 1, 0, First_Submatch)'Length + 1
           + Posix_Tools.Commands.Rg.Json.Line_Event
             ("match", Path, "hit hit", True, 3, 15, Two_Submatches)'Length + 1;
      begin
         AUnit.Assertions.Assert
           (Normal.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (Text, "{""type"":""begin"",""data"":{""path"":{""text"":""" & Path & """}}}" & LF)
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""hit one\n""},""line_number"":1,""absolute_offset"":0,"
               & """submatches"":[{""match"":{""text"":""hit""},""start"":0,""end"":3}]")
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""hit hit\n""},""line_number"":3,""absolute_offset"":15,"
               & """submatches"":[{""match"":{""text"":""hit""},""start"":0,""end"":3},"
               & "{""match"":{""text"":""hit""},""start"":4,""end"":7}]")
            and then Test_Support.Contains (Text, "{""type"":""end"",""data"":")
            and then Test_Support.Contains
              (Text, """bytes_printed"":" & Natural_Image (Expected_Printed))
            and then Test_Support.Contains (Text, """matches"":3}}}" & LF)
            and then Test_Support.Contains (Text, """type"":""summary""}" & LF),
            "JSON emits begin, match, end, and summary events with byte offsets");
      end;

      declare
         Context_Result : constant Run_Outcome := Run_Rg (["--json", "-C1", "middle", Path]);
         Inverted       : constant Run_Outcome := Run_Rg (["--json", "-v", "hit", Path]);
         Only_Matching  : constant Run_Outcome := Run_Rg (["--json", "-o", "hit", Path]);
         Replacement   : constant Run_Outcome := Run_Rg (["--json", "--replace", "<$0>", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Context_Result.Output), "{""type"":""context""")
            and then Test_Support.Contains
              (To_String (Context_Result.Output), """absolute_offset"":0,""submatches"":[]")
            and then Test_Support.Contains
              (To_String (Context_Result.Output), """absolute_offset"":15,""submatches"":[]"),
            "JSON context events preserve record offsets and have no submatches");
         AUnit.Assertions.Assert
           (Inverted.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Inverted.Output), """submatches"":[]"),
            "inverted JSON selections do not invent submatches");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Only_Matching.Output), """text"":""hit one\n""")
            and then Test_Support.Contains (To_String (Only_Matching.Output), """start"":0,""end"":3"),
            "--only-matching retains reference JSON line events");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Replacement.Output), """replacement"":{""text"":""<hit>""}"),
            "replacement text is attached to each JSON submatch");
      end;

      declare
         No_Match : constant Run_Outcome := Run_Rg (["--json", "absent", Path]);
         Quiet    : constant Run_Outcome := Run_Rg (["--json", "-q", "hit", Path]);
         Counted  : constant Run_Outcome := Run_Rg (["--json", "-c", "hit", Path]);
         Disabled : constant Run_Outcome := Run_Rg (["--json", "--no-json", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (No_Match.Status = Posix_Tools.Exit_Status.Operational_Failure
            and then not Test_Support.Contains (To_String (No_Match.Output), """type"":""begin""")
            and then Test_Support.Contains (To_String (No_Match.Output), """type"":""summary""}"),
            "a no-match JSON search emits only its summary");
         AUnit.Assertions.Assert
           (not Test_Support.Contains (To_String (Quiet.Output), """type"":""match""")
            and then Test_Support.Contains (To_String (Quiet.Output), """type"":""summary""}")
            and then Test_Support.Contains (To_String (Quiet.Output), """matches"":3"),
            "quiet JSON suppresses records while retaining complete statistics");
         AUnit.Assertions.Assert
           (To_String (Counted.Output) = "2" & LF
            and then not Test_Support.Contains (To_String (Disabled.Output), """type"":"),
            "count modes stay textual and --no-json restores normal output");
      end;

      declare
         Bytes         : constant Run_Outcome := Run_Rg (["--json", "hit", Byte_Path]);
         UTF8          : constant Run_Outcome := Run_Rg (["--json", "hit", UTF8_Path]);
      begin
         AUnit.Assertions.Assert
           (Bytes.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Bytes.Output), """path"":{""bytes"":"),
            "non-UTF-8 JSON payloads use base64 byte values");
         AUnit.Assertions.Assert
           (UTF8.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (UTF8.Output),
               """lines"":{""text"":""caf" & Character'Val (16#C3#) & Character'Val (16#A9#) & " hit\n""}"),
            "valid multibyte JSON payloads remain UTF-8 text values");
      end;

      declare
         Data : constant String :=
           "zero" & LF & "before" & LF & "xxfoo" & LF & "barzz" & LF & "after" & LF & "last" & LF;
         Pattern : constant String := "foo" & LF & "bar";
         Spanning : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "-C1", Pattern], Data);
         Only_Matching : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "-o", Pattern], Data);
         Replaced : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "--replace", "<$0>", Pattern], Data);
         Inverted : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "-v", Pattern], "foo" & LF & "bar" & LF & "none" & LF);
         Adjacent : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "-e", "foo", "-e", "bar"], "foo" & LF & "bar" & LF);
         Empty_Matches : constant Run_Outcome :=
           Run_Rg (["--json", "-U", "^"], "ab" & LF & "cd" & LF);
         Disjoint_Context : constant Run_Outcome :=
           Run_Rg
             (["--json", "-C1", "hit"],
              "hit" & LF & "one" & LF & "two" & LF & "three" & LF & "hit" & LF);
         Text : constant String := To_String (Spanning.Output);
      begin
         AUnit.Assertions.Assert
           (Spanning.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""xxfoo\nbarzz\n""},""line_number"":3,"
               & """absolute_offset"":12,""submatches"":["
               & "{""match"":{""text"":""foo\nbar""},""start"":2,""end"":9}]")
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""before\n""},""line_number"":2,"
               & """absolute_offset"":5,""submatches"":[]")
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""after\n""},""line_number"":5,"
               & """absolute_offset"":24,""submatches"":[]")
            and then Test_Support.Contains (Text, """matched_lines"":2")
            and then Test_Support.Contains (Text, """matches"":1")
            and then not Test_Support.Contains (Text, LF & "barzz" & LF),
            "multiline JSON emits one match event for the complete spanning record block");
         AUnit.Assertions.Assert
           (Only_Matching.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Only_Matching.Output),
               """lines"":{""text"":""xxfoo\nbarzz\n""}")
            and then Replaced.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Replaced.Output),
               """replacement"":{""text"":""<foo\nbar>""}"),
            "multiline JSON keeps whole-line events for match-only and attaches replacements");
         AUnit.Assertions.Assert
           (Inverted.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Inverted.Output),
               """lines"":{""text"":""none\n""},""line_number"":3,"
               & """absolute_offset"":8,""submatches"":[]")
            and then Test_Support.Occurrences
              (To_String (Adjacent.Output), """type"":""match""") = 2,
            "multiline JSON supports inversion and keeps independent adjacent matches separate");
         AUnit.Assertions.Assert
           (Empty_Matches.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Empty_Matches.Output),
               """lines"":{""text"":""ab\ncd\n""},""line_number"":1,"
               & """absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""""},""start"":0,""end"":0},"
               & "{""match"":{""text"":""""},""start"":3,""end"":3}]")
            and then not Test_Support.Contains
              (To_String (Empty_Matches.Output), LF & "cd" & LF)
            and then not Test_Support.Contains
              (To_String (Disjoint_Context.Output), LF & "--" & LF),
            "zero-length multiline matches are bounded and JSON context has no raw separators");
      end;

      declare
         NUL : constant Character := ASCII.NUL;
         Data : constant String := "before" & NUL & "hit hit" & NUL & "after" & NUL & "tail hit";
         Normal : constant Run_Outcome := Run_Rg (["--json", "--null-data", "hit"], Data);
         Context_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--null-data", "-C1", "hit"], Data);
         Inverted : constant Run_Outcome :=
           Run_Rg (["--json", "--null-data", "-v", "hit"], "hit" & NUL & "miss" & NUL);
         Replaced : constant Run_Outcome :=
           Run_Rg (["--json", "--null-data", "--replace", "<$0>", "hit"], "hit" & NUL);
         Text : constant String := To_String (Normal.Output);
      begin
         AUnit.Assertions.Assert
           (Normal.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""hit hit\u0000""},""line_number"":2,"
               & """absolute_offset"":7,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":0,""end"":3},"
               & "{""match"":{""text"":""hit""},""start"":4,""end"":7}]")
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""tail hit""},""line_number"":4,"
               & """absolute_offset"":21,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":5,""end"":8}]")
            and then Test_Support.Contains (Text, """bytes_searched"":29")
            and then Test_Support.Contains (Text, """matches"":3"),
            "NUL-data JSON preserves escaped delimiters, final records, offsets, and statistics");
         AUnit.Assertions.Assert
           (Context_Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Context_Result.Output),
               """lines"":{""text"":""before\u0000""},""line_number"":1,"
               & """absolute_offset"":0,""submatches"":[]")
            and then Test_Support.Contains
              (To_String (Context_Result.Output),
               """lines"":{""text"":""after\u0000""},""line_number"":3,"
               & """absolute_offset"":15,""submatches"":[]"),
            "NUL-data JSON context events preserve record delimiters and offsets");
         AUnit.Assertions.Assert
           (Inverted.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Inverted.Output),
               """lines"":{""text"":""miss\u0000""},""line_number"":2,"
               & """absolute_offset"":4,""submatches"":[]")
            and then Replaced.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Replaced.Output), """replacement"":{""text"":""<hit>""}"),
            "NUL-data JSON supports inverted selection and replacements");
      end;

      declare
         NUL : constant Character := ASCII.NUL;
         Binary : constant Run_Outcome :=
           Run_Rg (["--json", "hit"], "before" & NUL & "hit" & LF);
         Text : constant String := To_String (Binary.Output);
      begin
         AUnit.Assertions.Assert
           (Binary.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (Text,
               """lines"":{""text"":""before\u0000hit\n""},""line_number"":1,")
            and then Test_Support.Contains (Text, """binary_offset"":6")
            and then not Test_Support.Contains (Text, "binary file matches"),
            "JSON searches NUL-bearing input and reports the first binary offset");
      end;

      Test_Support.Delete_If_Exists (Path);
      Test_Support.Delete_If_Exists (Byte_Path);
      Test_Support.Delete_If_Exists (UTF8_Path);
   end Test_Json_Output;
end Rg_Json_Tests;
