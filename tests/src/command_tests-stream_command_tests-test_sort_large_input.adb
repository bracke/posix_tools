separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Sort_Large_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      LF       : constant Character := Character'Val (10);
      Count    : constant := 50_000;
      Input    : Unbounded_String;
      Expected : Unbounded_String;

      function Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return [1 .. 6 - (Raw'Length - 1) => '0'] & Raw (Raw'First + 1 .. Raw'Last);
      end Image;
   begin
      --  A permutation of 0 .. Count - 1: 7919 is prime to Count.
      for I in 0 .. Count - 1 loop
         Append (Input, Image ((I * 7919) mod Count) & LF);
         Append (Expected, Image (I) & LF);
      end loop;

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "C");
      Test_Contexts.Set_Standard_Input (Context, To_String (Input));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = To_String (Expected),
         "sort orders 50000 lines");
   end Test_Sort_Large_Input;
