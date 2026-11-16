with Ada.Containers;
with Posix_Tools.Commands.Find_Evaluation.Actions;
with Posix_Tools.Commands.Find_Evaluation.Predicates;
with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Host_Adapters.Path_Separators;
with Posix_Tools.Paths;
with Posix_Tools.Text.File_Modes;

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
      Is_Link : constant Boolean := View.Is_Link;
      Kind    : constant FS.File_Kind := View.Kind;
      Exists  : constant Boolean := Is_Link or else Kind /= FS.Missing_File;
      Cached_Status : FS.Entry_Status;
      Status_Loaded : Boolean := False;

      --  Metadata predicates share one lazy query. Name-only and action-only
      --  expressions therefore retain the directory walk's cheap path.
      function Status_Of return FS.Entry_Status;

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

      function Status_Of return FS.Entry_Status is
      begin
         if not Status_Loaded then
            Cached_Status :=
              (if View.Followed_Link
               then FS.File_Status_Of (Path)
               else FS.Entry_Status_Of (Path));
            Status_Loaded := True;
         end if;
         return Cached_Status;
      end Status_Of;

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
                (State.Expression.Element (Index - 1),
                 Posix_Tools.Paths.Basename (Path));
         elsif Token = "-path" then
            Index := Index + 2;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.Glob_Matches
                (State.Expression.Element (Index - 1), Slashed (Path));
         elsif Token = "-mtime" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Operand.Count_Valid
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Mtime_Matches
                   (Status_Of, Exists, Operand.Count, Operand.Relation,
                    State.Started, Valid);
            end;
         elsif Token = "-newer" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Newer_Matches
                   (Status_Of, Exists, Operand.Reference_Time,
                    Operand.Reference_Valid, Valid);
            end;
         elsif Token = "-perm" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Operand.Permission_Valid
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Permission_Matches
                   (Status_Of, Operand.Permission, Operand.Match_All);
            end;
         elsif Token = "-size" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Operand.Count_Valid
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Size_Matches
                   (Status_Of, Is_Link, Exists, Kind, Operand.Count, Operand.Relation,
                    Operand.Bytes);
            end;
         elsif Token = "-type" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Valid := Valid and then Operand.Type_Valid;
               Index := Index + 2;
               return Active
                 and then Valid
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Type_Matches
                   (Path, Exists, Is_Link, Kind, Operand.Type_Filter);
            end;
         elsif Token = "-user" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Ownership_Matches
                   (Status_Of, Operand.Identity,
                    Operand.Identity_Found, True, Valid);
            end;
         elsif Token = "-group" then
            declare
               Operand : constant Compiled_Operand := State.Compiled.Element (Index);
            begin
               Index := Index + 2;
               return Active
                 and then Posix_Tools.Commands.Find_Evaluation.Predicates.Ownership_Matches
                   (Status_Of, Operand.Identity,
                    Operand.Identity_Found, False, Valid);
            end;
         elsif Token = "-nouser" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Status_Of, True, Valid);
         elsif Token = "-nogroup" then
            Index := Index + 1;
            return Active
              and then Posix_Tools.Commands.Find_Evaluation.Predicates.No_Owner_Matches
                (Status_Of, False, Valid);
         elsif Token = "-print" then
            if Active then
               Print_Path (State, Context, Path);
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

   procedure Flush_Output
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class)
   is
   begin
      Posix_Tools.Commands.Helpers.Flush_Output
        (State.Output_Buffer, Context);
   end Flush_Output;

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
      Context          : Posix_Tools.Commands.Contexts.Host_Context'Class;
      Expression       : Posix_Tools.Arguments.Vector;
      Environment_Size : Natural)
   is
   begin
      State.Expression := Expression;
      State.Compiled.Clear;
      for I in 1 .. Natural (Expression.Length) loop
         declare
            Item  : Compiled_Operand;
            Token : constant String := Expression.Element (I);
         begin
            if I < Natural (Expression.Length) then
               if Token = "-mtime" or else Token = "-size" then
                  Item.Count_Valid := Parse_Find_Count
                    (Expression.Element (I + 1), Item.Count,
                     Item.Relation, Item.Bytes);
               elsif Token = "-perm" then
                  Item.Permission_Valid := Parse_Permission_Mode
                    (Expression.Element (I + 1), Item.Permission,
                     Item.Match_All);
               elsif Token = "-type" then
                  declare
                     Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
                       Posix_Tools.Text.Find_Expressions.Parse_Type_Filter
                         (Expression.Element (I + 1));
                  begin
                     Item.Type_Filter := Parsed.Filter;
                     Item.Type_Valid := Parsed.Valid;
                  end;
               elsif Token = "-newer" then
                  Item.Reference_Valid := FS.Modification_Time
                    (Expression.Element (I + 1), Item.Reference_Time);
               elsif Token = "-user" then
                  Item.Identity_Found := Posix_Tools.Commands.Helpers.Resolve_User_Id
                    (Context, Expression.Element (I + 1), Item.Identity);
               elsif Token = "-group" then
                  Item.Identity_Found := Posix_Tools.Commands.Helpers.Resolve_Group_Id
                    (Context, Expression.Element (I + 1), Item.Identity);
               end if;
            end if;
            State.Compiled.Append (Item);
         end;
      end loop;
      State.Exec_Batches.Clear;
      State.Batch_Failed := False;
      Posix_Tools.Commands.Helpers.Clear_Output (State.Output_Buffer);
      State.Batch_Limit :=
        (if Environment_Size >= Batch_Argument_Bytes - Minimum_Batch_Argument_Bytes
         then Minimum_Batch_Argument_Bytes
         else Batch_Argument_Bytes - Environment_Size);
      State.Depth := (for some Token of Expression => Token = "-depth");
      State.Xdev := (for some Token of Expression => Token = "-xdev");
      State.Started := Posix_Tools.Host_Adapters.Clock.Now;
   end Initialize;

   procedure Print_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String)
   is
   begin
      Posix_Tools.Commands.Helpers.Buffered_Put_Line
        (State.Output_Buffer, Context, Path);
   end Print_Path;

   --  -path patterns name directories with '/', as POSIX writes them; a host
   --  whose own separator differs (Windows) is matched in that spelling.
   function Parse_Find_Count
     (Text     : String;
      Count    : out Long_Long_Integer;
      Relation : out Posix_Tools.Text.Find_Expressions.Count_Relation;
      Bytes    : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
        Posix_Tools.Text.Find_Expressions.Parse_Find_Count (Text);
   begin
      Count := Parsed.Count;
      Relation := Parsed.Relation;
      Bytes := Parsed.Bytes;
      return Parsed.Valid;
   end Parse_Find_Count;

   function Parse_Permission_Mode
     (Text      : String;
      Mode      : out Natural;
      Match_All : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
        Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode (Text);
   begin
      Mode := Parsed.Mode;
      Match_All := Parsed.Match_All;
      case Parsed.Status is
         when Posix_Tools.Text.File_Modes.Invalid_Permission_Mode =>
            return False;
         when Posix_Tools.Text.File_Modes.Octal_Permission_Mode
            | Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode =>
            return True;
      end case;
   end Parse_Permission_Mode;

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
