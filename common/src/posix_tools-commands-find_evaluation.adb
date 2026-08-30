with Ada.Calendar;
with Ada.Containers;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Localization;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Find_Expressions;
with Posix_Tools.Text.Glob_Fields;

package body Posix_Tools.Commands.Find_Evaluation is
   use Ada.Strings.Unbounded;

   use type Ada.Containers.Count_Type;
   use type Ada.Calendar.Time;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   subtype Find_Count_Relation is Posix_Tools.Text.Find_Expressions.Count_Relation;
   Exact_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Exact_Count;
   Greater_Than_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Greater_Than_Count;
   Less_Than_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Less_Than_Count;

   function Glob_Matches (Pattern, Text : String) return Boolean;

   function Glob_Matches (Pattern, Text : String) return Boolean is
      function Match_From (P, T : Natural) return Boolean is
      begin
         if P > Pattern'Last then
            return T > Text'Last;
         elsif Pattern (P) = '*' then
            for Next in T .. Text'Last + 1 loop
               if Match_From (P + 1, Next) then
                  return True;
               end if;
            end loop;
            return False;
         elsif Pattern (P) = '?' then
            return T <= Text'Last and then Match_From (P + 1, T + 1);
         elsif Pattern (P) = '[' then
            declare
               Closing : constant Natural :=
                 (if P < Pattern'Last then
                    Posix_Tools.Text.Glob_Fields.Closing_Bracket_From (Pattern, P)
                  else
                    0);
            begin
               if Closing = 0 then
                  return T <= Text'Last
                    and then Pattern (P) = Text (T)
                    and then Match_From (P + 1, T + 1);
               elsif T > Text'Last then
                  return False;
               else
                  return Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches
                      (Pattern, P, Closing, Text (T))
                    and then Match_From (Closing + 1, T + 1);
               end if;
            end;
         elsif T <= Text'Last and then Pattern (P) = Text (T) then
            return Match_From (P + 1, T + 1);
         else
            return False;
         end if;
      end Match_From;
   begin
      return Match_From (Pattern'First, Text'First);
   end Glob_Matches;

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

   function Parse_Permission_Mode
     (Text : String;
      Mode : out Natural;
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

   function Parse_Find_Count
     (Text     : String;
      Count    : out Long_Long_Integer;
      Relation : out Find_Count_Relation;
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

      function Type_Matches
        (Filter : Posix_Tools.Text.Find_Expressions.Find_Type_Filter) return Boolean
      is
         use type Posix_Tools.Text.Find_Expressions.Find_Type_Filter;

         No_Special_File : constant Posix_Tools.Text.Find_Expressions.Find_Special_File_Class :=
           Posix_Tools.Text.Find_Expressions.No_Special_File;
      begin
         if Filter in Posix_Tools.Text.Find_Expressions.Block_Device_Type
                   | Posix_Tools.Text.Find_Expressions.Character_Device_Type
                   | Posix_Tools.Text.Find_Expressions.FIFO_Type
                   | Posix_Tools.Text.Find_Expressions.Socket_Type
           and then Exists
           and then Kind = FS.Special_File
         then
            declare
               Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Path);
               Special_Class : Posix_Tools.Text.Find_Expressions.Find_Special_File_Class :=
                 No_Special_File;
            begin
               if Info.Available then
                  Special_Class :=
                    (case Info.Kind is
                       when FS.Block_Device =>
                         Posix_Tools.Text.Find_Expressions.Block_Device_File,
                       when FS.Character_Device =>
                         Posix_Tools.Text.Find_Expressions.Character_Device_File,
                       when FS.FIFO =>
                         Posix_Tools.Text.Find_Expressions.FIFO_File,
                       when FS.Socket =>
                         Posix_Tools.Text.Find_Expressions.Socket_File,
                       when FS.Not_Special | FS.Other_Special =>
                         No_Special_File);
               end if;

               return
                 Posix_Tools.Text.Find_Expressions.Type_Matches
                   (Filter,
                    Exists,
                    Kind = FS.Directory,
                    Kind = FS.Ordinary_File,
                    Is_Link,
                    Info.Available,
                    Special_Class);
            end;
         else
            return
              Posix_Tools.Text.Find_Expressions.Type_Matches
                (Filter,
                 Exists,
                 Kind = FS.Directory,
                 Kind = FS.Ordinary_File,
                 Is_Link,
                 False,
                 No_Special_File);
         end if;
      end Type_Matches;

      function Permission_Matches (Text : String; Valid : in out Boolean) return Boolean is
         Available : Boolean;
         Actual    : constant Natural := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
         Expected  : Natural;
         Match_All : Boolean;
      begin
         if not Parse_Permission_Mode (Text, Expected, Match_All) then
            Valid := False;
            return False;
         elsif not FS.Permissions_Supported or else not Available then
            return False;
         else
            return
              Posix_Tools.Text.File_Modes.Permission_Matches
                (Actual, Expected, Match_All);
         end if;
      end Permission_Matches;

      function Size_Matches (Text : String; Valid : in out Boolean) return Boolean is
         Count    : Long_Long_Integer;
         Relation : Find_Count_Relation;
         Bytes    : Boolean;
         Units    : Long_Long_Integer;
      begin
         if not Exists or else Kind = FS.Directory then
            return False;
         elsif not Parse_Find_Count (Text, Count, Relation, Bytes) then
            Valid := False;
            return False;
         end if;

         declare
            Raw_Size : constant Long_Long_Integer := FS.Size (Path);
         begin
            Units := (if Bytes then Raw_Size else (Raw_Size + 511) / 512);
         end;

         return
           Posix_Tools.Text.Find_Expressions.Count_Matches
             (Units, Count, Relation);
      end Size_Matches;

      function Mtime_Matches (Text : String; Valid : in out Boolean) return Boolean is
         Seconds_Per_Day : constant Duration := 86_400.0;
         Count           : Long_Long_Integer;
         Relation        : Find_Count_Relation;
         Bytes           : Boolean;

         function Threshold (Value : Long_Long_Integer; Ok : in out Boolean) return Duration is
         begin
            if Value < 0 or else Value > Long_Long_Integer (Duration'Last / Seconds_Per_Day) then
               Ok := False;
               return 0.0;
            end if;
            return Duration (Value) * Seconds_Per_Day;
         end Threshold;
      begin
         if not Exists or else not Parse_Find_Count (Text, Count, Relation, Bytes) or else Bytes then
            Valid := False;
            return False;
         end if;

         declare
            Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
            Path_Time : Ada.Calendar.Time;
            Ok  : Boolean := True;
         begin
            if not FS.Modification_Time (Path, Path_Time) then
               Valid := False;
               return False;
            end if;

            case Relation is
               when Exact_Count =>
                  if Count = Long_Long_Integer'Last then
                     Valid := False;
                     return False;
                  end if;
                  declare
                     Low  : constant Duration := Threshold (Count, Ok);
                     High : constant Duration := Threshold (Count + 1, Ok);
                  begin
                     Valid := Valid and then Ok;
                     return
                       Ok
                       and then Posix_Tools.Text.Find_Expressions.Age_Matches
                         (Now - Path_Time, Low, High, Relation);
                  end;
               when Greater_Than_Count =>
                  if Count = Long_Long_Integer'Last then
                     return False;
                  end if;
                  declare
                     Low : constant Duration := Threshold (Count + 1, Ok);
                  begin
                     Valid := Valid and then Ok;
                     return
                       Ok
                       and then Posix_Tools.Text.Find_Expressions.Age_Matches
                         (Now - Path_Time, Low, 0.0, Relation);
                  end;
               when Less_Than_Count =>
                  declare
                     High : constant Duration := Threshold (Count, Ok);
                  begin
                     Valid := Valid and then Ok;
                     return
                       Ok
                       and then Posix_Tools.Text.Find_Expressions.Age_Matches
                         (Now - Path_Time, 0.0, High, Relation);
                  end;
            end case;
         end;
      end Mtime_Matches;

      function Newer_Matches (Reference : String; Valid : in out Boolean) return Boolean is
      begin
         if not Exists or else not FS.Exists (Reference) then
            Valid := False;
            return False;
         end if;
         declare
            Path_Time      : Ada.Calendar.Time;
            Reference_Time : Ada.Calendar.Time;
         begin
            if not FS.Modification_Time (Path, Path_Time)
              or else not FS.Modification_Time (Reference, Reference_Time)
            then
               Valid := False;
               return False;
            end if;
            return Path_Time > Reference_Time;
         end;
      exception
         when others =>
            Valid := False;
            return False;
      end Newer_Matches;

      function Ownership_Matches
        (Text : String;
         User : Boolean;
         Valid : in out Boolean) return Boolean
      is
         Actual_User  : Natural;
         Actual_Group : Natural;
         Available    : Boolean;
         Expected     : Natural := 0;
         Found        : Boolean := False;
      begin
         if User then
            Found := Posix_Tools.Commands.Helpers.Resolve_User_Id (Text, Expected);
         else
            Found := Posix_Tools.Commands.Helpers.Resolve_Group_Id (Text, Expected);
         end if;

         if not Found or else not FS.Ownership_Supported then
            return False;
         end if;

         FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
         return
           Posix_Tools.Text.Find_Expressions.Ownership_Matches
             (Available, User, Actual_User, Actual_Group, Expected);
      exception
         when others =>
            Valid := False;
            return False;
      end Ownership_Matches;

      function No_Owner_Matches (User : Boolean; Valid : in out Boolean) return Boolean is
         Actual_User  : Natural;
         Actual_Group : Natural;
         Available    : Boolean;
      begin
         if not FS.Ownership_Supported then
            return False;
         end if;

         FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
         return
           Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
             (Available,
              (if User
               then FS.User_Name_For_Id (Actual_User)
               else FS.Group_Name_For_Id (Actual_Group)));
      exception
         when others =>
            Valid := False;
            return False;
      end No_Owner_Matches;

      function Read_Ok_Affirmative return Boolean is
      begin
         return Posix_Tools.Commands.Helpers.Read_Affirmative_Response
           (Context, Wait_For_Line_End => True);
      end Read_Ok_Affirmative;

      function Replaced_Path (Item : String) return String is
      begin
         if Item = "{}" then
            return Path;
         else
            return Item;
         end if;
      end Replaced_Path;

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
            return Active and then Glob_Matches (State.Expression.Element (Index - 1), Name);
         elsif Token = "-path" then
            Index := Index + 2;
            return Active and then Glob_Matches (State.Expression.Element (Index - 1), Path);
         elsif Token = "-mtime" then
            Index := Index + 2;
            return Active and then Mtime_Matches (State.Expression.Element (Index - 1), Valid);
         elsif Token = "-newer" then
            Index := Index + 2;
            return Active and then Newer_Matches (State.Expression.Element (Index - 1), Valid);
         elsif Token = "-perm" then
            Index := Index + 2;
            return Active and then Permission_Matches (State.Expression.Element (Index - 1), Valid);
         elsif Token = "-size" then
            Index := Index + 2;
            return Active and then Size_Matches (State.Expression.Element (Index - 1), Valid);
         elsif Token = "-type" then
            declare
               Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
                 Posix_Tools.Text.Find_Expressions.Parse_Type_Filter
                   (State.Expression.Element (Index + 1));
            begin
               Valid := Valid and then Parsed.Valid;
               Index := Index + 2;
               return Active and then Valid and then Type_Matches (Parsed.Filter);
            end;
         elsif Token = "-user" then
            Index := Index + 2;
            return Active and then Ownership_Matches (State.Expression.Element (Index - 1), True, Valid);
         elsif Token = "-group" then
            Index := Index + 2;
            return Active and then Ownership_Matches (State.Expression.Element (Index - 1), False, Valid);
         elsif Token = "-nouser" then
            Index := Index + 1;
            return Active and then No_Owner_Matches (True, Valid);
         elsif Token = "-nogroup" then
            Index := Index + 1;
            return Active and then No_Owner_Matches (False, Valid);
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
            declare
               Start : constant Positive := Index + 1;
               Terminator : Natural := 0;
               Arguments : Posix_Tools.Arguments.Vector;
               Exit_Code : Integer := 0;
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
                  Arguments.Append (Replaced_Path (State.Expression.Element (J)));
               end loop;

               if Context.Execute_Utility (State.Expression.Element (Start), Arguments, Exit_Code) then
                  return Exit_Code = 0;
               else
                  return False;
               end if;
            end;
         elsif Token = "-ok" then
            declare
               Start : constant Positive := Index + 1;
               Terminator : Natural := 0;
               Arguments : Posix_Tools.Arguments.Vector;
               Exit_Code : Integer := 0;
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
               if not Read_Ok_Affirmative then
                  return False;
               end if;

               for J in Start + 1 .. Terminator - 1 loop
                  Arguments.Append (Replaced_Path (State.Expression.Element (J)));
               end loop;

               if Context.Execute_Utility (State.Expression.Element (Start), Arguments, Exit_Code) then
                  return Exit_Code = 0;
               else
                  return False;
               end if;
            end;
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
