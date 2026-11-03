separate (Command_Tests.Root_Tests)

   procedure Test_Root_Verify_Status_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      function Is_Danish_Status (Status : String) return Boolean is
      begin
         return
           Status = "mangler"
           or else Status = "ikke eksekverbar"
           or else Status = "ok"
           or else Status = "skygget"
           or else Status = "kan ikke verificeres"
           or else Status = "forkert projekt"
           or else Status = "forkert version";
      end Is_Danish_Status;

      function Is_English_Status (Status : String) return Boolean is
      begin
         return
           Status = "missing"
           or else Status = "not executable"
           or else Status = "ok"
           or else Status = "shadowed"
           or else Status = "unverifiable"
           or else Status = "wrong project"
           or else Status = "wrong version";
      end Is_English_Status;

      procedure Assert_Verify_Status_Lines
        (Output_Text : String;
         Label       : String;
         Danish      : Boolean)
      is
         Position : Natural := Output_Text'First;
      begin
         for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
               Prefix  : constant String := Command & ": ";
               Start   : Natural;
               Stop    : Natural;
            begin
               AUnit.Assertions.Assert
                 (Position + Prefix'Length - 1 <= Output_Text'Last
                  and then Output_Text (Position .. Position + Prefix'Length - 1) = Prefix,
                  Label & " prefix for " & Command);
               Start := Position + Prefix'Length;
               Stop := Start;
               while Stop <= Output_Text'Last and then Output_Text (Stop) /= LF loop
                  Stop := Stop + 1;
               end loop;
               AUnit.Assertions.Assert
                 (Stop <= Output_Text'Last and then Output_Text (Stop) = LF,
                  Label & " line terminator for " & Command);
               AUnit.Assertions.Assert
                 (Start < Stop,
                  Label & " nonempty status for " & Command);
               declare
                  Status : constant String := Output_Text (Start .. Stop - 1);
               begin
                  AUnit.Assertions.Assert
                    ((if Danish then Is_Danish_Status (Status) else Is_English_Status (Status)),
                     Label & " localized status for " & Command & ": " & Status);
               end;
               Position := Stop + 1;
            end;
         end loop;

         AUnit.Assertions.Assert
           (Position = Output_Text'Last + 1,
            Label & " extra output after inventory lines");
      end Assert_Verify_Status_Lines;

      procedure Check (Locale, Label : String; Danish : Boolean) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("verify"));
         Test_Contexts.Set_Locale (Context, Locale);
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Expected_Verify_Status (Test_Contexts.Output (Context)),
            "root verify locale status " & Label);
         Assert_Verify_Status_Lines (Test_Contexts.Output (Context), Label, Danish);
         AUnit.Assertions.Assert
           (not Contains (Test_Contexts.Output (Context), "posix_tools."),
            "root verify locale no message-key leak " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root verify locale stderr " & Label);
      end Check;
   begin
      Check ("da", "da", True);
      Check ("zz-ZZ", "unknown", False);
   end Test_Root_Verify_Status_Locales;
