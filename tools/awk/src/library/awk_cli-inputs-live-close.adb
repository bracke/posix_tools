separate (Awk_CLI.Inputs.Live)
procedure Close (State : in out Live_Input_State) is
begin
   Awk_CLI.Platform.Close_Input (State.Process_Stream);
end Close;
