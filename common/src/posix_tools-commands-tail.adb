with Ada.Streams;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Numbers;

package body Posix_Tools.Commands.Tail is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;

   type Mode is (Line_Mode, Byte_Mode);
   type Count_Origin is (From_End, From_Start);

   Max_Retained_Bytes : constant Posix_Tools.Numbers.Count := 16 * 1024 * 1024;

   function Parse_Count
     (Text : String;
      Value : out Posix_Tools.Numbers.Count;
      Count_Origin_Value : out Count_Origin) return Posix_Tools.Numbers.Parse_Status
   is
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      if Text /= "" and then Text (Text'First) = '+' then
         if Text'Length = 1 then
            return Posix_Tools.Numbers.Invalid_Syntax;
         end if;

         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (Text'First + 1 .. Text'Last));
         Count_Origin_Value := From_Start;
      else
         Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text);
         Count_Origin_Value := From_End;
      end if;

      Value := Parsed.Value;
      return Parsed.Status;
   end Parse_Count;

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

   procedure Keep_Byte
     (Ring     : in out Ada.Streams.Stream_Element_Array;
      Filled   : in out Natural;
      Next     : in out Ada.Streams.Stream_Element_Offset;
      Element  : Ada.Streams.Stream_Element)
   is
   begin
      Ring (Next) := Element;
      if Filled < Ring'Length then
         Filled := Filled + 1;
      end if;

      if Next = Ring'Last then
         Next := Ring'First;
      else
         Next := Next + Ada.Streams.Stream_Element_Offset (1);
      end if;
   end Keep_Byte;

   procedure Emit_Ring
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ring    : Ada.Streams.Stream_Element_Array;
      Filled  : Natural;
      Next    : Ada.Streams.Stream_Element_Offset)
   is
      Start : Ada.Streams.Stream_Element_Offset;
   begin
      if Filled = 0 then
         return;
      elsif Filled < Ring'Length then
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Ring'First + Ada.Streams.Stream_Element_Offset (Filled) - Ada.Streams.Stream_Element_Offset (1);
         begin
            Context.Put (To_String (Ring (Ring'First .. Last), Last));
         end;
      else
         Start := Next;
         if Start <= Ring'Last then
            Context.Put (To_String (Ring (Start .. Ring'Last), Ring'Last));
         end if;
         if Start > Ring'First then
            declare
               Last : constant Ada.Streams.Stream_Element_Offset :=
                 Start - Ada.Streams.Stream_Element_Offset (1);
            begin
               Context.Put (To_String (Ring (Ring'First .. Last), Last));
            end;
         end if;
      end if;
   end Emit_Ring;

   procedure Tail_Bytes
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Origin    : Count_Origin;
      Ok        : out Boolean)
   is
      Limit    : Natural;
   begin
      Ok := True;
      if Origin = From_Start then
         declare
            Position : Posix_Tools.Numbers.Count := 0;

            procedure Emit_From_Start
              (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset)
            is
            begin
               if Last < Buffer'First then
                  return;
               end if;

               for I in Buffer'First .. Last loop
                  Position := Position + 1;
                  if Requested = 0 or else Position >= Requested then
                     Context.Put (To_String (Buffer (I .. I), I));
                     exit when Context.Output_Failed;
                  end if;
               end loop;
            end Emit_From_Start;

            procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
              (Action => Emit_From_Start);
         begin
            Iterate (Context, File_Name, Ok);
         end;
         return;
      end if;

      if Requested = 0 then
         declare
            procedure Ignore_Chunk
              (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset)
            is
               pragma Unreferenced (Context, Buffer, Last);
            begin
               null;
            end Ignore_Chunk;

            procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
              (Action => Ignore_Chunk);
         begin
            Iterate (Context, File_Name, Ok);
         end;
         return;
      elsif Requested > Max_Retained_Bytes
        or else Requested > Posix_Tools.Numbers.Count (Natural'Last)
      then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         Ok := False;
         return;
      end if;

      Limit := Natural (Requested);

      declare
         Filled : Natural := 0;
         Ring : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Limit));
         Next : Ada.Streams.Stream_Element_Offset := Ring'First;

         procedure Retain_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Context);
         begin
            if Last < Buffer'First then
               return;
            end if;

            for I in Buffer'First .. Last loop
               Keep_Byte (Ring, Filled, Next, Buffer (I));
            end loop;
         end Retain_Chunk;

         procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
           (Action => Retain_Chunk);
      begin
         Iterate (Context, File_Name, Ok);
         if not Ok then
            return;
         end if;

         Emit_Ring (Context, Ring, Filled, Next);
         if Context.Output_Failed then
            Ok := False;
         end if;
      end;
   end Tail_Bytes;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First_File : Positive := 1;
      Count      : constant Natural := Context.Argument_Count;
      Parsed_Status : Posix_Tools.Numbers.Parse_Status;
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Sources    : Natural;
      Current_Mode : Mode := Line_Mode;
      Requested  : Posix_Tools.Numbers.Count := 10;
      Origin     : Count_Origin := From_End;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Count >= 1 and then (Context.Argument (1) = "-n" or else Context.Argument (1) = "-c") then
         if Count = 1 then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "missing option argument '" & Context.Argument (1) & "'");
            return;
         end if;

         Current_Mode := (if Context.Argument (1) = "-c" then Byte_Mode else Line_Mode);
         Parsed_Status := Parse_Count (Context.Argument (2), Requested, Origin);
         if Parsed_Status /= Posix_Tools.Numbers.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid count '" & Context.Argument (2) & "'");
            return;
         end if;
         First_File := 3;
      elsif Count >= 1 and then Context.Argument (1)'Length > 2
        and then Context.Argument (1) (1) = '-'
        and then (Context.Argument (1) (2) = 'n' or else Context.Argument (1) (2) = 'c')
      then
         Current_Mode := (if Context.Argument (1) (2) = 'c' then Byte_Mode else Line_Mode);
         Parsed_Status := Parse_Count
           (Context.Argument (1) (3 .. Context.Argument (1)'Last), Requested, Origin);
         if Parsed_Status /= Posix_Tools.Numbers.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid count '" & Context.Argument (1) & "'");
            return;
         end if;
         First_File := 2;
      else
         Origin := From_End;
      end if;

      if First_File <= Count and then Context.Argument (First_File) = "--" then
         First_File := First_File + 1;
      end if;

      Sources := (if First_File > Count then 1 else Count - First_File + 1);
      if First_File > Count then
         if Current_Mode = Byte_Mode then
            Tail_Bytes (Context, "-", Requested, Origin, Ok);
         elsif Origin = From_Start then
            Posix_Tools.Commands.File_Helpers.Copy_Lines_From (Context, "-", Requested, Ok);
         else
            Posix_Tools.Commands.File_Helpers.Copy_Line_Suffix (Context, "-", Requested, Ok);
         end if;
         All_Ok := Ok;
      else
         for I in First_File .. Count loop
            if Sources > 1 then
               if I > First_File then
                  Context.Put_Line ("");
                  if Context.Output_Failed then
                     All_Ok := False;
                     exit;
                  end if;
               end if;
               Context.Put_Line ("==> " & Context.Argument (I) & " <==");
               if Context.Output_Failed then
                  All_Ok := False;
                  exit;
               end if;
            end if;

            if Current_Mode = Byte_Mode then
               Tail_Bytes (Context, Context.Argument (I), Requested, Origin, Ok);
            elsif Origin = From_Start then
               Posix_Tools.Commands.File_Helpers.Copy_Lines_From
                 (Context, Context.Argument (I), Requested, Ok);
            else
               Posix_Tools.Commands.File_Helpers.Copy_Line_Suffix
                 (Context, Context.Argument (I), Requested, Ok);
            end if;
            All_Ok := All_Ok and Ok;
         end loop;
      end if;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Tail;
