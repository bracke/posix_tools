separate (Posix_Tools.Commands.Cut.Run.Cut_File)
procedure Copy_All_Chunks (Ok : out Boolean) is
   Saw_Data    : Boolean := False;
   Ended_In_LF : Boolean := True;

   procedure Each_Chunk
     (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset);

   procedure Each_Chunk
     (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Ignored);
   begin
      if Last >= Buffer'First then
         Saw_Data := True;
         Ended_In_LF := Buffer (Last) = 10;
         Context.Put_Bytes (Buffer, Last);
      end if;
   end Each_Chunk;

   procedure Iterate_Chunks is new
     Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
       (Action        => Each_Chunk,
        Buffer_Length =>
          Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
begin
   Iterate_Chunks (Context, Name, Ok);
   if Ok and then Saw_Data and then not Ended_In_LF
     and then not Context.Output_Failed
   then
      Context.Put ([1 => Character'Val (10)]);
   end if;
   Ok := Ok and then not Context.Output_Failed;
end Copy_All_Chunks;
