with Ada.Streams.Stream_IO;

package body Posix_Tools.Host_Adapters.Output_Files is
   use Hostkit.Descriptors;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_IO.Count;

   procedure Close (File : in out Output_File; Ok : out Boolean) is
   begin
      Ok := Close (File.Descriptor);
   end Close;

   function Is_Open (File : Output_File) return Boolean is
     (Is_Valid (File.Descriptor));

   procedure Open
     (File        : in out Output_File;
      Path        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean) is
   begin
      Close (File.Descriptor);
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
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      First   : Ada.Streams.Stream_Element_Offset := Buffer'First;
      Written : Ada.Streams.Stream_Element_Offset;
   begin
      for I in Text'Range loop
         Buffer (Ada.Streams.Stream_Element_Offset (I - Text'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Text (I)));
      end loop;

      Ok := True;
      while First <= Buffer'Last loop
         case Write (File.Descriptor, Buffer (First .. Buffer'Last), Written) is
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
         Ok := False;
   end Write;

   procedure Write_At
     (Path     : String;
      Offset   : Long_Long_Integer;
      Text     : String;
      Truncate : Boolean;
      Ok       : out Boolean)
   is
      --  Hostkit descriptors cannot seek, and a seek is what leaves the gap
      --  before Offset a hole rather than written zeros.
      package Stream_IO renames Ada.Streams.Stream_IO;

      File  : Stream_IO.File_Type;
      Start : constant Stream_IO.Positive_Count := Stream_IO.Positive_Count (Offset + 1);
   begin
      Ok := False;
      if Truncate then
         Stream_IO.Create (File, Stream_IO.Out_File, Path);
      else
         --  Out_File opens a stream file without truncating it.
         Stream_IO.Open (File, Stream_IO.Out_File, Path);
      end if;

      if Text'Length > 0 then
         declare
            Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
         begin
            for I in Text'Range loop
               Buffer (Ada.Streams.Stream_Element_Offset (I - Text'First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Text (I)));
            end loop;
            Stream_IO.Set_Index (File, Start);
            Stream_IO.Write (File, Buffer);
         end;
      elsif not Truncate and then Offset > 0 and then Stream_IO.Size (File) < Stream_IO.Count (Offset) then
         --  The last byte before Offset makes the file that long.
         Stream_IO.Set_Index (File, Start - 1);
         Stream_IO.Write (File, [1 => 0]);
      end if;

      Stream_IO.Close (File);
      Ok := True;
   exception
      when others =>
         if Stream_IO.Is_Open (File) then
            Stream_IO.Close (File);
         end if;
         Ok := False;
   end Write_At;
end Posix_Tools.Host_Adapters.Output_Files;
