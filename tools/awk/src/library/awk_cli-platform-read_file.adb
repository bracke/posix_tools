separate (Awk_CLI.Platform)
function Read_File
  (Path    : String;
   Content : out U.Unbounded_String) return Read_Status
is
begin
   return File_IO.Read_File (Path, Content);
end Read_File;
