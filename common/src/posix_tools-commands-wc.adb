with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Counting;

package body Posix_Tools.Commands.Wc is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   subtype Counts is Posix_Tools.Streams.Counting.Counts;

   function Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Image;

   procedure Count_Buffer
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      State   : in out Posix_Tools.Streams.Counting.Counter)
   is
      Text   : String (1 .. Natural (Integer (Last) - Integer (Buffer'First) + 1));
      Target : Positive := Text'First;
   begin
      if Last < Buffer'First then
         return;
      end if;

      for I in Buffer'First .. Last loop
         Text (Target) := Character'Val (Integer (Buffer (I)));
         Target := Target + 1;
      end loop;

      Posix_Tools.Streams.Counting.Process (State, Text);
   end Count_Buffer;

   procedure Count_File
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Need_Text : Boolean;
      Result    : out Counts;
      Ok        : out Boolean)
   is
      State   : Posix_Tools.Streams.Counting.Counter;

      procedure Count_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         Count_Buffer (Buffer, Last, State);
      end Count_Chunk;

      procedure Count_Chunks is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
        (Action => Count_Chunk);
   begin
      Result := (others => 0);
      Count_Chunks (Context, File_Name, Ok);
      if not Ok then
         return;
      end if;

      Posix_Tools.Streams.Counting.Finish_Text (State);
      if Need_Text and then Posix_Tools.Streams.Counting.Text_Invalid (State) then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, File_Name, "posix_tools.diagnostic.text.invalid_utf8", "invalid UTF-8");
         Ok := False;
         return;
      end if;

      Result := Posix_Tools.Streams.Counting.Snapshot (State);
   end Count_File;

   procedure Print_Counts
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      C       : Counts;
      Name    : String;
      Show_C  : Boolean;
      Show_L  : Boolean;
      Show_M  : Boolean;
      Show_W  : Boolean)
   is
      Text : Unbounded_String;
   begin
      if Show_L then
         Append (Text, " " & Image (C.Lines));
      end if;
      if Show_W then
         Append (Text, " " & Image (C.Words));
      end if;
      if Show_C then
         Append (Text, " " & Image (C.Bytes));
      end if;
      if Show_M then
         Append (Text, " " & Image (C.Characters));
      end if;
      if Name /= "" then
         Append (Text, " " & Name);
      end if;

      declare
         Rendered : constant String := To_String (Text);
      begin
         if Rendered /= "" and then Rendered (Rendered'First) = ' ' then
            Context.Put (Rendered (Rendered'First + 1 .. Rendered'Last) & Character'Val (10));
         else
            Context.Put (Rendered & Character'Val (10));
         end if;
      end;
   end Print_Counts;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_C     : Boolean := False;
      Show_L     : Boolean := False;
      Show_M     : Boolean := False;
      Show_W     : Boolean := False;
      First_File : Positive := 1;
      C          : Counts;
      Total      : Counts := (others => 0);
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Successful : Natural := 0;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First_File <= Context.Argument_Count
        and then Context.Argument (First_File)'Length > 1
        and then Context.Argument (First_File) (1) = '-'
        and then Context.Argument (First_File) /= "-"
      loop
         if Context.Argument (First_File) = "--" then
            First_File := First_File + 1;
            exit;
         end if;

         for Ch of Context.Argument (First_File) (2 .. Context.Argument (First_File)'Last) loop
            case Ch is
               when 'c' => Show_C := True;
               when 'l' => Show_L := True;
               when 'm' => Show_M := True;
               when 'w' => Show_W := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First_File := First_File + 1;
      end loop;

      if not (Show_C or Show_L or Show_M or Show_W) then
         Show_L := True;
         Show_W := True;
         Show_C := True;
      end if;

      if First_File > Context.Argument_Count then
         Count_File (Context, "-", Show_M or Show_W, C, Ok);
         if Ok then
            Print_Counts (Context, C, "", Show_C, Show_L, Show_M, Show_W);
            Ok := not Context.Output_Failed;
         end if;
         All_Ok := Ok;
      else
         for I in First_File .. Context.Argument_Count loop
            Count_File (Context, Context.Argument (I), Show_M or Show_W, C, Ok);
            if Ok then
               Print_Counts (Context, C, Context.Argument (I), Show_C, Show_L, Show_M, Show_W);
               if Context.Output_Failed then
                  Ok := False;
               else
                  Successful := Successful + 1;
                  Total.Lines := Total.Lines + C.Lines;
                  Total.Words := Total.Words + C.Words;
                  Total.Bytes := Total.Bytes + C.Bytes;
                  Total.Characters := Total.Characters + C.Characters;
               end if;
            end if;
            All_Ok := All_Ok and Ok;
            exit when Context.Output_Failed;
         end loop;

         if not Context.Output_Failed
           and then Context.Argument_Count - First_File + 1 > 1
           and then Successful > 0
         then
            Print_Counts (Context, Total, "total", Show_C, Show_L, Show_M, Show_W);
            if Context.Output_Failed then
               All_Ok := False;
            end if;
         end if;
      end if;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Wc;
