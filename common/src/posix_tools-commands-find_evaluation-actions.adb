with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Localization;

package body Posix_Tools.Commands.Find_Evaluation.Actions is
   use Ada.Strings.Unbounded;

   procedure Append_Exec_Batch_Path
     (State       : in out Evaluation_State;
      Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Start_Index : Positive;
      Terminator  : Positive;
      Path        : String;
      Ok          : out Boolean);
   function Argument_Size (Item : String) return Natural;
   function Batch_Position
     (State       : Evaluation_State;
      Start_Index : Positive) return Natural;
   function Paths_Size (Paths : Posix_Tools.Arguments.Vector) return Natural;
   function Replaced_Path (Item : String; Path : String) return String;

   --  Invoke Batch's utility with its prefix and pathnames; True when it ran
   --  and exited 0.
   function Run_Batch
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Batch   : Find_Exec_Batch) return Boolean;

   procedure Append_Exec_Batch_Path
     (State       : in out Evaluation_State;
      Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Start_Index : Positive;
      Terminator  : Positive;
      Path        : String;
      Ok          : out Boolean)
   is
      Position : constant Natural := Batch_Position (State, Start_Index);
      Batch    : Find_Exec_Batch;
   begin
      Ok := True;
      if Position = 0 then
         Batch.Start_Index := Start_Index;
         Batch.Utility := To_Unbounded_String (State.Expression.Element (Start_Index));
         Batch.Size := Argument_Size (State.Expression.Element (Start_Index));
         for J in Start_Index + 1 .. Terminator - 2 loop
            Batch.Prefix.Append (State.Expression.Element (J));
            Batch.Size := Batch.Size + Argument_Size (State.Expression.Element (J));
         end loop;
         Batch.Paths.Append (Path);
         Batch.Size := Batch.Size + Argument_Size (Path);
         State.Exec_Batches.Append (Batch);
      else
         Batch := State.Exec_Batches.Element (Position);
         --  A pathname that would take the invocation past the limit sends
         --  the pathnames gathered so far first; one pathname always goes,
         --  however long.
         if not Batch.Paths.Is_Empty
           and then Batch.Size + Argument_Size (Path) > State.Batch_Limit
         then
            Ok := Run_Batch (Context, Batch);
            Batch.Size := Batch.Size - Paths_Size (Batch.Paths);
            Batch.Paths.Clear;
         end if;
         Batch.Paths.Append (Path);
         Batch.Size := Batch.Size + Argument_Size (Path);
         State.Exec_Batches.Replace_Element (Position, Batch);
      end if;
   end Append_Exec_Batch_Path;

   --  What one argument costs a new process: its bytes, its terminating NUL
   --  and the pointer the argument vector holds to it.
   function Argument_Size (Item : String) return Natural is
     (Item'Length + 1 + 8);

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
      Terminator := Exec_Terminator (State.Expression, Start, Allow_Batch => True);
      if Terminator = 0 or else Terminator = Start then
         Valid := False;
         return False;
      end if;

      Index := Terminator + 1;
      if not Active then
         return False;
      end if;

      if State.Expression.Element (Terminator) = "+" then
         declare
            Earlier_Ok : Boolean;
         begin
            Append_Exec_Batch_Path (State, Context, Start, Terminator, Path, Earlier_Ok);
            State.Batch_Failed := State.Batch_Failed or else not Earlier_Ok;
         end;
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
      Terminator := Exec_Terminator (State.Expression, Start, Allow_Batch => False);
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
   begin
      if State.Batch_Failed then
         Ok := False;
      end if;
      for Batch of State.Exec_Batches loop
         if not Batch.Paths.Is_Empty and then not Run_Batch (Context, Batch) then
            Ok := False;
         end if;
      end loop;
   end Flush_Exec_Batches;

   function Paths_Size (Paths : Posix_Tools.Arguments.Vector) return Natural is
   begin
      return Total : Natural := 0 do
         for Item of Paths loop
            Total := Total + Argument_Size (Item);
         end loop;
      end return;
   end Paths_Size;

   function Replaced_Path (Item : String; Path : String) return String is
   begin
      if Item = "{}" then
         return Path;
      else
         return Item;
      end if;
   end Replaced_Path;

   function Run_Batch
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Batch   : Find_Exec_Batch) return Boolean
   is
      Arguments : Posix_Tools.Arguments.Vector := Batch.Prefix;
      Exit_Code : Integer := 0;
   begin
      for Item of Batch.Paths loop
         Arguments.Append (Item);
      end loop;
      return Context.Execute_Utility (To_String (Batch.Utility), Arguments, Exit_Code)
        and then Exit_Code = 0;
   end Run_Batch;
end Posix_Tools.Commands.Find_Evaluation.Actions;
