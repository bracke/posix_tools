separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Sort_Large_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Hostkit.Limits.Amount;
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      LF       : constant Character := Character'Val (10);
      Count    : constant := 50_000;
      Input    : Unbounded_String;
      Expected : Unbounded_String;
      Stable_Input : Unbounded_String;
      Old_Open_Limit : Hostkit.Limits.Amount := Hostkit.Limits.Unbounded;
      Limit_Read     : Boolean := False;
      Limit_Lowered  : Boolean := False;
      Tmpdir_Was_Set : Boolean := False;
      Tmpdir_Changed : Boolean := False;
      Old_Tmpdir     : Unbounded_String;

      procedure Restore_Open_Limit is
         Restored : Boolean;
      begin
         if Limit_Lowered then
            Restored := Hostkit.Limits.Set_Limit
              (Hostkit.Limits.Open_Files, Hostkit.Limits.Soft,
               Old_Open_Limit);
            AUnit.Assertions.Assert (Restored, "open-file limit restored");
            Limit_Lowered := False;
         end if;
      end Restore_Open_Limit;

      procedure Restore_Tmpdir is
      begin
         if Tmpdir_Changed then
            if Tmpdir_Was_Set then
               Ada.Environment_Variables.Set
                 ("TMPDIR", To_String (Old_Tmpdir));
            else
               Ada.Environment_Variables.Clear ("TMPDIR");
            end if;
            Tmpdir_Changed := False;
         end if;
      end Restore_Tmpdir;

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
      --  Force many external runs with bounded input so the heap merge and
      --  positioned spill reads are covered without a huge test fixture.
      Test_Contexts.Set_Sort_Memory_Threshold
        (Context, Posix_Tools.Numbers.Count (8 * 1024));
      Test_Contexts.Set_Standard_Input (Context, To_String (Input));

      --  The fixture creates more than 200 runs.  Where the host exposes an
      --  open-file limit, 64 descriptors proves the merge consumes runs in
      --  bounded groups rather than retaining one descriptor per run.
      Limit_Read := Hostkit.Limits.Limit
        (Hostkit.Limits.Open_Files, Hostkit.Limits.Soft,
         Old_Open_Limit);
      if Limit_Read
        and then Old_Open_Limit > Hostkit.Limits.Amount (64)
      then
         Limit_Lowered := Hostkit.Limits.Set_Limit
           (Hostkit.Limits.Open_Files, Hostkit.Limits.Soft, 64);
         AUnit.Assertions.Assert
           (Limit_Lowered, "open-file limit lowered for bounded merge");
      end if;
      Posix_Tools.Commands.Sort.Run (Context, Result);
      Restore_Open_Limit;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = To_String (Expected),
         "sort orders 50000 lines");

      --  Exercise a non-direct key through more than one merge pass.  Every
      --  key is equal, so -s must retain input order across pass boundaries.
      for I in 0 .. 9_999 loop
         Append (Stable_Input, "key " & Image ((I * 7919) mod 10_000) & LF);
      end loop;
      Context.Initialize ("sort", Two_Args ("-s", "-k1,1"));
      Test_Contexts.Set_Locale (Context, "C");
      Test_Contexts.Set_Sort_Memory_Threshold
        (Context, Posix_Tools.Numbers.Count (8 * 1024));
      Test_Contexts.Set_Standard_Input (Context, To_String (Stable_Input));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = To_String (Stable_Input),
         "stable sort preserves equal keys across merge passes");

      Context.Initialize ("sort", Two_Args ("-u", "-k1,1"));
      Test_Contexts.Set_Locale (Context, "C");
      Test_Contexts.Set_Sort_Memory_Threshold
        (Context, Posix_Tools.Numbers.Count (8 * 1024));
      Test_Contexts.Set_Standard_Input (Context, To_String (Stable_Input));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "key " & Image (0) & LF,
         "unique sort keeps the first equal key across merge passes");

      --  An exception from the output boundary must still release every
      --  temporary run.  Deleting the private TMPDIR succeeds only when the
      --  sort exception path removed all of its spill directories.
      declare
         Spill_Root : constant String :=
           Test_Support.Work_Path ("sort-exception-spills");
         Raised     : Boolean := False;
      begin
         if Ada.Directories.Exists (Spill_Root) then
            Ada.Directories.Delete_Tree (Spill_Root);
         end if;
         Ada.Directories.Create_Directory (Spill_Root);
         Tmpdir_Was_Set := Ada.Environment_Variables.Exists ("TMPDIR");
         if Tmpdir_Was_Set then
            Old_Tmpdir := To_Unbounded_String
              (Ada.Environment_Variables.Value ("TMPDIR"));
         end if;
         Ada.Environment_Variables.Set ("TMPDIR", Spill_Root);
         Tmpdir_Changed := True;

         Context.Initialize ("sort", No_Args);
         Test_Contexts.Set_Locale (Context, "C");
         Test_Contexts.Set_Sort_Memory_Threshold
           (Context, Posix_Tools.Numbers.Count (8 * 1024));
         Test_Contexts.Set_Standard_Input
           (Context, To_String (Stable_Input));
         Test_Contexts.Set_Output_Exception (Context);
         begin
            Posix_Tools.Commands.Sort.Run (Context, Result);
         exception
            when Constraint_Error =>
               Raised := True;
         end;
         Restore_Tmpdir;
         AUnit.Assertions.Assert
           (Raised, "sort propagates an injected output exception");
         Ada.Directories.Delete_Directory (Spill_Root);
      end;
   exception
      when others =>
         Restore_Open_Limit;
         Restore_Tmpdir;
         raise;
   end Test_Sort_Large_Input;
