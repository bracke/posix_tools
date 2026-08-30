with Posix_Tools.Commands.File_Helpers.Copying;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.File_Helpers.Tailing;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;
with Posix_Tools.Text.File_Operands;

package body Posix_Tools.Commands.File_Helpers is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Numbers.Count;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   package FS renames Posix_Tools.Host_Adapters.File_System;

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

   function Character_At
     (Buffer : Ada.Streams.Stream_Element_Array;
      Index  : Ada.Streams.Stream_Element_Offset) return Character
   is
   begin
      return Character'Val (Integer (Buffer (Index)));
   end Character_At;

   function Join_Path (Directory, Leaf : String) return String is
   begin
      if Directory = "" or else Directory (Directory'Last) = '/' then
         return Directory & Leaf;
      else
         return Directory & "/" & Leaf;
      end if;
   end Join_Path;

   function Simple_Name (Path : String) return String is
   begin
      return FS.Simple_Name (Path);
   exception
      when others =>
         return Path;
   end Simple_Name;

   function Target_Path
     (Source              : String;
      Target              : String;
      Target_Is_Directory : Boolean) return String
   is
   begin
      if Target_Is_Directory then
         return FS.Join (Target, Posix_Tools.Paths.Basename (Source));
      else
         return Target;
      end if;
   end Target_Path;

   function Is_Directory (Path : String) return Boolean is
   begin
      return FS.Kind (Path) = FS.Directory;
   exception
      when others =>
         return False;
   end Is_Directory;

   function Remove_Non_Directory_Target (Path : String) return Boolean is
   begin
      if FS.Is_Link (Path) then
         return FS.Delete_Link (Path);
      elsif FS.Exists (Path) then
         if FS.Kind (Path) = FS.Directory then
            return False;
         end if;
         FS.Delete_File (Path);
      end if;

      return True;
   exception
      when others =>
         return False;
   end Remove_Non_Directory_Target;

   procedure Emit_Prefix_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Current : in out Unbounded_String;
      Lines   : Posix_Tools.Numbers.Count;
      Emitted : in out Posix_Tools.Numbers.Count;
      Ok      : in out Boolean)
   is
   begin
      if Emitted < Lines then
         Context.Put (To_String (Current));
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;

         Emitted := Emitted + Posix_Tools.Numbers.Count (1);
      end if;

      Current := Null_Unbounded_String;
   end Emit_Prefix_Line;

   procedure Append_Buffer_To_Line_Prefix
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Lines   : Posix_Tools.Numbers.Count;
      Emitted : in out Posix_Tools.Numbers.Count;
      Current : in out Unbounded_String;
      Ok      : in out Boolean)
   is
      Ch : Character;
   begin
      if Last < Buffer'First or else Emitted >= Lines then
         return;
      end if;

      for I in Buffer'First .. Last loop
         Ch := Character_At (Buffer, I);
         Append (Current, Ch);
         if Ch = Character'Val (10) then
            Emit_Prefix_Line (Context, Current, Lines, Emitted, Ok);
            exit when not Ok or else Emitted >= Lines;
         end if;
      end loop;
   end Append_Buffer_To_Line_Prefix;

   procedure Finish_Line_Prefix
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Lines   : Posix_Tools.Numbers.Count;
      Emitted : in out Posix_Tools.Numbers.Count;
      Current : in out Unbounded_String;
      Ok      : in out Boolean)
   is
   begin
      if Ok and then Length (Current) > 0 and then Emitted < Lines then
         Emit_Prefix_Line (Context, Current, Lines, Emitted, Ok);
      end if;
   end Finish_Line_Prefix;

   procedure Copy_Standard_Input_Line_Prefix
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Lines   : Posix_Tools.Numbers.Count;
      Ok      : out Boolean)
   is
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : Unbounded_String;
      Emitted : Posix_Tools.Numbers.Count := 0;
   begin
      Ok := True;
      while Emitted < Lines loop
         if not Context.Try_Read_Standard_Input (Buffer, Last) then
            Ok := False;
            return;
         end if;
         exit when Last < Buffer'First;
         Append_Buffer_To_Line_Prefix (Context, Buffer, Last, Lines, Emitted, Current, Ok);
         exit when not Ok;
      end loop;

      Finish_Line_Prefix (Context, Lines, Emitted, Current, Ok);
   end Copy_Standard_Input_Line_Prefix;

   procedure For_Each_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Action    : Line_Action;
      Ok        : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Line
        (Context, File_Name, Action, Ok);
   end For_Each_Line;

   procedure For_Each_Chunk
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean)
   is
      procedure Forward
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
      begin
         Action (Context, Buffer, Last);
      end Forward;

      procedure Iterate is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
        (Action => Forward);
   begin
      Iterate (Context, File_Name, Ok);
   end For_Each_Chunk;

   procedure Read_All
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Data      : out Unbounded_String;
      Ok        : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Streaming.Read_All
        (Context, File_Name, Data, Ok);
   end Read_All;

   function Read_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean) return String
   is
   begin
      return Posix_Tools.Commands.File_Helpers.Streaming.Read_File
        (Context, File_Name, Ok);
   end Read_File;

   function Read_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class) return String
   is
   begin
      return Posix_Tools.Commands.File_Helpers.Streaming.Read_Standard_Input (Context);
   end Read_Standard_Input;

   procedure Copy_Path
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Source         : String;
      Target         : String;
      Recursive      : Boolean;
      Preserve_Mode  : Boolean;
      Preserve_Links : Boolean;
      Ok             : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Copying.Copy_Path
        (Context, Source, Target, Recursive, Preserve_Mode, Preserve_Links, Ok);
   end Copy_Path;

   procedure Copy_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Ok        : out Boolean)
   is
      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         if Last >= Buffer'First then
            Context.Put (To_String (Buffer, Last));
            Stop := Context.Output_Failed;
         end if;
      end Copy_Chunk;
   begin
      Ok := True;

      if File_Name = "-" then
         Copy_Standard_Input (Context, Ok);
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Copy_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
         if Ok then
            Ok := not Context.Output_Failed;
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Posix_Tools.Text.File_Operands.Subject_Name (File_Name),
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
      Current : Unbounded_String;
      Emitted : Posix_Tools.Numbers.Count := 0;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Append_Buffer_To_Line_Prefix (Context, Buffer, Last, Lines, Emitted, Current, Ok);
         Stop := not Ok or else Emitted >= Lines;
      end Scan_Chunk;
   begin
      Ok := True;

      if File_Name = "-" then
         Copy_Standard_Input_Line_Prefix (Context, Lines, Ok);
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Scan_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
         Finish_Line_Prefix (Context, Lines, Emitted, Current, Ok);
      end if;

      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
          (Context, Posix_Tools.Text.File_Operands.Subject_Name (File_Name),
           "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_Line_Prefix;

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
         Context.Put (To_String (Buffer (Buffer'First .. Copy_Last), Copy_Last));
         if Context.Output_Failed then
            Ok := False;
            Stop := True;
         else
            Remaining := Remaining - To_Copy;
            Stop := Remaining = 0;
         end if;
      end Copy_Chunk;

      procedure Copy_Standard_Input_Prefix is
         Buffer : Byte_Buffer;
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
   begin
      Ok := True;

      if Bytes = 0 then
         return;
      elsif File_Name = "-" then
         Copy_Standard_Input_Prefix;
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Copy_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
      end if;

      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
          (Context, Posix_Tools.Text.File_Operands.Subject_Name (File_Name),
           "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_Byte_Prefix;

   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix
        (Context, File_Name, Lines, Ok);
   end Copy_Line_Suffix;

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Tailing.Copy_Lines_From
        (Context, File_Name, First, Ok);
   end Copy_Lines_From;

   procedure Copy_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Streaming.Copy_Standard_Input
        (Context, Ok);
   end Copy_Standard_Input;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
   begin
      Posix_Tools.Commands.File_Helpers.Streaming.Write_File
        (Path, Text, Append_Mode, Ok);
   end Write_File;
end Posix_Tools.Commands.File_Helpers;
