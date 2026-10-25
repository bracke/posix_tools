with Ada.Streams;

package body Posix_Tools.Host_Adapters.Output_Files is
   use Hostkit.Descriptors;
   use type Ada.Streams.Stream_Element_Offset;

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
end Posix_Tools.Host_Adapters.Output_Files;
