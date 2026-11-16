with Ada.Streams;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.File_Helpers is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;

   Buffer_Size : constant Positive := 16 * 1024;
   Bulk_Buffer_Size : constant Positive :=
     Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length;

   procedure Copy_Byte_Prefix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Bytes     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
      Remaining : Posix_Tools.Numbers.Count := Bytes;

      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      generic
         Input_Buffer_Size : Positive;
      procedure Copy_Standard_Input_Prefix;

      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         Available : constant Posix_Tools.Numbers.Count :=
           Posix_Tools.Numbers.Count (Last - Buffer'First + 1);
         To_Copy   : constant Posix_Tools.Numbers.Count :=
           Posix_Tools.Numbers.Count'Min (Remaining, Available);
         Copy_Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Last < Buffer'First or else Remaining = 0 then
            Stop := Remaining = 0;
            return;
         end if;

         Copy_Last := Buffer'First + Ada.Streams.Stream_Element_Offset (To_Copy) - 1;
         Context.Put_Bytes (Buffer, Copy_Last);
         if Context.Output_Failed then
            Ok := False;
            Stop := True;
         else
            Remaining := Remaining - To_Copy;
            Stop := Remaining = 0;
         end if;
      end Copy_Chunk;

      procedure Copy_Standard_Input_Prefix is
         Buffer : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Input_Buffer_Size));
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : Boolean := False;
      begin
         while Remaining > 0 loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Ok := False;
               return;
            end if;
            exit when Last < Buffer'First;
            Copy_Chunk (Buffer, Last, Stop);
            exit when Stop;
         end loop;
      end Copy_Standard_Input_Prefix;

      procedure Copy_Bounded_Standard_Input is new Copy_Standard_Input_Prefix
        (Input_Buffer_Size => Buffer_Size);
      procedure Copy_Bulk_Standard_Input is new Copy_Standard_Input_Prefix
        (Input_Buffer_Size => Bulk_Buffer_Size);
      procedure Iterate_Bounded is new
        Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
          (Action        => Copy_Chunk,
           Buffer_Length => Buffer_Size);
      procedure Iterate_Bulk is new
        Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
          (Action        => Copy_Chunk,
           Buffer_Length => Bulk_Buffer_Size);

      Use_Bulk : constant Boolean :=
        Bytes >= Posix_Tools.Numbers.Count (Bulk_Buffer_Size);
   begin
      Ok := True;

      if Bytes = 0 then
         return;
      elsif File_Name = "-" then
         if Use_Bulk then
            Copy_Bulk_Standard_Input;
         else
            Copy_Bounded_Standard_Input;
         end if;
      elsif Use_Bulk then
         Iterate_Bulk (File_Name, Ok);
      else
         Iterate_Bounded (File_Name, Ok);
      end if;

      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
          (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
           "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_Byte_Prefix;

   procedure Copy_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean)
   is
      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         if Last >= Buffer'First then
            Context.Put_Bytes (Buffer, Last);
            Stop := Context.Output_Failed;
         end if;
      end Copy_Chunk;
   begin
      Ok := True;

      if File_Name = "-" then
         Posix_Tools.Commands.File_Helpers.Streaming.Copy_Standard_Input (Context, Ok);
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action        => Copy_Chunk,
               Buffer_Length =>
                 Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
         begin
            Iterate (File_Name, Ok);
         end;
         if Ok then
            Ok := not Context.Output_Failed;
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
         end if;
      end if;
   end Copy_File;

   procedure Copy_Line_Prefix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
      Emitted : Posix_Tools.Numbers.Count := 0;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      generic
         Input_Buffer_Size : Positive;
      procedure Scan_Standard_Input;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         Copy_Last : Ada.Streams.Stream_Element_Offset := Last;
      begin
         if Last < Buffer'First or else Emitted >= Lines then
            Stop := Emitted >= Lines;
            return;
         end if;

         for I in Buffer'First .. Last loop
            if Character'Val (Integer (Buffer (I))) = Character'Val (10) then
               Emitted := Emitted + Posix_Tools.Numbers.Count (1);
               if Emitted >= Lines then
                  Copy_Last := I;
                  Stop := True;
                  exit;
               end if;
            end if;
         end loop;

         Context.Put_Bytes (Buffer, Copy_Last);
         if Context.Output_Failed then
            Ok := False;
            Stop := True;
         end if;
      end Scan_Chunk;

      procedure Scan_Standard_Input is
         Buffer : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Input_Buffer_Size));
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : Boolean := False;
      begin
         while Emitted < Lines loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Ok := False;
               exit;
            end if;
            exit when Last < Buffer'First;
            Scan_Chunk (Buffer, Last, Stop);
            exit when Stop;
         end loop;
      end Scan_Standard_Input;

      procedure Scan_Bounded_Standard_Input is new Scan_Standard_Input
        (Input_Buffer_Size => Buffer_Size);
      procedure Scan_Bulk_Standard_Input is new Scan_Standard_Input
        (Input_Buffer_Size => Bulk_Buffer_Size);
      procedure Iterate_Bounded is new
        Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
          (Action        => Scan_Chunk,
           Buffer_Length => Buffer_Size);
      procedure Iterate_Bulk is new
        Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
          (Action        => Scan_Chunk,
           Buffer_Length => Bulk_Buffer_Size);

      Use_Bulk : constant Boolean :=
        Lines >= Posix_Tools.Numbers.Count (Bulk_Buffer_Size);
   begin
      Ok := True;

      if File_Name = "-" then
         if Use_Bulk then
            Scan_Bulk_Standard_Input;
         else
            Scan_Bounded_Standard_Input;
         end if;
      else
         declare
            Read_Ok : Boolean;
         begin
            if Use_Bulk then
               Iterate_Bulk (File_Name, Read_Ok);
            else
               Iterate_Bounded (File_Name, Read_Ok);
            end if;
            Ok := Ok and Read_Ok;
         end;
      end if;

      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
          (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
           "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_Line_Prefix;

end Posix_Tools.Commands.File_Helpers;
