separate (Awk_CLI.Context_IO)
function Write_File
  (Context : in out Invocation_Context;
   Path    : String;
   Content : String;
   Append  : Boolean) return Awk_CLI.Redirections.Write_Status
is
   procedure Record_Write is
   begin
      Context.IO.Writes.Append
        (Context_State.Write_Operation'
           (Path    => U.To_Unbounded_String (Path),
            Content => U.To_Unbounded_String (Content),
            Append  => Append));
   end Record_Write;

   procedure Add_New_Virtual_File is
   begin
      Context.IO.Files.Append
        (Context_State.Virtual_File'
           (Path     => U.To_Unbounded_String (Path),
            Content  => U.To_Unbounded_String (Content),
            Readable => True,
            Writable => True,
            Openable => True));
      Record_Write;
   end Add_New_Virtual_File;

   procedure Update_Virtual_File (Position : Positive) is
      File : Context_State.Virtual_File := Context.IO.Files.Element (Position);
   begin
      if Append then
         U.Append (File.Content, Content);
      else
         File.Content := U.To_Unbounded_String (Content);
      end if;

      Context.IO.Files.Replace_Element (Position, File);
      Record_Write;
   end Update_Virtual_File;

   function Write_Existing_Process_File
     (Position : Positive) return Awk_CLI.Redirections.Write_Status
   is
   begin
      if Awk_CLI.Platform.Write_File (Path, Content, Append) then
         Update_Virtual_File (Position);
         return Awk_CLI.Redirections.Write_Success;
      else
         return Awk_CLI.Redirections.Write_Failed;
      end if;
   end Write_Existing_Process_File;

   function Write_New_Process_File return Awk_CLI.Redirections.Write_Status is
   begin
      if Awk_CLI.Platform.Write_File (Path, Content, Append) then
         Add_New_Virtual_File;
         return Awk_CLI.Redirections.Write_Success;
      else
         return Awk_CLI.Redirections.Write_Failed;
      end if;
   end Write_New_Process_File;
begin
   if not Context.IO.Files.Is_Empty then
      for Position in Context.IO.Files.First_Index .. Context.IO.Files.Last_Index loop
         declare
            File : constant Context_State.Virtual_File :=
              Context.IO.Files.Element (Position);
         begin
            if U.To_String (File.Path) = Path then
               if not File.Openable then
                  return Awk_CLI.Redirections.Open_Failed;
               end if;
               if not File.Writable then
                  return Awk_CLI.Redirections.Write_Failed;
               end if;

               if Context.Config.Use_Process then
                  return Write_Existing_Process_File (Position);
               end if;

               Update_Virtual_File (Position);
               return Awk_CLI.Redirections.Write_Success;
            end if;
         end;
      end loop;
   end if;

   if Context.Config.Use_Process then
      return Write_New_Process_File;
   end if;

   Add_New_Virtual_File;
   return Awk_CLI.Redirections.Write_Success;
end Write_File;
