separate (Awk_CLI.Platform)
function Write_File
  (Path    : String;
   Content : String;
   Append  : Boolean) return Boolean
is
begin
   return File_IO.Write_File (Path, Content, Append);
end Write_File;
