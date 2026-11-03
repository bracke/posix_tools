separate (Command_Tests.Locale_Tests)

   procedure Test_Pwd_Option_Precedence_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#5057_4431#;
      Seed     : Word_32 := Initial_Seed;
      Physical : constant String := "/physical/property";
      Logical  : constant String := "/logical/property";
      LF       : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Test_Support.Advance (Seed);
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            Context   : Test_Contexts.Capturing_Context;
            Result    : Posix_Tools.Commands.Results.Result;
            Args      : Posix_Tools.Arguments.Vector;
            Use_Logical : Boolean := True;
            Count     : constant Natural := Next_Value mod 9;
            Label     : constant String :=
              "pwd option precedence property "
              & Test_Support.Seed_Label (Initial_Seed)
              & " case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Count loop
               if Next_Value mod 2 = 0 then
                  Args.Append ("-L");
                  Use_Logical := True;
               else
                  Args.Append ("-P");
                  Use_Logical := False;
               end if;
            end loop;

            Context.Initialize ("pwd", Args);
            Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
            Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
            Posix_Tools.Commands.Pwd.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) =
                 (if Use_Logical then Logical & LF else Physical & LF),
               Label & " output");
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " status");
         end;
      end loop;
   end Test_Pwd_Option_Precedence_Property;
