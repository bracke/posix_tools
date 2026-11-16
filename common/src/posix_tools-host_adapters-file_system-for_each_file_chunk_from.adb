separate (Posix_Tools.Host_Adapters.File_System)
procedure For_Each_File_Chunk_From
  (Path   : String;
   Offset : Long_Long_Integer;
   Ok     : out Boolean)
is
   File      : Ada.Streams.Stream_IO.File_Type;
   Buffer    : Byte_Buffer;
   Last      : Ada.Streams.Stream_Element_Offset;
   Stop      : Boolean := False;
   Callback_Active : aliased Boolean := False;

   procedure Invoke_Action is new Invoke_Chunk_Callback
     (Callback => Action);

   procedure Close_Safely is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others =>
         --  intentional terminal exception barrier
         null;
   end Close_Safely;
begin
   Ada.Streams.Stream_IO.Open
     (File, Ada.Streams.Stream_IO.In_File, Path);
   Ada.Streams.Stream_IO.Set_Index
     (File, Ada.Streams.Stream_IO.Positive_Count (Offset + 1));
   Ok := True;

   while not Stop loop
      Ada.Streams.Stream_IO.Read (File, Buffer, Last);
      exit when Last < Buffer'First;
      Invoke_Action (Buffer, Last, Stop, Callback_Active'Access);
   end loop;

   Ada.Streams.Stream_IO.Close (File);
exception
   when Ada.IO_Exceptions.End_Error =>
      declare
         Callback_Failed : constant Boolean := Callback_Active;
      begin
         Close_Safely;
         if Callback_Failed then
            raise;
         end if;
         Ok := True;
      end;
   when others =>
      --  intentional terminal exception barrier
      declare
         Callback_Failed : constant Boolean := Callback_Active;
      begin
         Close_Safely;
         if Callback_Failed then
            --  Cleanup must not replace the callback's exception.
            raise;
         end if;
         Ok := False;
      end;
end For_Each_File_Chunk_From;
