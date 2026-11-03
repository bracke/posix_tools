separate (Command_Tests.Simple_Tests)

   procedure Test_True_False_Operand_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#7F00_F15E#;
      Seed : Word_32 := Initial_Seed;

      function Next_Value return Natural is
      begin
         Test_Support.Advance (Seed);
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Operand (Argument_Index : Positive) return String is
         Choices : constant Natural := Next_Value mod 9;
         Length  : Natural;
         Result  : Ada.Strings.Unbounded.Unbounded_String;
      begin
         case Choices is
            when 0 =>
               return "";
            when 1 =>
               return "-n";
            when 2 =>
               return "--";
            when 3 =>
               return "--help";
            when 4 =>
               return "--version";
            when 5 =>
               return "--posix-tools-identify";
            when others =>
               Length := 1 + Next_Value mod 8;
               for I in 1 .. Length loop
                  Ada.Strings.Unbounded.Append
                    (Result,
                     Character'Val
                       (Character'Pos ('a') + (Argument_Index + I + Next_Value) mod 26));
               end loop;
               return Ada.Strings.Unbounded.To_String (Result);
         end case;
      end Generated_Operand;

      function Sole_Extension (Operand : String) return Boolean is
      begin
         return Operand = "--help"
           or else Operand = "--version"
           or else Operand = "--posix-tools-identify";
      end Sole_Extension;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            True_Context  : Test_Contexts.Capturing_Context;
            False_Context : Test_Contexts.Capturing_Context;
            True_Result   : Posix_Tools.Commands.Results.Result;
            False_Result  : Posix_Tools.Commands.Results.Result;
            Args          : Posix_Tools.Arguments.Vector;
            Arg_Count     : constant Natural := Next_Value mod 9;
            Label         : constant String :=
              "true false operand property "
              & Test_Support.Seed_Label (Initial_Seed)
              & " case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Arg_Count loop
               declare
                  Generated : constant String := Generated_Operand (Index);
                  Operand   : constant String :=
                    (if Arg_Count = 1 and then Sole_Extension (Generated) then "ordinary" else Generated);
               begin
                  Args.Append (Operand);
               end;
            end loop;

            True_Context.Initialize ("true", Args);
            Posix_Tools.Commands.True_Command.Run (True_Context, True_Result);
            AUnit.Assertions.Assert (Test_Contexts.Output (True_Context) = "", Label & " true output");
            AUnit.Assertions.Assert (Test_Contexts.Error_Output (True_Context) = "", Label & " true stderr");
            AUnit.Assertions.Assert
              (True_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " true status");

            False_Context.Initialize ("false", Args);
            Posix_Tools.Commands.False_Command.Run (False_Context, False_Result);
            AUnit.Assertions.Assert (Test_Contexts.Output (False_Context) = "", Label & " false output");
            AUnit.Assertions.Assert (Test_Contexts.Error_Output (False_Context) = "", Label & " false stderr");
            AUnit.Assertions.Assert
              (False_Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
               Label & " false status");
         end;
      end loop;
   end Test_True_False_Operand_Property;
