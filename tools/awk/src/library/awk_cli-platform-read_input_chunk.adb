separate (Awk_CLI.Platform)
function Read_Input_Chunk
  (Stream      : in out Input_Stream;
   Content     : out U.Unbounded_String;
   End_Of_File : out Boolean) return Read_Status
is
begin
   return Input_Streams.Read_Chunk (Stream, Content, End_Of_File);
end Read_Input_Chunk;
