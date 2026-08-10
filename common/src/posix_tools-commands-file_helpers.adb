with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.File_Helpers is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;

   Buffer_Size : constant := 16 * 1024;
   Max_Tail_Retained_Bytes : constant Posix_Tools.Numbers.Count := 16 * 1024 * 1024;

   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

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

   function Subject_Name (File_Name : String) return String is
   begin
      if File_Name = "-" then
         return "standard input";
      else
         return File_Name;
      end if;
   end Subject_Name;

   procedure Append_Buffer_To_Lines
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : in out Unbounded_String;
      Action  : Line_Action;
      Ok      : in out Boolean)
   is
      Ch : Character;
   begin
      if Last < Buffer'First then
         return;
      end if;

      for I in Buffer'First .. Last loop
         Ch := Character_At (Buffer, I);
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
      Action  : Line_Action;
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

   procedure For_Each_Standard_Input_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Action  : Line_Action;
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
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Action    : Line_Action;
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
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
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
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end For_Each_Chunk;

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
         return;
      end if;

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
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
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
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_Line_Prefix;

   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
      Input   : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : Unbounded_String;
      Retained : Line_Vectors.Vector;
      Retained_Bytes : Posix_Tools.Numbers.Count := 0;

      procedure Keep_Current is
         Current_Length : constant Posix_Tools.Numbers.Count :=
           Posix_Tools.Numbers.Count (Length (Current));
      begin
         if Current_Length > Max_Tail_Retained_Bytes
           or else Retained_Bytes > Max_Tail_Retained_Bytes - Current_Length
         then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
            Ok := False;
            return;
         end if;

         Retained.Append (To_String (Current));
         Retained_Bytes := Retained_Bytes + Current_Length;
         if Posix_Tools.Numbers.Count (Retained.Length) > Lines then
            Retained_Bytes :=
              Retained_Bytes - Posix_Tools.Numbers.Count (Retained.First_Element'Length);
            Retained.Delete_First;
         end if;

         Current := Null_Unbounded_String;
      end Keep_Current;

      procedure Scan_Buffer is
         Ch : Character;
      begin
         if Last < Input'First then
            return;
         end if;

         for I in Input'First .. Last loop
            Ch := Character_At (Input, I);
            Append (Current, Ch);
            if Ch = Character'Val (10) then
               Keep_Current;
               exit when not Ok;
            end if;
         end loop;
      end Scan_Buffer;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Chunk_Last : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Input (Input'First .. Chunk_Last) := Buffer (Buffer'First .. Chunk_Last);
         Last := Chunk_Last;
         Scan_Buffer;
         Stop := not Ok;
      end Scan_Chunk;
   begin
      Ok := True;
      if Lines = 0 then
         if File_Name = "-"
           or else Posix_Tools.Host_Adapters.File_System.Can_Open_For_Read (File_Name)
         then
            return;
         end if;

         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Ok := False;
         return;
      end if;

      if File_Name = "-" then
         loop
            if not Context.Try_Read_Standard_Input (Input, Last) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, "standard input", "posix_tools.diagnostic.file.read_failed", "cannot read file");
               Ok := False;
               return;
            end if;
            exit when Last < Input'First;
            Scan_Buffer;
            exit when not Ok;
         end loop;
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Scan_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
         if not Ok then
           Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
            return;
         end if;
      end if;

      if Ok and then Length (Current) > 0 then
         Keep_Current;
      end if;

      if not Ok then
         return;
      end if;

      for Line of Retained loop
         Context.Put (Line);
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;
      end loop;
   end Copy_Line_Suffix;

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
      Input   : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : Unbounded_String;
      Seen    : Posix_Tools.Numbers.Count := 0;

      procedure Emit_Current is
      begin
         Seen := Seen + Posix_Tools.Numbers.Count (1);
         if First = 0 or else Seen >= First then
            Context.Put (To_String (Current));
         end if;

         Current := Null_Unbounded_String;
      end Emit_Current;

      procedure Scan_Buffer is
         Ch : Character;
      begin
         if Last < Input'First then
            return;
         end if;

         for I in Input'First .. Last loop
            Ch := Character_At (Input, I);
            Append (Current, Ch);
            if Ch = Character'Val (10) then
               Emit_Current;
               exit when Context.Output_Failed;
            end if;
         end loop;
      end Scan_Buffer;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Chunk_Last : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Input (Input'First .. Chunk_Last) := Buffer (Buffer'First .. Chunk_Last);
         Last := Chunk_Last;
         Scan_Buffer;
         Stop := Context.Output_Failed;
      end Scan_Chunk;
   begin
      Ok := True;
      if File_Name = "-" then
         loop
            if not Context.Try_Read_Standard_Input (Input, Last) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, "standard input", "posix_tools.diagnostic.file.read_failed", "cannot read file");
               Ok := False;
               return;
            end if;
            exit when Last < Input'First;
            Scan_Buffer;
            exit when Context.Output_Failed;
         end loop;
      else
         declare
            procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
              (Action => Scan_Chunk);
         begin
            Iterate (File_Name, Ok);
         end;
         if not Ok then
           Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
            return;
         end if;
      end if;

      if not Context.Output_Failed and then Length (Current) > 0 then
         Emit_Current;
      end if;

      Ok := not Context.Output_Failed;
   end Copy_Lines_From;

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
end Posix_Tools.Commands.File_Helpers;
