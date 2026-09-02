separate (Awk_CLI.Platform)
package body Input_Streams is
   function Open_File
     (Path   : String;
      Stream : in out Input_Stream) return Read_Status
   is
   begin
      Close (Stream);
      if not Ada.Directories.Exists (Path) then
         return Open_Failed;
      end if;
      SIO.Open (Stream.File, SIO.In_File, Path);
      Stream.Opened := True;
      Stream.Is_Stdin := False;
      Stream.Stdin_Done := False;
      return Read_Success;
   exception
      when Ada.IO_Exceptions.Name_Error
         | Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.Status_Error
         | Ada.Directories.Name_Error
         | Ada.Directories.Use_Error =>
         Close (Stream);
         return Open_Failed;
   end Open_File;

   function Open_Standard_Input
     (Stream : in out Input_Stream) return Read_Status
   is
      use type System.Address;

      Handle : constant Interfaces.C_Streams.int :=
        Interfaces.C_Streams.fileno (Interfaces.C_Streams.stdin);
   begin
      Close (Stream);
      if Interfaces.C_Streams.stdin = Interfaces.C_Streams.NULL_Stream
        or else Handle < 0
      then
         return Open_Failed;
      end if;
      Interfaces.C_Streams.set_binary_mode (Handle);
      Stream.Opened := True;
      Stream.Is_Stdin := True;
      Stream.Stdin_Done := False;
      return Read_Success;
   end Open_Standard_Input;

   function Read_Stdin_Chunk
     (Stream      : in out Input_Stream;
      Content     : out U.Unbounded_String;
      End_Of_File : out Boolean) return Read_Status
   is
      use type Interfaces.C_Streams.size_t;

      Text : String (1 .. Natural (Byte_IO.Chunk_Size));
      Read : constant Interfaces.C_Streams.size_t :=
        Interfaces.C_Streams.fread
          (Text (Text'First)'Address,
           1,
           Interfaces.C_Streams.size_t (Text'Length),
           Interfaces.C_Streams.stdin);
   begin
      if Stream.Stdin_Done then
         End_Of_File := True;
         return Read_Success;
      end if;

      if Read = 0 then
         Stream.Stdin_Done := True;
         End_Of_File := True;
         if Interfaces.C_Streams.ferror (Interfaces.C_Streams.stdin) /= 0 then
            return Read_Failed;
         end if;
         return Read_Success;
      end if;

      Content := U.To_Unbounded_String (Text (1 .. Natural (Read)));
      return Read_Success;
   end Read_Stdin_Chunk;

   function Read_File_Chunk
     (Stream      : in out Input_Stream;
      Content     : out U.Unbounded_String;
      End_Of_File : out Boolean) return Read_Status
   is
   begin
      if SIO.End_Of_File (Stream.File) then
         End_Of_File := True;
         return Read_Success;
      end if;

      declare
         Buffer : Ada.Streams.Stream_Element_Array (1 .. Byte_IO.Chunk_Size);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         SIO.Read (Stream.File, Buffer, Last);
         if Last < Buffer'First then
            End_Of_File := True;
            return Read_Success;
         end if;

         Content := U.To_Unbounded_String (Byte_IO.To_String (Buffer, Last));
      end;

      End_Of_File := False;
      return Read_Success;
   end Read_File_Chunk;

   function Read_Chunk
     (Stream      : in out Input_Stream;
      Content     : out U.Unbounded_String;
      End_Of_File : out Boolean) return Read_Status
   is
   begin
      Content := U.Null_Unbounded_String;
      End_Of_File := False;

      if not Stream.Opened then
         End_Of_File := True;
         return Read_Failed;
      elsif Stream.Is_Stdin then
         return Read_Stdin_Chunk (Stream, Content, End_Of_File);
      else
         return Read_File_Chunk (Stream, Content, End_Of_File);
      end if;
   exception
      when Ada.IO_Exceptions.Use_Error
         | Ada.IO_Exceptions.Device_Error
         | Ada.IO_Exceptions.End_Error
         | Ada.IO_Exceptions.Data_Error
         | Ada.IO_Exceptions.Status_Error
         | Ada.IO_Exceptions.Mode_Error
         | Constraint_Error
         | Storage_Error =>
         Content := U.Null_Unbounded_String;
         End_Of_File := True;
         return Read_Failed;
   end Read_Chunk;

   procedure Close (Stream : in out Input_Stream) is
   begin
      if Stream.Opened and then not Stream.Is_Stdin and then SIO.Is_Open (Stream.File) then
         SIO.Close (Stream.File);
      end if;
      Stream.Opened := False;
      Stream.Is_Stdin := False;
      Stream.Stdin_Done := False;
   exception
      when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Status_Error =>
         Stream.Opened := False;
         Stream.Is_Stdin := False;
         Stream.Stdin_Done := False;
   end Close;
end Input_Streams;
