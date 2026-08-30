with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Operands;

package body Posix_Tools.Commands.File_Helpers.Streaming is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   is
      Result : String (1 .. Natural (Integer (Last) - Integer (Buffer'First) + 1));
      Target : Positive := Result'First;
   begin
      for I in Buffer'First .. Last loop
         Result (Target) := Character'Val (Integer (Buffer (I)));
         Target := Target + 1;
      end loop;

      return Result;
   end To_String;

   procedure Append_Buffer_To_Lines
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : in out Unbounded_String;
      Action  : Posix_Tools.Commands.File_Helpers.Line_Action;
      Ok      : in out Boolean)
   is
      Ch : Character;
   begin
      if Last < Buffer'First then
         return;
      end if;

      for I in Buffer'First .. Last loop
         Ch := Character'Val (Integer (Buffer (I)));
         Append (Current, Ch);
         if Ch = Character'Val (10) then
            Action (Context, To_String (Current));
            if Context.Output_Failed then
               Ok := False;
               return;
            end if;
            Current := Null_Unbounded_String;
         end if;
      end loop;
   end Append_Buffer_To_Lines;

   procedure Finish_Line_Scan
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Current : in out Unbounded_String;
      Action  : Posix_Tools.Commands.File_Helpers.Line_Action;
      Ok      : in out Boolean)
   is
   begin
      if Length (Current) > 0 then
         Action (Context, To_String (Current));
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;
         Current := Null_Unbounded_String;
      end if;
   end Finish_Line_Scan;

   procedure For_Each_Standard_Input_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Action  : Posix_Tools.Commands.File_Helpers.Line_Action;
      Ok      : out Boolean)
   is
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : Unbounded_String;
   begin
      Ok := True;
      loop
         if not Context.Try_Read_Standard_Input (Buffer, Last) then
            Ok := False;
            return;
         end if;
         exit when Last < Buffer'First;
         Append_Buffer_To_Lines (Context, Buffer, Last, Current, Action, Ok);
         exit when not Ok;
      end loop;

      if Ok then
         Finish_Line_Scan (Context, Current, Action, Ok);
      end if;
   end For_Each_Standard_Input_Line;

   procedure For_Each_Line
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Action    : Posix_Tools.Commands.File_Helpers.Line_Action;
      Ok        : out Boolean)
   is
      Current : Unbounded_String;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Append_Buffer_To_Lines (Context, Buffer, Last, Current, Action, Ok);
         Stop := not Ok;
      end Scan_Chunk;
   begin
      Ok := True;

      if File_Name = "-" then
         For_Each_Standard_Input_Line (Context, Action, Ok);
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Scan_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
         if Ok then
            Finish_Line_Scan (Context, Current, Action, Ok);
         end if;
      end if;

      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
          (Context, Posix_Tools.Text.File_Operands.Subject_Name (File_Name),
           "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end For_Each_Line;

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
         Stop   : in out Boolean)
      is
      begin
         Action (Context, Buffer, Last);
         Stop := Context.Output_Failed;
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
            exit when Context.Output_Failed;
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
         (Context, Posix_Tools.Text.File_Operands.Subject_Name (File_Name),
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
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         if Last >= Buffer'First then
            for I in Buffer'First .. Last loop
               Append (Data, Character'Val (Integer (Buffer (I))));
            end loop;
         end if;
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

   function Read_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class) return String
   is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Text   : Unbounded_String;
   begin
      loop
         exit when not Context.Try_Read_Standard_Input (Buffer, Last);
         exit when Last < Buffer'First;

         for I in Buffer'First .. Last loop
            Append (Text, Character'Val (Integer (Buffer (I))));
         end loop;
      end loop;

      return To_String (Text);
   end Read_Standard_Input;

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
              (Context, "standard input", "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Ok := False;
            return;
         end if;
         exit when Last < Buffer'First;
         Context.Put (To_String (Buffer, Last));
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;
      end loop;
   end Copy_Standard_Input;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
   begin
      Posix_Tools.Host_Adapters.File_System.Write_File (Path, Text, Append_Mode, Ok);
   end Write_File;
end Posix_Tools.Commands.File_Helpers.Streaming;
