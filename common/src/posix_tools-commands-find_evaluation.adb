with Ada.Containers;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Find_Evaluation.Actions;
with Posix_Tools.Commands.Find_Evaluation.Predicates;
with Posix_Tools.Host_Adapters.Path_Separators;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find_Evaluation is
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   --  The most argument bytes a batched -exec ... {} + passes at once: XCU
   --  find splits the pathnames over invocations so none exceeds {ARG_MAX}.
   --  The host does not report its limit here, so this keeps to a value
   --  every supported host allows, less the environment the child inherits.
   Batch_Argument_Bytes : constant := 128 * 1024;

   --  The least the limit falls to however large the environment: the
   --  smallest {ARG_MAX} POSIX allows.
   Minimum_Batch_Argument_Bytes : constant := 4_096;

   function Slashed (Path : String) return String;

   procedure Evaluate_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      View    : Entry_View;
      Result  : out Path_Result)
   is
      Name    : constant String := Posix_Tools.Commands.File_Helpers.Simple_Name (Path);
      Is_Link : constant Boolean := View.Is_Link;
      Kind    : constant FS.File_Kind := View.Kind;
      Exists  : constant Boolean := Is_Link or else Kind /= FS.Missing_File;

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
                (State.Expression.Element (Index - 1), Slashed (Path));
         elsif Token = "-mtime" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Mtime_Matches
                (Path, Is_Link, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-newer" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Newer_Matches
                (Path, Is_Link, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-perm" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Permission_Matches
                (Path, Is_Link, State.Expression.Element (Index - 1), Valid);
         elsif Token = "-size" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Size_Matches
                (Path, Is_Link, State.Expression.Element (Index - 1), Valid);
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
                (Path, Is_Link, State.Expression.Element (Index - 1), True, Valid);
         elsif Token = "-group" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Ownership_Matches
                (Path, Is_Link, State.Expression.Element (Index - 1), False, Valid);
         elsif Token = "-nouser" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Path, Is_Link, True, Valid);
         elsif Token = "-nogroup" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Path, Is_Link, False, Valid);
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

      Index : Positive := 1;
   begin
      Result := (Matches => True, Valid => True, Pruned => False);
      if State.Expression.Length = 0 then
         return;
      end if;

      Result.Matches := Evaluate_Or (Index, Result.Valid, True);
      Result.Valid := Result.Valid and then Index > Natural (State.Expression.Length);
   end Evaluate_Path;

   function Exec_Terminator
     (Expression    : Posix_Tools.Arguments.Vector;
      Utility_Index : Positive;
      Allow_Batch   : Boolean) return Natural
   is
   begin
      for J in Utility_Index .. Natural (Expression.Length) loop
         if Expression.Element (J) = ";" then
            return J;
         elsif Allow_Batch
           and then Expression.Element (J) = "+"
           and then J >= Utility_Index + 2
           and then Expression.Element (J - 1) = "{}"
         then
            return J;
         end if;
      end loop;
      return 0;
   end Exec_Terminator;

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean)
   is
   begin
      Posix_Tools.Commands.Find_Evaluation.Actions.Flush_Exec_Batches
        (State, Context, Ok);
   end Flush_Exec_Batches;

   function Has_Depth (State : Evaluation_State) return Boolean is
   begin
      return State.Depth;
   end Has_Depth;

   function Has_Xdev (State : Evaluation_State) return Boolean is
   begin
      return State.Xdev;
   end Has_Xdev;

   procedure Initialize
     (State            : out Evaluation_State;
      Expression       : Posix_Tools.Arguments.Vector;
      Environment_Size : Natural)
   is
   begin
      State.Expression := Expression;
      State.Exec_Batches.Clear;
      State.Batch_Limit :=
        (if Environment_Size >= Batch_Argument_Bytes - Minimum_Batch_Argument_Bytes
         then Minimum_Batch_Argument_Bytes
         else Batch_Argument_Bytes - Environment_Size);
      State.Depth := (for some Token of Expression => Token = "-depth");
      State.Xdev := (for some Token of Expression => Token = "-xdev");
   end Initialize;

   --  -path patterns name directories with '/', as POSIX writes them; a host
   --  whose own separator differs (Windows) is matched in that spelling.
   function Slashed (Path : String) return String is
      Separator : constant Character :=
        Posix_Tools.Host_Adapters.Path_Separators.Directory_Separator;
   begin
      return Result : String := Path do
         if Separator /= '/' then
            for C of Result loop
               if C = Separator then
                  C := '/';
               end if;
            end loop;
         end if;
      end return;
   end Slashed;
end Posix_Tools.Commands.Find_Evaluation;
