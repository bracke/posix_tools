with Ada.Containers;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Find_Evaluation.Actions;
with Posix_Tools.Commands.Find_Evaluation.Predicates;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find_Evaluation is
   use type Ada.Containers.Count_Type;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Initialize
     (State      : out Evaluation_State;
      Expression : Posix_Tools.Arguments.Vector)
   is
   begin
      State.Expression := Expression;
      State.Exec_Batches.Clear;
      State.Depth := (for some Token of Expression => Token = "-depth");
      State.Xdev := (for some Token of Expression => Token = "-xdev");
   end Initialize;

   function Has_Depth (State : Evaluation_State) return Boolean is
   begin
      return State.Depth;
   end Has_Depth;

   function Has_Xdev (State : Evaluation_State) return Boolean is
   begin
      return State.Xdev;
   end Has_Xdev;

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean)
   is
   begin
      Posix_Tools.Commands.Find_Evaluation.Actions.Flush_Exec_Batches
        (State, Context, Ok);
   end Flush_Exec_Batches;

   procedure Evaluate_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Result  : out Path_Result)
   is
      Name    : constant String := Posix_Tools.Commands.File_Helpers.Simple_Name (Path);
      Exists  : constant Boolean := FS.Exists (Path);
      Is_Link : constant Boolean := FS.Is_Link (Path);
      Kind    : constant FS.File_Kind := FS.Kind (Path);

      function Evaluate_Primary
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean;
      function Evaluate_Not
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean;
      function Evaluate_And
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean;
      function Evaluate_Or
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean;

      function Evaluate_Primary
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean
      is
         Token : constant String := State.Expression.Element (Index);
      begin
         if Token = "(" then
            declare
               Value : Boolean;
            begin
               Index := Index + 1;
               Value := Evaluate_Or (Index, Valid, Active);
               if not Valid
                 or else Index > Natural (State.Expression.Length)
                 or else State.Expression.Element (Index) /= ")"
               then
                  Valid := False;
                  return False;
               end if;
               Index := Index + 1;
               return Value;
            end;
         elsif Token = "-name" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Glob_Matches
                (State.Expression.Element (Index - 1), Name);
         elsif Token = "-path" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Glob_Matches
                (State.Expression.Element (Index - 1), Path);
         elsif Token = "-mtime" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Mtime_Matches
                (Path, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-newer" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Newer_Matches
                (Path, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-perm" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Permission_Matches
                (Path, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-size" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Size_Matches
                (Path, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-type" then
            declare
               Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
                 Posix_Tools.Text.Find_Expressions.Parse_Type_Filter
                   (State.Expression.Element (Index + 1));
            begin
               Valid := Valid and then Parsed.Valid;
               Index := Index + 2;
               return Active
                 and then Valid
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Type_Matches
                   (Path, Exists, Is_Link, Kind, Parsed.Filter);
            end;
         elsif Token = "-user" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Ownership_Matches
                (Path, State.Expression.Element (Index - 1), True, Valid);
         elsif Token = "-group" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Ownership_Matches
                (Path, State.Expression.Element (Index - 1), False, Valid);
         elsif Token = "-nouser" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Path, True, Valid);
         elsif Token = "-nogroup" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Path, False, Valid);
         elsif Token = "-print" then
            if Active then
               Context.Put_Line (Path);
            end if;
            Index := Index + 1;
            return Active;
         elsif Token = "-prune" then
            if Active and then not State.Depth then
               Result.Pruned := True;
            end if;
            Index := Index + 1;
            return Active;
         elsif Token = "-depth" then
            Index := Index + 1;
            return Active;
         elsif Token = "-xdev" then
            Index := Index + 1;
            return Active;
         elsif Token = "-exec" then
            return Posix_Tools.Commands.Find_Evaluation.Actions.Execute_Exec
              (State, Context, Path, Index, Active, Valid);
         elsif Token = "-ok" then
            return Posix_Tools.Commands.Find_Evaluation.Actions.Execute_Ok
              (State, Context, Path, Index, Active, Valid);
         else
            Valid := False;
            return False;
         end if;
      end Evaluate_Primary;

      function Evaluate_Not
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean
      is
      begin
         if Index <= Natural (State.Expression.Length) and then State.Expression.Element (Index) = "!" then
            Index := Index + 1;
            if Active then
               return not Evaluate_Not (Index, Valid, True);
            else
               declare
                  Ignored : constant Boolean := Evaluate_Not (Index, Valid, False);
               begin
                  return False;
               end;
            end if;
         else
            return Evaluate_Primary (Index, Valid, Active);
         end if;
      end Evaluate_Not;

      function Evaluate_And
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean
      is
         Value : Boolean := Evaluate_Not (Index, Valid, Active);
         Right : Boolean;
      begin
         while Valid and then Index <= Natural (State.Expression.Length) loop
            exit when State.Expression.Element (Index) = ")" or else State.Expression.Element (Index) = "-o";
            if State.Expression.Element (Index) = "-a" then
               Index := Index + 1;
            end if;
            exit when Index > Natural (State.Expression.Length) or else State.Expression.Element (Index) = ")";
            Right := Evaluate_Not (Index, Valid, Active and then Value);
            if Value then
               Value := Right;
            end if;
         end loop;
         return Value;
      end Evaluate_And;

      function Evaluate_Or
        (Index : in out Positive;
         Valid : in out Boolean;
         Active : Boolean) return Boolean
      is
         Value : Boolean := Evaluate_And (Index, Valid, Active);
         Right : Boolean;
      begin
         while Valid
           and then Index <= Natural (State.Expression.Length)
           and then State.Expression.Element (Index) = "-o"
         loop
            Index := Index + 1;
            exit when Index > Natural (State.Expression.Length);
            Right := Evaluate_And (Index, Valid, Active and then not Value);
            if not Value then
               Value := Right;
            end if;
         end loop;
         return Value;
      end Evaluate_Or;

      Index : Positive := 1;
   begin
      Result := (Matches => True, Valid => True, Pruned => False);
      if State.Expression.Length = 0 then
         return;
      end if;

      Result.Matches := Evaluate_Or (Index, Result.Valid, True);
      Result.Valid := Result.Valid and then Index > Natural (State.Expression.Length);
   end Evaluate_Path;
end Posix_Tools.Commands.Find_Evaluation;
