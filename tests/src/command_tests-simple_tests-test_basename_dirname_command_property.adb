separate (Command_Tests.Simple_Tests)

   procedure Test_Basename_Dirname_Command_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#BA5E_D123#;
      Seed : Word_32 := Initial_Seed;
      LF   : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Test_Support.Advance (Seed);
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Path return String is
         Length : constant Natural := Next_Value mod 18;
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            case Next_Value mod 8 is
               when 0 | 1 =>
                  Ada.Strings.Unbounded.Append (Result, "/");
               when 2 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#5C#));
               when 3 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#C3#));
               when 4 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#A6#));
               when others =>
                  Ada.Strings.Unbounded.Append
                    (Result,
                     Character'Val (Character'Pos ('a') + (I + Next_Value) mod 26));
            end case;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Path;

      function Generated_Suffix (Path : String) return String is
      begin
         case Next_Value mod 5 is
            when 0 =>
               return "";
            when 1 =>
               return ".txt";
            when 2 =>
               return "x";
            when 3 =>
               if Path'Length = 0 then
                  return "";
               else
                  return Path (Path'Last .. Path'Last);
               end if;
            when others =>
               return Character'Val (16#C3#) & Character'Val (16#A6#);
         end case;
      end Generated_Suffix;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            Basename_Context : Test_Contexts.Capturing_Context;
            Dirname_Context  : Test_Contexts.Capturing_Context;
            Basename_Result  : Posix_Tools.Commands.Results.Result;
            Dirname_Result   : Posix_Tools.Commands.Results.Result;
            Path             : constant String := Generated_Path;
            Suffix           : constant String := Generated_Suffix (Path);
            Label            : constant String :=
              "basename dirname command property "
              & Test_Support.Seed_Label (Initial_Seed)
              & " case" & Natural'Image (Case_Index);
         begin
            Basename_Context.Initialize ("basename", Two_Args (Path, Suffix));
            Posix_Tools.Commands.Basename.Run (Basename_Context, Basename_Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Basename_Context) = Posix_Tools.Paths.Basename (Path, Suffix) & LF,
               Label & " basename output");
            AUnit.Assertions.Assert
              (Basename_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " basename status");

            Dirname_Context.Initialize ("dirname", One_Arg (Path));
            Posix_Tools.Commands.Dirname.Run (Dirname_Context, Dirname_Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Dirname_Context) = Posix_Tools.Paths.Dirname (Path) & LF,
               Label & " dirname output");
            AUnit.Assertions.Assert
              (Dirname_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " dirname status");
         end;
      end loop;
   end Test_Basename_Dirname_Command_Property;
