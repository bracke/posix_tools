separate (Command_Tests.Simple_Tests)

   procedure Test_Cat_Byte_Preservation_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#5054_0003#;
      Seed : Word_32 := Initial_Seed;

      function Next_Value return Word_32 is
      begin
         Test_Support.Advance (Seed);
         return Seed;
      end Next_Value;

      function Random_Natural (Modulo : Positive) return Natural is
      begin
         return Natural (Next_Value mod Word_32 (Modulo));
      end Random_Natural;

      function Generated_Bytes return String is
         Length : constant Natural := Random_Natural (513);
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            case Random_Natural (8) is
               when 0 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (0));
               when 1 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (10));
               when others =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (Random_Natural (256)));
            end case;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Bytes;
   begin
      for Case_Index in 1 .. 128 loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Input   : constant String := Generated_Bytes;
            Label   : constant String := Test_Support.Seed_Label (Initial_Seed) & " case" & Integer'Image (Case_Index);
         begin
            Context.Initialize ("cat", No_Args);
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat implicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat implicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat implicit stdin status for " & Label);

            Context.Initialize ("cat", One_Arg ("-"));
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat explicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat explicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat explicit stdin status for " & Label);
         end;
      end loop;
   end Test_Cat_Byte_Preservation_Property;
