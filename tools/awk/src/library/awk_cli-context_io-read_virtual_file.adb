separate (Awk_CLI.Context_IO)
function Read_Virtual_File
  (Context : Invocation_Context;
   Path    : String;
   Content : out U.Unbounded_String;
   Found   : out Boolean) return Awk_CLI.Platform.Read_Status
is
begin
   Found := False;
   Content := U.Null_Unbounded_String;

   for File of Context.IO.Files loop
      if U.To_String (File.Path) = Path then
         Found := True;
         if not File.Openable then
            return Awk_CLI.Platform.Open_Failed;
         elsif not File.Readable then
            return Awk_CLI.Platform.Read_Failed;
         else
            Content := File.Content;
            return Awk_CLI.Platform.Read_Success;
         end if;
      end if;
   end loop;

   return Awk_CLI.Platform.Open_Failed;
end Read_Virtual_File;
