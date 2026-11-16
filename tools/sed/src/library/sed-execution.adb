with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Regexp;
with Sedlib.Diagnostics;
with Sedlib.Execution;
with Sedlib.Options;
with Sedlib.Programs;
with Sedlib.Text;
with Sed.Engine;
with Sed.Execution.Environment;
with Sed.Input;
with Sed.Output;
with Sed.Scripts.Compilation.Engine;

package body Sed.Execution is

   package D renames Sed.Diagnostics;

   --  Execution options for a general-purpose command-line sed.
   --
   --  The engine enforces finite bounds by design. A library embedding it in
   --  a server wants those bounds small; a command-line stream editor must be
   --  able to process whatever the host can hold, so they are raised to
   --  effectively unbounded values here. The mechanism stays in place: a
   --  script that still exceeds one gets a structured Resource_Exhausted
   --  diagnostic rather than a truncated result.
   function Command_Line_Options
     (Suppress_Automatic_Output : Boolean)
      return Sedlib.Options.Execution_Options;

   --------------------------
   -- Command_Line_Options --
   --------------------------

   function Command_Line_Options
     (Suppress_Automatic_Output : Boolean)
      return Sedlib.Options.Execution_Options
   is
      Options : Sedlib.Options.Execution_Options :=
        Sedlib.Options.Default_Execution_Options;

      --  One gibibyte for byte-valued bounds, and the widest count the engine
      --  accepts for event and instruction bounds.
      Byte_Bound : constant Natural := 2 ** 30;

      Limits : constant Sedlib.Options.Execution_Limits :=
        (Input_Record_Bytes => Byte_Bound,
         Pattern_Space_Bytes => Byte_Bound,
         Hold_Space_Bytes => Byte_Bound,
         Pending_Append_Bytes => Byte_Bound,
         Pending_Append_Events => Natural'Last,
         Output_Bytes => Natural'Last,
         Output_Events => Natural'Last,
         Total_Instructions => Natural'Last,
         Instructions_Per_Cycle => Natural'Last,
         Branches_Per_Cycle => Natural'Last,
         Input_Records => Natural'Last,
         Cycles => Natural'Last,
         Regexp_Steps => Natural'Last);
   begin
      Sedlib.Options.Set_Automatic_Output
        (Options, not Suppress_Automatic_Output);
      Sedlib.Options.Set_Text_Mode (Options, Sedlib.Options.Byte_Mode);
      Sedlib.Options.Set_UTF8_Policy
        (Options, Sedlib.Options.Treat_Invalid_As_Bytes);
      Sedlib.Options.Set_Resource_Preflight
        (Options, Sedlib.Options.Fail_When_Executed);
      Sedlib.Options.Set_Callback_Policy
        (Options, Sedlib.Options.Convert_Callback_Exceptions);
      Sedlib.Options.Set_Limits (Options, Limits);
      return Options;
   end Command_Line_Options;

   ---------
   -- Run --
   ---------

   procedure Run
     (Program : Sed.Scripts.Compilation.Compiled_Program;
      Suppress_Automatic_Output : Boolean;
      Source : not null access Sed.Input.Logical_Stream.Stream;
      Target : not null access Sed.Output.Standard.Writer;
      Named : not null access Sed.Output.Named_Files.Registry;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Result : out Outcome)
   is
      use type Sedlib.Execution.Termination_Reason;

      Records : aliased Environment.Record_Adapter;
      Sink : aliased Environment.Sink_Adapter;
      Resources : aliased Environment.Resource_Adapter;

      Engine_Result : Sedlib.Execution.Execution_Result;
      Reported : Sed.Diagnostics.Diagnostic_List;

      procedure Try_Run_Literal_Substitution (Handled : out Boolean) is
         use type Regexp.Copy_Status;
         use type Sed.Input.Record_Status;
         use type Sedlib.Programs.Compiled_Address_Kind;
         use type Sedlib.Programs.Operation_Kind;

         Engine_Program : constant Sedlib.Programs.Program :=
           Sed.Scripts.Compilation.Engine.Program_Of (Program);
         Expression : Regexp.Regexp;
         Pattern_Buffer : String (1 .. 4 * 1024);
         Pattern_Last : Natural := 0;
         Copy_Result : Regexp.Copy_Status;

         function Is_Plain_Pattern (Pattern : String) return Boolean is
         begin
            if Pattern = "" then
               return False;
            end if;

            for Ch of Pattern loop
               if Ch in '.' | '*' | '+' | '?' | '(' | ')' | '[' | ']'
                        | '{' | '}' | '\' | '^' | '$' | '|'
               then
                  return False;
               end if;
            end loop;
            return True;
         end Is_Plain_Pattern;

         function Is_Plain_Replacement (Replacement : String) return Boolean is
         begin
            for Ch of Replacement loop
               if Ch in '\' | '&' then
                  return False;
               end if;
            end loop;
            return True;
         end Is_Plain_Replacement;
      begin
         Handled := False;
         if Suppress_Automatic_Output
           or else Sedlib.Programs.Instruction_Count (Engine_Program) /= 1
           or else Sedlib.Programs.Kind (Engine_Program, 1) /=
             Sedlib.Programs.Substitute
           or else Sedlib.Programs.First_Address_Kind (Engine_Program, 1) /=
             Sedlib.Programs.No_Address
           or else Sedlib.Programs.Second_Address_Kind (Engine_Program, 1) /=
             Sedlib.Programs.No_Address
           or else Sedlib.Programs.Is_Negated (Engine_Program, 1)
           or else Sedlib.Programs.Substitution_Print (Engine_Program, 1)
           or else Sedlib.Programs.Substitution_Case_Insensitive
             (Engine_Program, 1)
           or else Sedlib.Programs.Substitution_Occurrence
             (Engine_Program, 1) /= 0
           or else Sedlib.Programs.Substitution_Has_Write
             (Engine_Program, 1)
         then
            return;
         end if;

         Expression :=
           Sedlib.Programs.Substitution_Expression (Engine_Program, 1);
         if not Regexp.Is_Literal (Expression) then
            return;
         end if;

         Regexp.Copy_Source_Pattern
           (Expression, Pattern_Buffer, Pattern_Last, Copy_Result);
         if Copy_Result /= Regexp.Copy_Ok
           or else Pattern_Last = 0
           or else not Is_Plain_Pattern
             (Pattern_Buffer (Pattern_Buffer'First .. Pattern_Last))
         then
            return;
         end if;

         declare
            Pattern : constant String :=
              Pattern_Buffer (Pattern_Buffer'First .. Pattern_Last);
            Replacement : constant String :=
              Sedlib.Text.To_String
                (Sedlib.Programs.Substitution_Replacement
                   (Engine_Program, 1));
            Global : constant Boolean :=
              Sedlib.Programs.Substitution_Global (Engine_Program, 1);

            function Substitute (Text : String) return String is
               Match : Natural := Ada.Strings.Fixed.Index (Text, Pattern);
            begin
               if Match = 0 then
                  return Text;
               elsif not Global then
                  return
                    (if Match = Text'First then ""
                     else Text (Text'First .. Match - 1))
                    & Replacement
                    & (if Match + Pattern'Length > Text'Last then ""
                       else Text (Match + Pattern'Length .. Text'Last));
               end if;

               declare
                  Output : Ada.Strings.Unbounded.Unbounded_String;
                  First  : Natural := Text'First;
               begin
                  loop
                     if Match > First then
                        Ada.Strings.Unbounded.Append
                          (Output, Text (First .. Match - 1));
                     end if;
                     Ada.Strings.Unbounded.Append (Output, Replacement);
                     First := Match + Pattern'Length;
                     exit when First > Text'Last;
                     Match :=
                       Ada.Strings.Fixed.Index
                         (Source => Text,
                          Pattern => Pattern,
                          From => First);
                     exit when Match = 0;
                  end loop;
                  if First <= Text'Last then
                     Ada.Strings.Unbounded.Append
                       (Output, Text (First .. Text'Last));
                  end if;
                  return Ada.Strings.Unbounded.To_String (Output);
               end;
            end Substitute;

            Item   : Sed.Input.Input_Line;
            Status : Sed.Input.Record_Status;
         begin
            if not Is_Plain_Replacement (Replacement) then
               return;
            end if;

            Handled := True;
            Result :=
              (Succeeded => False,
               Diagnostics => D.Empty_List,
               Lines_Read => 0);
            loop
               Sed.Input.Logical_Stream.Next (Source.all, Item, Status);
               case Status is
                  when Sed.Input.Record_Available =>
                     Result.Lines_Read := Result.Lines_Read + 1;
                     Sed.Output.Standard.Write
                       (Target.all,
                        Substitute
                          (Sed.Input.U.To_String (Item.Data)),
                        Sed.Output.Policy_For (Item.Has_Terminator));
                     exit when Sed.Output.Standard.Failed (Target.all);
                  when Sed.Input.End_Of_Input =>
                     Result.Succeeded := True;
                     exit;
                  when Sed.Input.Read_Failed =>
                     exit;
               end case;
            end loop;

            Sed.Input.Logical_Stream.Take_Diagnostics
              (Source.all, Reported);
            for Index in 1 .. D.Length (Reported) loop
               D.Append
                 (Result.Diagnostics, D.Element (Reported, Index));
            end loop;

            if Sed.Output.Standard.Failed (Target.all) then
               D.Append_Unique
                 (Result.Diagnostics,
                  Sed.Output.Standard.Failure (Target.all));
               Result.Succeeded := False;
            end if;
         end;
      end Try_Run_Literal_Substitution;
   begin
      Result := (Succeeded => False,
                 Diagnostics => D.Empty_List,
                 Lines_Read => 0);

      declare
         Handled : Boolean;
      begin
         Try_Run_Literal_Substitution (Handled);
         if Handled then
            return;
         end if;
      end;

      Environment.Initialize (Records, Source);
      Environment.Initialize (Sink, Target);
      Environment.Initialize (Resources, Files, Named);

      Sedlib.Execution.Execute
        (Program => Sed.Scripts.Compilation.Engine.Program_Of (Program),
         Source => Records,
         Sink => Sink,
         Options => Command_Line_Options (Suppress_Automatic_Output),
         Result => Engine_Result,
         Resources => Resources'Access);

      Result.Lines_Read := Environment.Lines_Read (Records);

      --  Diagnostics the input stream and the resource adapter produced while
      --  the engine was running are part of this run's outcome.
      Sed.Input.Logical_Stream.Take_Diagnostics (Source.all, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      Environment.Take_Diagnostics (Resources, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      Sed.Output.Named_Files.Take_Diagnostics (Named.all, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      --  Then whatever the engine itself reported.
      declare
         use type D.Diagnostic_Code;

         Engine_Diagnostics : constant Sedlib.Diagnostics.Diagnostic_List :=
           Engine_Result.Diagnostics;

         --  When the standard-output writer has failed, the engine also
         --  reports that its sink rejected a write. Only one of the two is
         --  news, and the writer is the one that knows why.
         Output_Already_Reported : constant Boolean :=
           Sed.Output.Standard.Failed (Target.all);
      begin
         for Index in 1 .. Sedlib.Diagnostics.Length (Engine_Diagnostics) loop
            declare
               Item : constant Sedlib.Diagnostics.Diagnostic :=
                 Sedlib.Diagnostics.Element (Engine_Diagnostics, Index);
               Translated : constant D.Diagnostic := Sed.Engine.Translate (Item);
            begin
               if Sed.Engine.Is_Reportable (Item)
                 and then not (Output_Already_Reported
                               and then D.Code (Translated)
                                        = D.Standard_Output_Failed)
               then
                  D.Append_Unique (Result.Diagnostics, Translated);
               end if;
            end;
         end loop;
      end;

      if Sed.Output.Standard.Failed (Target.all) then
         D.Append_Unique
           (Result.Diagnostics, Sed.Output.Standard.Failure (Target.all));
      end if;

      --  q and Q are ordinary, successful terminations; only a genuine fault
      --  makes the run unsuccessful.
      Result.Succeeded :=
        Engine_Result.Succeeded
        or else Engine_Result.Termination = Sedlib.Execution.Quit_Command
        or else Engine_Result.Termination =
                  Sedlib.Execution.Quit_Without_Output_Command;

      if Sed.Output.Standard.Failed (Target.all) then
         Result.Succeeded := False;
      end if;
   end Run;

end Sed.Execution;
