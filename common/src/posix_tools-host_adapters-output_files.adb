package body Posix_Tools.Host_Adapters.Output_Files is
   use Hostkit.Descriptors;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_IO.Count;

   Text_Chunk_Size : constant := 64 * 1024;

   procedure Close (File : in out Output_File; Ok : out Boolean) is
   begin
      Ok := Close (File.Descriptor);
   end Close;

   overriding procedure Finalize (File : in out Output_File) is
      Closed : Boolean;
   begin
      Close (File, Closed);
   end Finalize;

   function Is_Open (File : Output_File) return Boolean is
     (Is_Valid (File.Descriptor));

   function Is_Open (File : Positioned_Output_File) return Boolean is
     (Ada.Streams.Stream_IO.Is_Open (File.Handle));

   procedure Close
     (File : in out Positioned_Output_File;
      Ok   : out Boolean) is
   begin
      if not Ada.Streams.Stream_IO.Is_Open (File.Handle) then
         Ok := True;
         return;
      end if;

      Ada.Streams.Stream_IO.Close (File.Handle);
      Ok := not Ada.Streams.Stream_IO.Is_Open (File.Handle);
   exception
      when others =>
         --  A delayed I/O error can be reported even when the Ada file object
         --  became closed.  Closure does not make that failed write succeed.
         --  intentional terminal exception barrier
         Ok := False;
   end Close;

   overriding procedure Finalize (File : in out Positioned_Output_File) is
      Closed : Boolean;
   begin
      Close (File, Closed);
   end Finalize;

   procedure Open
     (File        : in out Output_File;
      Path        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
      Closed : Boolean;
   begin
      if Is_Open (File) then
         Close (File, Closed);
         if not Closed then
            Ok := False;
            return;
         end if;
      end if;
      Ok :=
        Open_File (Path, (if Append_Mode then Open_Write_Append else Open_Write_Truncate), File.Descriptor);
      if not Ok then
         Close (File.Descriptor);
      end if;
   exception
      when others =>
         Close (File.Descriptor);
         Ok := False;
   end Open;

   procedure Write (File : Output_File; Text : String; Ok : out Boolean) is
      Text_First : Natural := Text'First;
   begin
      Ok := True;
      while Text_First <= Text'Last loop
         declare
            Text_Last : constant Natural :=
              Natural'Min (Text'Last, Text_First + Text_Chunk_Size - 1);
            Buffer    : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Text_Last - Text_First + 1));
         begin
            for I in Text_First .. Text_Last loop
               Buffer (Ada.Streams.Stream_Element_Offset (I - Text_First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (I)));
            end loop;
            Write (File, Buffer, Ok);
            if not Ok then
               return;
            end if;
            Text_First := Text_Last + 1;
         end;
      end loop;
   exception
      when others =>
         --  intentional terminal exception barrier
         Ok := False;
   end Write;

   procedure Write
     (File : Output_File;
      Data : Ada.Streams.Stream_Element_Array;
      Ok   : out Boolean)
   is
      First   : Ada.Streams.Stream_Element_Offset := Data'First;
      Written : Ada.Streams.Stream_Element_Offset;
   begin
      Ok := True;
      while First <= Data'Last loop
         case Write (File.Descriptor, Data (First .. Data'Last), Written) is
            when Transfer_Ok =>
               if Written < First then
                  Ok := False;
                  return;
               end if;
               First := Written + 1;
            when Transfer_Interrupted =>
               null;
            when others =>
               Ok := False;
               return;
         end case;
      end loop;
   exception
      when others =>
         --  intentional terminal exception barrier
         Ok := False;
   end Write;

   procedure Open_At
     (File     : in out Positioned_Output_File;
      Path     : String;
      Offset   : Long_Long_Integer;
      Truncate : Boolean;
      Ok       : out Boolean)
   is
      package Stream_IO renames Ada.Streams.Stream_IO;
      Closed : Boolean;
   begin
      --  Keep the conversion inside the handled statement sequence. In
      --  particular, Long_Long_Integer'Last has no successor to use as a
      --  one-based stream index.
      declare
         Start : constant Stream_IO.Positive_Count :=
           Stream_IO.Positive_Count (Offset + 1);
      begin
         if Stream_IO.Is_Open (File.Handle) then
            Close (File, Closed);
            if not Closed then
               Ok := False;
               return;
            end if;
         end if;
         if Truncate then
            Stream_IO.Create (File.Handle, Stream_IO.Out_File, Path);
         else
            Stream_IO.Open (File.Handle, Stream_IO.Out_File, Path);
            if Offset > 0
              and then Stream_IO.Size (File.Handle) < Stream_IO.Count (Offset)
            then
               Stream_IO.Set_Index (File.Handle, Start - 1);
               Stream_IO.Write (File.Handle, [1 => 0]);
            end if;
         end if;
         Stream_IO.Set_Index (File.Handle, Start);
         Ok := True;
      end;
   exception
      when others =>
         --  intentional terminal exception barrier
         Close (File, Closed);
         Ok := False;
   end Open_At;

   procedure Write
     (File : in out Positioned_Output_File;
      Text : String;
      Ok   : out Boolean)
   is
      First      : Natural := Text'First;
   begin
      while First <= Text'Last loop
         declare
            Last   : constant Natural :=
              Natural'Min (Text'Last, First + Text_Chunk_Size - 1);
            Buffer : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Last - First + 1));
         begin
            for I in First .. Last loop
               Buffer (Ada.Streams.Stream_Element_Offset (I - First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (I)));
            end loop;
            Write (File, Buffer, Ok);
            if not Ok then
               return;
            end if;
            First := Last + 1;
         end;
      end loop;
      Ok := True;
   exception
      when others =>
         --  intentional terminal exception barrier
         Ok := False;
   end Write;

   procedure Write
     (File : in out Positioned_Output_File;
      Data : Ada.Streams.Stream_Element_Array;
      Ok   : out Boolean) is
   begin
      Ada.Streams.Stream_IO.Write (File.Handle, Data);
      Ok := True;
   exception
      when others =>
         --  intentional terminal exception barrier
         Ok := False;
   end Write;

   procedure Write_At
     (Path     : String;
      Offset   : Long_Long_Integer;
      Text     : String;
      Truncate : Boolean;
      Ok       : out Boolean)
   is
      File     : Positioned_Output_File;
      Written  : Boolean;
      Closed   : Boolean;
   begin
      Open_At (File, Path, Offset, Truncate, Ok);
      if not Ok then
         return;
      end if;
      Write (File, Text, Written);
      Close (File, Closed);
      Ok := Written and Closed;
   end Write_At;
end Posix_Tools.Host_Adapters.Output_Files;
