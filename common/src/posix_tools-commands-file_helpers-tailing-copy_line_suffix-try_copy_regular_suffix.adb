separate (Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix)
procedure Try_Copy_Regular_Suffix (Handled : out Boolean) is
   File_Size : Long_Long_Integer;
   Start     : Long_Long_Integer;
   Window    : Long_Long_Integer;
   Line_Feeds : Posix_Tools.Numbers.Count;
   Lines_In_Window : Posix_Tools.Numbers.Count;
   Last_Byte : Ada.Streams.Stream_Element := 0;
   Saw_Byte  : Boolean;
   Read_Ok   : Boolean;

   procedure Report_Read_Failure is
   begin
      Posix_Tools.Commands.Helpers.Subject_Operational_Error
        (Context,
         Posix_Tools.Commands.Helpers.File_Subject
           (Context, File_Name),
         "posix_tools.diagnostic.file.read_failed",
         "cannot read file");
      Ok := False;
   end Report_Read_Failure;

   procedure Count_Chunk
     (Buffer : Ada.Streams.Stream_Element_Array;
      Chunk_Last : Ada.Streams.Stream_Element_Offset;
      Stop   : in out Boolean)
   is
      pragma Unreferenced (Stop);
   begin
      for I in Buffer'First .. Chunk_Last loop
         if Buffer (I) = Ada.Streams.Stream_Element (10) then
            Line_Feeds :=
              Line_Feeds + Posix_Tools.Numbers.Count (1);
         end if;
      end loop;
      Saw_Byte := True;
      Last_Byte := Buffer (Chunk_Last);
   end Count_Chunk;

   procedure Count_From is new
     Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk_From
       (Action => Count_Chunk);
begin
   Handled := False;
   if File /= null
     or else File_Name = "-"
     or else Context.Tail_Memory_Threshold <
       Posix_Tools.Numbers.Count (Bulk_Buffer_Size)
   then
      return;
   end if;

   begin
      if Posix_Tools.Host_Adapters.File_System.Kind (File_Name) /=
        Posix_Tools.Host_Adapters.File_System.Ordinary_File
      then
         return;
      end if;
   exception
      when Ada.IO_Exceptions.Use_Error =>
         Handled := True;
         Report_Read_Failure;
         return;
   end;

   Handled := True;
   File_Size := Posix_Tools.Host_Adapters.File_System.Size (File_Name);
   if File_Size = 0 then
      return;
   end if;

   Window := Long_Long_Integer'Min
     (File_Size, Long_Long_Integer (Bulk_Buffer_Size));
   Start := File_Size - Window;
   loop
      Line_Feeds := 0;
      Saw_Byte := False;
      Count_From (File_Name, Start, Read_Ok);
      if not Read_Ok then
         Report_Read_Failure;
         return;
      end if;

      Lines_In_Window :=
        Line_Feeds
        + (if Saw_Byte
             and then Last_Byte /= Ada.Streams.Stream_Element (10)
           then Posix_Tools.Numbers.Count (1)
           else 0);
      exit when Start = 0 or else Lines_In_Window > Lines;

      Start := Long_Long_Integer'Max (0, Start - Window);
      Window := File_Size - Start;
   end loop;

   if Start > 0 or else Lines_In_Window > Lines then
      declare
         To_Skip : constant Posix_Tools.Numbers.Count :=
           Lines_In_Window - Lines;
         Skipped  : Posix_Tools.Numbers.Count := 0;
         Position : Long_Long_Integer := Start;
         Found    : Boolean := False;

         procedure Find_Start
           (Buffer : Ada.Streams.Stream_Element_Array;
            Chunk_Last : Ada.Streams.Stream_Element_Offset;
            Stop   : in out Boolean)
         is
         begin
            for I in Buffer'First .. Chunk_Last loop
               if Buffer (I) = Ada.Streams.Stream_Element (10) then
                  Skipped := Skipped + Posix_Tools.Numbers.Count (1);
                  if Skipped = To_Skip then
                     Start :=
                       Position + Long_Long_Integer (I - Buffer'First) + 1;
                     Found := True;
                     Stop := True;
                     exit;
                  end if;
               end if;
            end loop;
            Position :=
              Position
              + Long_Long_Integer (Chunk_Last - Buffer'First + 1);
         end Find_Start;

         procedure Find_From is new
           Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk_From
             (Action => Find_Start);
      begin
         Find_From (File_Name, Start, Read_Ok);
         if not Read_Ok or else not Found then
            Report_Read_Failure;
            return;
         end if;
      end;
   end if;

   declare
      procedure Emit_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Chunk_Last : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Context.Put_Bytes (Buffer, Chunk_Last);
         Stop := Context.Output_Failed;
      end Emit_Chunk;

      procedure Emit_From is new
        Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk_From
          (Action => Emit_Chunk);
   begin
      Emit_From (File_Name, Start, Read_Ok);
      if not Read_Ok then
         Report_Read_Failure;
      elsif Context.Output_Failed then
         Ok := False;
      end if;
   end;
end Try_Copy_Regular_Suffix;
