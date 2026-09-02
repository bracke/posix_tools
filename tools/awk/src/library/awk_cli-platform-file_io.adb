separate (Awk_CLI.Platform)
package body File_IO is
   function Read_File
     (Path    : String;
      Content : out U.Unbounded_String) return Read_Status
   is
      File   : SIO.File_Type;
      Opened : Boolean := False;
   begin
      Content := U.Null_Unbounded_String;
      if not Ada.Directories.Exists (Path) then
         return Open_Failed;
      end if;
      SIO.Open (File, SIO.In_File, Path);
      Opened := True;

      while not SIO.End_Of_File (File) loop
         declare
            Buffer : Ada.Streams.Stream_Element_Array (1 .. Byte_IO.Chunk_Size);
            Last   : Ada.Streams.Stream_Element_Offset;
         begin
            SIO.Read (File, Buffer, Last);
            U.Append (Content, Byte_IO.To_String (Buffer, Last));
         end;
      end loop;

      SIO.Close (File);
      return Read_Success;
   exception
      when Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error
         | Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error
         | Ada.Directories.Name_Error
         | Ada.Directories.Use_Error
         | Constraint_Error
         | Storage_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         Content := U.Null_Unbounded_String;
         return (if Opened then Read_Failed else Open_Failed);
   end Read_File;

   function Write_File
     (Path    : String;
      Content : String;
      Append  : Boolean) return Boolean
   is
      File     : SIO.File_Type;
      Mode     : constant SIO.File_Mode :=
        (if Append then SIO.Append_File else SIO.Out_File);
      Position : Natural := Content'First;
   begin
      if Append and then Ada.Directories.Exists (Path) then
         SIO.Open (File, Mode, Path);
      else
         SIO.Create (File, SIO.Out_File, Path);
      end if;

      while Position <= Content'Last loop
         declare
            Remaining : constant Natural := Content'Last - Position + 1;
            Count     : constant Natural :=
              Natural'Min (Remaining, Natural (Byte_IO.Chunk_Size));
            Last      : constant Ada.Streams.Stream_Element_Offset :=
              Ada.Streams.Stream_Element_Offset (Count);
            Buffer    : Ada.Streams.Stream_Element_Array (1 .. Byte_IO.Chunk_Size);
         begin
            for Offset in 0 .. Count - 1 loop
               Buffer (Ada.Streams.Stream_Element_Offset (Offset + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Content (Position + Offset)));
            end loop;
            SIO.Write (File, Buffer (1 .. Last));
            Position := Position + Count;
         end;
      end loop;

      SIO.Close (File);
      return True;
   exception
      when Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error
         | Ada.Directories.Name_Error
         | Ada.Directories.Use_Error
         | Constraint_Error
         | Storage_Error =>
         if SIO.Is_Open (File) then
            SIO.Close (File);
         end if;
         return False;
   end Write_File;
end File_IO;
