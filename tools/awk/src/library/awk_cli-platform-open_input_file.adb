separate (Awk_CLI.Platform)
function Open_Input_File
  (Path   : String;
   Stream : in out Input_Stream) return Read_Status
is
begin
   return Input_Streams.Open_File (Path, Stream);
end Open_Input_File;
