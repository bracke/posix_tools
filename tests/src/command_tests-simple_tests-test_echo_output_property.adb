separate (Command_Tests.Simple_Tests)

   procedure Test_Echo_Output_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#EC40_0001#;
      Seed : Word_32 := Initial_Seed;
      LF   : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Test_Support.Advance (Seed);
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Operand (Case_Index, Argument_Index : Positive) return String is
         pragma Unreferenced (Case_Index);
         Choices : constant Natural := Next_Value mod 10;
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
                  case Next_Value mod 7 is
                     when 0 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#5C#));
                     when 1 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#20#));
                     when 2 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#C3#));
                     when 3 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#A6#));
                     when others =>
                        Ada.Strings.Unbounded.Append
                          (Result,
                           Character'Val
                             (Character'Pos ('a') + (Argument_Index + I + Next_Value) mod 26));
                  end case;
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
            Context     : Test_Contexts.Capturing_Context;
            Result      : Posix_Tools.Commands.Results.Result;
            Args        : Posix_Tools.Arguments.Vector;
            Expected    : Ada.Strings.Unbounded.Unbounded_String;
            Arg_Count   : constant Natural := Next_Value mod 9;
            Label       : constant String :=
              "echo property " & Test_Support.Seed_Label (Initial_Seed)
              & " case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Arg_Count loop
               declare
                  Generated : constant String := Generated_Operand (Case_Index, Index);
                  Operand   : constant String :=
                    (if Arg_Count = 1 and then Sole_Extension (Generated) then "ordinary" else Generated);
               begin
                  Args.Append (Operand);
                  if Index > 1 then
                     Ada.Strings.Unbounded.Append (Expected, " ");
                  end if;
                  Ada.Strings.Unbounded.Append (Expected, Operand);
               end;
            end loop;
            Ada.Strings.Unbounded.Append (Expected, LF);

            Context.Initialize ("echo", Args);
            Posix_Tools.Commands.Echo.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Ada.Strings.Unbounded.To_String (Expected),
               Label & " output");
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               Label & " stderr");
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " status");
         end;
      end loop;
   end Test_Echo_Output_Property;
