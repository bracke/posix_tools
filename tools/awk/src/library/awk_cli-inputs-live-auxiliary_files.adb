separate (Awk_CLI.Inputs.Live)
function Auxiliary_Files
  (Context : Invocation_Context) return Input_File_Vectors.Vector
is
   Result : Input_File_Vectors.Vector;
begin
   if Context.Config.Use_Process then
      return Result;
   end if;

   for File of Context.IO.Files loop
      if File.Openable and then File.Readable then
         Result.Append (Input_File'(Name => File.Path, Content => File.Content));
      end if;
   end loop;

   return Result;
end Auxiliary_Files;
