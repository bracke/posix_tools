with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Localization;

package body Posix_Tools.Commands.Find_Evaluation.Actions is
   use Ada.Strings.Unbounded;

   function Batch_Position
     (State       : Evaluation_State;
      Start_Index : Positive) return Natural
   is
   begin
      for I in 1 .. Natural (State.Exec_Batches.Length) loop
         if State.Exec_Batches.Element (I).Start_Index = Start_Index then
            return I;
         end if;
      end loop;
      return 0;
   end Batch_Position;

   procedure Append_Exec_Batch_Path
     (State       : in out Evaluation_State;
      Start_Index : Positive;
      Terminator  : Positive;
      Path        : String)
   is
      Position : constant Natural := Batch_Position (State, Start_Index);
      Batch    : Find_Exec_Batch;
   begin
      if Position = 0 then
         Batch.Start_Index := Start_Index;
         Batch.Utility := To_Unbounded_String (State.Expression.Element (Start_Index));
         for J in Start_Index + 1 .. Terminator - 2 loop
            Batch.Prefix.Append (State.Expression.Element (J));
         end loop;
         Batch.Paths.Append (Path);
         State.Exec_Batches.Append (Batch);
      else
         Batch := State.Exec_Batches.Element (Position);
         Batch.Paths.Append (Path);
         State.Exec_Batches.Replace_Element (Position, Batch);
      end if;
   end Append_Exec_Batch_Path;

   function Replaced_Path (Item : String; Path : String) return String is
   begin
      if Item = "{}" then
         return Path;
      else
         return Item;
      end if;
   end Replaced_Path;

   function Execute_Exec
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Index   : in out Positive;
      Active  : Boolean;
      Valid   : in out Boolean) return Boolean
   is
      Start      : constant Positive := Index + 1;
      Terminator : Natural := 0;
      Arguments  : Posix_Tools.Arguments.Vector;
      Exit_Code  : Integer := 0;
   begin
      for J in Start .. Natural (State.Expression.Length) loop
         if State.Expression.Element (J) = ";" or else State.Expression.Element (J) = "+" then
            Terminator := J;
            exit;
         end if;
      end loop;

      if Terminator = 0 or else Terminator = Start then
         Valid := False;
         return False;
      end if;

      Index := Terminator + 1;
      if not Active then
         return False;
      end if;

      if State.Expression.Element (Terminator) = "+" then
         Append_Exec_Batch_Path (State, Start, Terminator, Path);
         return True;
      end if;

      for J in Start + 1 .. Terminator - 1 loop
         Arguments.Append (Replaced_Path (State.Expression.Element (J), Path));
      end loop;

      if Context.Execute_Utility (State.Expression.Element (Start), Arguments, Exit_Code) then
         return Exit_Code = 0;
      else
         return False;
      end if;
   end Execute_Exec;

   function Execute_Ok
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Index   : in out Positive;
      Active  : Boolean;
      Valid   : in out Boolean) return Boolean
   is
      Start      : constant Positive := Index + 1;
      Terminator : Natural := 0;
      Arguments  : Posix_Tools.Arguments.Vector;
      Exit_Code  : Integer := 0;
   begin
      for J in Start .. Natural (State.Expression.Length) loop
         if State.Expression.Element (J) = ";" then
            Terminator := J;
            exit;
         end if;
      end loop;

      if Terminator = 0 or else Terminator = Start then
         Valid := False;
         return False;
      end if;

      Index := Terminator + 1;
      if not Active then
         return False;
      end if;

      Context.Put_Error_Line
        (Posix_Tools.Localization.Text_1
           (Context.Effective_Locale,
            "posix_tools.find.ok.prompt",
            "subject",
            State.Expression.Element (Start) & " ... " & Path,
            "< " & State.Expression.Element (Start) & " ... " & Path & " > ?"));
      if not Posix_Tools.Commands.Helpers.Read_Affirmative_Response
        (Context, Wait_For_Line_End => True)
      then
         return False;
      end if;

      for J in Start + 1 .. Terminator - 1 loop
         Arguments.Append (Replaced_Path (State.Expression.Element (J), Path));
      end loop;

      if Context.Execute_Utility (State.Expression.Element (Start), Arguments, Exit_Code) then
         return Exit_Code = 0;
      else
         return False;
      end if;
   end Execute_Ok;

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean)
   is
      Arguments : Posix_Tools.Arguments.Vector;
      Exit_Code : Integer := 0;
   begin
      for Batch of State.Exec_Batches loop
         Arguments.Clear;
         for Item of Batch.Prefix loop
            Arguments.Append (Item);
         end loop;
         for Item of Batch.Paths loop
            Arguments.Append (Item);
         end loop;
         if Natural (Batch.Paths.Length) > 0
           and then (not Context.Execute_Utility (To_String (Batch.Utility), Arguments, Exit_Code)
                     or else Exit_Code /= 0)
         then
            Ok := False;
         end if;
      end loop;
   end Flush_Exec_Batches;
end Posix_Tools.Commands.Find_Evaluation.Actions;
