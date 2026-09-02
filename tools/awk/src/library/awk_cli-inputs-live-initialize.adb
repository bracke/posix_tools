separate (Awk_CLI.Inputs.Live)
procedure Initialize
  (State    : out Live_Input_State;
   Context  : in out Invocation_Context;
   Operands : aliased Awk_CLI.Operands.Operand_Vectors.Vector)
is
begin
   --  Callback lifetime invariant: Context and Operands are owned by
   --  Awk_CLI.Invocation.Execute and outlive the synchronous awklib run
   --  that receives State'Address.
   State.Context := Context'Unchecked_Access;
   State.Operands := Operands'Unchecked_Access;
   State.Operand_Index := 0;
   State.Implicit_Stdin_Used := False;
   State.Active := False;
   State.Active_Process := False;
   State.Active_Name := U.Null_Unbounded_String;
   State.Active_Content := U.Null_Unbounded_String;
   State.Active_Position := 1;
   Awk_CLI.Platform.Close_Input (State.Process_Stream);
end Initialize;
