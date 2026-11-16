with Posix_Tools.Commands.Helpers;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.File_Helpers.Streaming is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := Bulk_Buffer_Length;
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
         Context.Put_Bytes (Buffer, Last);
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;
      end loop;
   end Copy_Standard_Input;

   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean;
      Stop_Requested : access function return Boolean := null)
   is
      Buffer : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Length));
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
         Stop :=
           (Stop_On_Output_Failure and then Context.Output_Failed)
           or else (Stop_Requested /= null and then Stop_Requested.all);
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
            exit when
              (Stop_On_Output_Failure and then Context.Output_Failed)
              or else (Stop_Requested /= null and then Stop_Requested.all);
         end loop;
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Buffer_Length => Buffer_Length,
               Action        => Scan_Chunk);
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

   procedure For_Each_Follow_Chunk
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      File    : in out Posix_Tools.Host_Adapters.File_System.Follow_File;
      Ok      : out Boolean;
      Stop_Requested : access function return Boolean := null)
   is
      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean) is
      begin
         Action (Context, Buffer, Last);
         Stop :=
           (Stop_On_Output_Failure and then Context.Output_Failed)
           or else (Stop_Requested /= null and then Stop_Requested.all);
      end Scan_Chunk;

      procedure Iterate is new
        Posix_Tools.Host_Adapters.File_System.For_Each_Follow_Chunk
          (Action => Scan_Chunk);
   begin
      Iterate (File, Ok);
      if Ok then
         Ok := not Context.Output_Failed;
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context,
            Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
            "posix_tools.diagnostic.file.read_failed",
            "cannot read file");
      end if;
   end For_Each_Follow_Chunk;

   procedure For_Each_Line
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean)
   is
      Current : Ada.Strings.Unbounded.Unbounded_String;

      procedure Scan
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);

      procedure Scan
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         Start : Ada.Streams.Stream_Element_Offset := Buffer'First;
      begin
         if Last < Buffer'First then
            return;
         end if;
         for I in Buffer'First .. Last loop
            if Buffer (I) = Ada.Streams.Stream_Element (10) then
               if Start < I then
                  Ada.Strings.Unbounded.Append
                    (Current,
                     Posix_Tools.Streams.Bytes.To_String (Buffer (Start .. I - 1), I - 1));
               end if;
               Action (Context, Ada.Strings.Unbounded.To_String (Current), True);
               Current := Ada.Strings.Unbounded.Null_Unbounded_String;
               Start := I + 1;
               exit when Context.Output_Failed;
            end if;
         end loop;
         if not Context.Output_Failed and then Start <= Last then
            Ada.Strings.Unbounded.Append
              (Current, Posix_Tools.Streams.Bytes.To_String (Buffer (Start .. Last), Last));
         end if;
      end Scan;

      procedure Iterate is new For_Each_Chunk
        (Action        => Scan,
         Buffer_Length => Buffer_Length);
   begin
      Iterate (Context, File_Name, Ok);
      if Ok and then not Context.Output_Failed
        and then Ada.Strings.Unbounded.Length (Current) > 0
      then
         Action (Context, Ada.Strings.Unbounded.To_String (Current), False);
      end if;
      Ok := Ok and then not Context.Output_Failed;
   end For_Each_Line;

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

      procedure Each_Chunk is new For_Each_Chunk
        (Action        => Append_Chunk,
         Buffer_Length => Bulk_Buffer_Length);
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
