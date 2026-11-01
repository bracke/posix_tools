with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.File_Helpers.Streaming is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   procedure Copy_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : out Boolean)
   is
      Buffer : Byte_Buffer;
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Ok := True;
      loop
         if not Context.Try_Read_Standard_Input (Buffer, Last) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Posix_Tools.Commands.Helpers.Standard_Input_Name (Context),
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Ok := False;
            return;
         end if;
         exit when Last < Buffer'First;
         Context.Put (Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;
      end loop;
   end Copy_Standard_Input;

   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean)
   is
      Buffer : Byte_Buffer;
      Last   : Ada.Streams.Stream_Element_Offset;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Action (Context, Buffer, Last);
         Stop := Stop_On_Output_Failure and then Context.Output_Failed;
      end Scan_Chunk;
   begin
      Ok := True;

      if File_Name = "-" then
         loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Ok := False;
               exit;
            end if;
            exit when Last < Buffer'First;
            Action (Context, Buffer, Last);
            exit when Stop_On_Output_Failure and then Context.Output_Failed;
         end loop;
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Scan_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
      end if;

      if Ok then
         Ok := not Context.Output_Failed;
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
         (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
          "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end For_Each_Chunk;

   procedure Read_All
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Data      : out Unbounded_String;
      Ok        : out Boolean)
   is
      procedure Append_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);

      procedure Append_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         Append (Data, Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
      end Append_Chunk;

      procedure Each_Chunk is new For_Each_Chunk (Action => Append_Chunk);
   begin
      Data := Null_Unbounded_String;
      Each_Chunk (Context, File_Name, Ok);
   end Read_All;

   function Read_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean) return String
   is
      Text : Unbounded_String;
   begin
      Read_All (Context, File_Name, Text, Ok);
      return To_String (Text);
   end Read_File;

end Posix_Tools.Commands.File_Helpers.Streaming;
