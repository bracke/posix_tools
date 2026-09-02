separate (Awk_CLI.Platform)
procedure Close_Input (Stream : in out Input_Stream) is
begin
   Input_Streams.Close (Stream);
end Close_Input;
