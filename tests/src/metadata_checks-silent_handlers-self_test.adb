separate (Metadata_Checks.Silent_Handlers)
procedure Self_Test is
begin
   declare
      LF : constant Character := Character'Val (10);
      Split_Null : constant Handler_Info :=
        Inspect
          ("when others -- misleading =>" & LF
           & "  => null" & LF & "  ;",
           1);
      Marked_Null : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  --  intentional terminal exception barrier" & LF
           & "  null;",
           1);
      Negated_Marker : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  --  not an intentional terminal exception barrier" & LF
           & "  null;",
           1);
      Returning : constant Handler_Info :=
        Inspect ("when others => return;", 1);
      Wrapped : constant Handler_Info :=
        Inspect
          ("when others => begin" & LF
           & "  null;" & LF
           & "end;" & LF
           & "end;",
           1);
      Labeled : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  <<Ignored>>" & LF
           & "  null;" & LF
           & "end;",
           1);
      Named_Block : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  Cleanup : declare" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end Cleanup;" & LF
           & "end;",
           1);
      Split_Named_Block : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  Cleanup" & LF
           & "    : declare" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end Cleanup;" & LF
           & "end;",
           1);
      Pragmatic : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  pragma Warnings (Off);" & LF
           & "  null;" & LF
           & "end;",
           1);
      Declared : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Ignored : constant Boolean := True;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Debug_Pragma : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  pragma Debug (Log_Error);" & LF
           & "  null;" & LF
           & "end;",
           1);
      Action_Initializer : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Reported : constant Boolean := Log_Error;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Enum_Initializer : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Mode : State := Off;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Cleanup_Then_Reraise : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Restored : constant Boolean := Restore;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "  raise;" & LF
           & "end;",
           1);
      Operator_Initializer : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Value : constant Custom := ""a"" & ""b"";" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Raising_Initializer : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Value : constant Integer := 1 / 0;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Constraint_Elaboration : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Ignored : constant Boolean range False .. Probe := True;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Numeric_Constant : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Ignored : constant Natural := 0;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      String_Constant : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Ignored : constant String := ""text"";" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Character_Constant : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     Ignored : constant Character := 'x';" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Signed_Constant : constant Handler_Info :=
        Inspect
          ("when others => declare" & LF
           & "  Ignored : constant Integer := -1;" & LF
           & "begin null; end; end;",
           1);
      Real_Constant : constant Handler_Info :=
        Inspect
          ("when others => declare" & LF
           & "  Ignored : constant Long_Float := 1.25E-3;" & LF
           & "begin null; end; end;",
           1);
      Based_Constant : constant Handler_Info :=
        Inspect
          ("when others => declare" & LF
           & "  Ignored : constant Integer := 16#FF#;" & LF
           & "begin null; end; end;",
           1);
      Apostrophe_Constant : constant Handler_Info :=
        Inspect
          ("when others => declare" & LF
           & "  Ignored : constant Character := '''';" & LF
           & "begin null; end; end;",
           1);
      Followed_By_Action : constant Handler_Info :=
        Inspect
          ("when others => null; Recover;" & LF & "end;", 1);
      Terminal_Assignment : constant Handler_Info :=
        Inspect
          ("when others => Ignored := True;" & LF & "end;", 1);
      Assignment_Then_Null : constant Handler_Info :=
        Inspect
          ("when others => Ignored := True; null;" & LF & "end;", 1);
      Character_Assignment : constant Handler_Info :=
        Inspect
          ("when others => Ignored := ';';" & LF & "end;", 1);
      Nested_Raise_Expression : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     function F return Integer is (raise Program_Error);" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
      Exit_Transfer : constant Handler_Info :=
        Inspect ("when others => exit;" & LF & "end;", 1);
      Conditional_Exit_Transfer : constant Handler_Info :=
        Inspect ("when others => exit when Done;" & LF & "end;", 1);
      Continue_Transfer : constant Handler_Info :=
        Inspect ("when others => continue;" & LF & "end;", 1);
      Goto_Transfer : constant Handler_Info :=
        Inspect ("when others => goto Finished;" & LF & "end;", 1);
      Conditional_Statement : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  if False then Recover; end if;" & LF
           & "end;",
           1);
      Case_Statement : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  case Mode is when others => null; end case;" & LF
           & "end;",
           1);
      While_Loop : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  while False loop null; end loop;" & LF
           & "end;",
           1);
      For_Loop : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  for Item in 1 .. 0 loop null; end loop;" & LF
           & "end;",
           1);
      Plain_Loop : constant Handler_Info :=
        Inspect
          ("when others => loop exit; end loop;" & LF & "end;", 1);
      Select_Statement : constant Handler_Info :=
        Inspect
          ("when others => select delay 0.0; end select;" & LF & "end;", 1);
      Unclassified_Declaration : constant Handler_Info :=
        Inspect
          ("when others =>" & LF
           & "  declare" & LF
           & "     subtype Marker is Integer;" & LF
           & "  begin" & LF
           & "     null;" & LF
           & "  end;" & LF
           & "end;",
           1);
   begin
      if not Split_Named_Block.Is_Silent then
         Tooling_Checks.Fail ("split named block was not classified as silent");
      elsif not Action_Initializer.Is_Silent then
         Tooling_Checks.Fail ("initializer hid a silent handler");
      elsif not Enum_Initializer.Is_Silent then
         Tooling_Checks.Fail ("enum initializer hid a silent handler");
      elsif Cleanup_Then_Reraise.Is_Indeterminate
        or else Cleanup_Then_Reraise.Is_Silent
      then
         Tooling_Checks.Fail ("cleanup followed by re-raise was rejected");
      elsif not Terminal_Assignment.Is_Indeterminate then
         Tooling_Checks.Fail ("terminal assignment was accepted");
      elsif not Assignment_Then_Null.Is_Indeterminate then
         Tooling_Checks.Fail ("assignment followed by null was accepted");
      elsif not Character_Assignment.Is_Indeterminate then
         Tooling_Checks.Fail ("character assignment was accepted");
      elsif not Exit_Transfer.Is_Indeterminate
        or else not Conditional_Exit_Transfer.Is_Indeterminate
        or else not Continue_Transfer.Is_Indeterminate
        or else not Goto_Transfer.Is_Indeterminate
      then
         Tooling_Checks.Fail ("control transfer was accepted");
      elsif not Nested_Raise_Expression.Is_Indeterminate then
         Tooling_Checks.Fail ("nested raise expression was accepted");
      elsif not Conditional_Statement.Is_Indeterminate
        or else not Case_Statement.Is_Indeterminate
        or else not While_Loop.Is_Indeterminate
        or else not For_Loop.Is_Indeterminate
        or else not Plain_Loop.Is_Indeterminate
        or else not Select_Statement.Is_Indeterminate
      then
         Tooling_Checks.Fail ("compound handler statement was accepted");
      end if;
      if not Split_Null.Is_Silent
        or else Split_Null.Intentional
        or else not Marked_Null.Is_Silent
        or else not Marked_Null.Intentional
        or else not Negated_Marker.Is_Silent
        or else Negated_Marker.Intentional
        or else not Returning.Is_Silent
        or else Returning.Intentional
        or else not Wrapped.Is_Silent
        or else not Labeled.Is_Silent
        or else not Named_Block.Is_Silent
        or else not Split_Named_Block.Is_Silent
        or else not Pragmatic.Is_Silent
        or else not Declared.Is_Silent
        or else Debug_Pragma.Is_Silent
        or else not Action_Initializer.Is_Silent
        or else not Enum_Initializer.Is_Silent
        or else Cleanup_Then_Reraise.Is_Silent
        or else Cleanup_Then_Reraise.Is_Indeterminate
        or else not Operator_Initializer.Is_Silent
        or else not Raising_Initializer.Is_Silent
        or else not Constraint_Elaboration.Is_Silent
        or else not Numeric_Constant.Is_Silent
        or else not String_Constant.Is_Silent
        or else not Character_Constant.Is_Silent
        or else not Signed_Constant.Is_Silent
        or else not Real_Constant.Is_Silent
        or else not Based_Constant.Is_Silent
        or else not Apostrophe_Constant.Is_Silent
        or else Followed_By_Action.Is_Silent
        or else not Terminal_Assignment.Is_Indeterminate
        or else not Assignment_Then_Null.Is_Indeterminate
        or else not Character_Assignment.Is_Indeterminate
        or else not Exit_Transfer.Is_Indeterminate
        or else not Conditional_Exit_Transfer.Is_Indeterminate
        or else not Continue_Transfer.Is_Indeterminate
        or else not Goto_Transfer.Is_Indeterminate
        or else not Nested_Raise_Expression.Is_Indeterminate
        or else not Conditional_Statement.Is_Indeterminate
        or else not Case_Statement.Is_Indeterminate
        or else not While_Loop.Is_Indeterminate
        or else not For_Loop.Is_Indeterminate
        or else not Plain_Loop.Is_Indeterminate
        or else not Select_Statement.Is_Indeterminate
        or else not Unclassified_Declaration.Is_Silent
      then
         Tooling_Checks.Fail
           ("silent broad exception handler parser self-test failed");
      end if;
   end;
end Self_Test;
