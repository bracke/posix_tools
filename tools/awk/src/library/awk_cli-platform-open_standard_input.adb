separate (Awk_CLI.Platform)
function Open_Standard_Input
  (Stream : in out Input_Stream) return Read_Status
is
begin
   return Input_Streams.Open_Standard_Input (Stream);
end Open_Standard_Input;
