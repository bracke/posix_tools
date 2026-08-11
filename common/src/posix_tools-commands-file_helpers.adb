with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Temporary_Storage;

package body Posix_Tools.Commands.File_Helpers is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_Element;
   use type Posix_Tools.Numbers.Count;

   Buffer_Size : constant := 16 * 1024;
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

   procedure Copy_File_From
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name  : String;
      Start_Byte : Posix_Tools.Numbers.Count;
      New_Size   : out Posix_Tools.Numbers.Count;
      Ok         : out Boolean)
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
      New_Size := Start_Byte;
      Ok := True;

      if File_Name = "-" then
         return;
      end if;

      declare
         procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk_From
           (Action => Copy_Chunk);
      begin
         Iterate (File_Name, Start_Byte, New_Size, Ok);
      end;
      if Ok then
         Ok := not Context.Output_Failed;
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_File_From;

   function File_Size
     (File_Name : String;
      Size      : out Posix_Tools.Numbers.Count) return Boolean
   is
   begin
      if File_Name = "-" then
         Size := 0;
         return False;
      end if;

      return Posix_Tools.Host_Adapters.File_System.File_Size (File_Name, Size);
   end File_Size;

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
      Store : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
      Store_Available : Boolean := False;
      Spill_Needed : Boolean := False;
      Spill_Ok : Boolean := True;

      procedure Resource_Error is
      begin
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         Ok := False;
      end Resource_Error;

      procedure Append_To_Store
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset)
      is
      begin
         if Store_Available and then Spill_Ok then
            Spill_Ok := Posix_Tools.Host_Adapters.Temporary_Storage.Append (Store, Buffer, Last);
         end if;
      end Append_To_Store;

      procedure Emit_Store_From (Start : Posix_Tools.Numbers.Count) is
         Buffer : Byte_Buffer;
         Last   : Ada.Streams.Stream_Element_Offset;
         Next   : Posix_Tools.Numbers.Count := Start;
      begin
         while Next <= Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store) loop
            if not Posix_Tools.Host_Adapters.Temporary_Storage.Read (Store, Next, Buffer, Last) then
               Posix_Tools.Commands.Helpers.Operational_Error
                 (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
               Ok := False;
               return;
            end if;

            exit when Last < Buffer'First;
            Context.Put (To_String (Buffer, Last));
            if Context.Output_Failed then
               Ok := False;
               return;
            end if;

            Next := Next + Posix_Tools.Numbers.Count
              (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
         end loop;
      end Emit_Store_From;

      function Last_Byte_Is_LF return Boolean is
         One : Ada.Streams.Stream_Element_Array (1 .. 1);
         One_Last : Ada.Streams.Stream_Element_Offset;
         Size : constant Posix_Tools.Numbers.Count :=
           Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store);
      begin
         if Size = 0
           or else not Posix_Tools.Host_Adapters.Temporary_Storage.Read (Store, Size, One, One_Last)
           or else One_Last < One'First
         then
            return False;
         end if;

         return One (One'First) = Ada.Streams.Stream_Element (10);
      end Last_Byte_Is_LF;

      function Store_Line_Start return Posix_Tools.Numbers.Count is
         Buffer : Byte_Buffer;
         Chunk_First : Posix_Tools.Numbers.Count;
         Chunk_Length : Posix_Tools.Numbers.Count;
         Last_Read : Ada.Streams.Stream_Element_Offset;
         Position : Posix_Tools.Numbers.Count := Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store);
         Seen : Posix_Tools.Numbers.Count := 0;
         Target : constant Posix_Tools.Numbers.Count :=
           (if Last_Byte_Is_LF then Lines + Posix_Tools.Numbers.Count (1) else Lines);
      begin
         if Target = 0 or else Position = 0 then
            return 1;
         end if;

         loop
            Chunk_Length := Posix_Tools.Numbers.Count'Min
              (Posix_Tools.Numbers.Count (Buffer'Length), Position);
            Chunk_First := Position - Chunk_Length + Posix_Tools.Numbers.Count (1);

            if not Posix_Tools.Host_Adapters.Temporary_Storage.Read
              (Store,
               Chunk_First,
               Buffer (Buffer'First .. Buffer'First + Ada.Streams.Stream_Element_Offset (Chunk_Length) - 1),
               Last_Read)
            then
               return 1;
            end if;

            if Last_Read >= Buffer'First then
               for I in reverse Buffer'First .. Last_Read loop
                  if Buffer (I) = Ada.Streams.Stream_Element (10) then
                     Seen := Seen + Posix_Tools.Numbers.Count (1);
                     if Seen = Target then
                        return Chunk_First
                          + Posix_Tools.Numbers.Count (I - Buffer'First)
                          + Posix_Tools.Numbers.Count (1);
                     end if;
                  end if;
               end loop;
            end if;

            exit when Chunk_First = 1;
            Position := Chunk_First - Posix_Tools.Numbers.Count (1);
         end loop;

         return 1;
      end Store_Line_Start;

      procedure Keep_Current is
         Current_Length : constant Posix_Tools.Numbers.Count :=
           Posix_Tools.Numbers.Count (Length (Current));
      begin
         if Spill_Needed then
            Current := Null_Unbounded_String;
            return;
         elsif Current_Length > Context.Tail_Memory_Threshold
           or else Retained_Bytes > Context.Tail_Memory_Threshold - Current_Length
         then
            Spill_Needed := True;
            Current := Null_Unbounded_String;
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
            exit when Spill_Needed;
            Ch := Character_At (Input, I);
            Append (Current, Ch);
            if Posix_Tools.Numbers.Count (Length (Current)) > Context.Tail_Memory_Threshold then
               Spill_Needed := True;
               Current := Null_Unbounded_String;
               return;
            end if;
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
         Append_To_Store (Buffer, Chunk_Last);
         Input (Input'First .. Chunk_Last) := Buffer (Buffer'First .. Chunk_Last);
         Last := Chunk_Last;
         Scan_Buffer;
         Stop := not Ok;
      end Scan_Chunk;
   begin
      Ok := True;
      Store_Available := Posix_Tools.Host_Adapters.Temporary_Storage.Create (Store, Context.Tail_Max_Spill_Bytes);
      if Lines = 0 then
         if File_Name = "-"
           or else Posix_Tools.Host_Adapters.File_System.Can_Open_For_Read (File_Name)
         then
            Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
            return;
         end if;

         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Subject_Name (File_Name), "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Ok := False;
         Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
         return;
      end if;

      if File_Name = "-" then
         loop
            if not Context.Try_Read_Standard_Input (Input, Last) then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, "standard input", "posix_tools.diagnostic.file.read_failed", "cannot read file");
               Ok := False;
               Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
               return;
            end if;
            exit when Last < Input'First;
            Append_To_Store (Input, Last);
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
            Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
            return;
         end if;
      end if;

      if Ok and then Length (Current) > 0 then
         Keep_Current;
      end if;

      if not Ok then
         Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
         return;
      end if;

      if Spill_Needed then
         if not Store_Available or else not Spill_Ok
           or else not Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_For_Read (Store)
         then
            Resource_Error;
         else
            Emit_Store_From (Store_Line_Start);
         end if;
      else
         for Line of Retained loop
            Context.Put (Line);
            if Context.Output_Failed then
               Ok := False;
               exit;
            end if;
         end loop;
      end if;

      Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
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
