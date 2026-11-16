with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Suffixes;

package body Posix_Tools.Commands.Split is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   --  -b's size: a positive number of bytes, n, followed by k for n
   --  kibibytes or m for n mebibytes.
   function Byte_Size (Text : String) return Posix_Tools.Text.Decimal_Parsing.Parsed_Natural;

   function Byte_Size (Text : String) return Posix_Tools.Text.Decimal_Parsing.Parsed_Natural is
      Invalid    : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural := (Valid => False, Value => 0);
      Has_Suffix : constant Boolean := Text'Length > 0 and then Text (Text'Last) in 'k' | 'm';
      Multiplier : constant Natural :=
        (if not Has_Suffix then 1 elsif Text (Text'Last) = 'k' then 1024 else 1024 * 1024);
      Count      : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
          (Text (Text'First .. (if Has_Suffix then Text'Last - 1 else Text'Last)), 1, Natural'Last);
   begin
      if not Count.Valid or else Count.Value > Natural'Last / Multiplier then
         return Invalid;
      end if;
      return (Valid => True, Value => Count.Value * Multiplier);
   end Byte_Size;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Lines_Per_File : Natural := 1000;
      Bytes_Per_File : Natural := 0;
      Suffix_Length  : Positive := 2;
      First          : Positive;
      Valid          : Boolean;
      Input          : Unbounded_String := To_Unbounded_String ("-");
      Prefix         : Unbounded_String := To_Unbounded_String ("x");
      Ok             : Boolean;
      Operation_Ok   : Boolean := True;
      Output         : Posix_Tools.Host_Adapters.Output_Files.Output_File;
      Output_Open    : Boolean := False;
      Part           : Natural := 0;
      In_Part        : Natural := 0;
      Output_Name    : Unbounded_String;

      procedure Close_Output;
      procedure Open_Output;
      procedure Write_Output (Data : Ada.Streams.Stream_Element_Array);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
           (case Name is
               when 'a' => Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Value, 1, 12),
               when 'l' => Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Value, 1, Natural'Last),
               when others => Byte_Size (Value));
      begin
         Valid := Parsed.Valid;
         if not Valid then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            return;
         end if;
         case Name is
            when 'a' => Suffix_Length := Positive (Parsed.Value);
            when 'l' => Lines_Per_File := Parsed.Value;
            when others => Bytes_Per_File := Parsed.Value;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);

      procedure Close_Output is
         Closed : Boolean;
      begin
         if Output_Open then
            Posix_Tools.Host_Adapters.Output_Files.Close (Output, Closed);
            Operation_Ok := Operation_Ok and Closed;
            Output_Open := False;
         end if;
      end Close_Output;

      procedure Open_Output is
      begin
         if Part >= Posix_Tools.Text.Suffixes.Lowercase_Capacity (Suffix_Length) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Prefix),
               "posix_tools.diagnostic.resource.limit", "resource limit exceeded");
            Operation_Ok := False;
            return;
         end if;
         Output_Name := To_Unbounded_String
           (To_String (Prefix)
            & Posix_Tools.Text.Suffixes.Lowercase_Image (Part, Suffix_Length));
         Posix_Tools.Host_Adapters.Output_Files.Open
           (Output, To_String (Output_Name), False, Operation_Ok);
         Output_Open := Operation_Ok;
         if not Operation_Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Output_Name),
               "posix_tools.diagnostic.file.open_failed", "cannot open file");
         else
            Part := Part + 1;
            In_Part := 0;
         end if;
      end Open_Output;

      procedure Write_Output (Data : Ada.Streams.Stream_Element_Array) is
      begin
         if not Output_Open then
            Open_Output;
         end if;
         if Output_Open and then Data'Length > 0 then
            Posix_Tools.Host_Adapters.Output_Files.Write (Output, Data, Operation_Ok);
            if not Operation_Ok then
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, To_String (Output_Name),
                  "posix_tools.diagnostic.file.write_failed", "cannot write file");
            end if;
         end if;
      end Write_Output;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "abl", "abl", First, Valid);
      if not Valid then
         return;
      end if;
      declare
         Remaining : constant Natural :=
           (if First > Context.Argument_Count then 0 else Context.Argument_Count - First + 1);
      begin
         if Remaining > 2 then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + 2));
            return;
         elsif Remaining >= 1 then
            Input := To_Unbounded_String (Context.Argument (First));
            if Remaining = 2 then
               Prefix := To_Unbounded_String (Context.Argument (First + 1));
            end if;
         end if;
      end;

      declare
         procedure Copy_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);
         procedure Copy_Line_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Copy_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
            First_Byte : Ada.Streams.Stream_Element_Offset := Buffer'First;
            Amount     : Natural;
            Final      : Ada.Streams.Stream_Element_Offset;
         begin
            while Operation_Ok and then First_Byte <= Last loop
               Amount := Natural'Min
                 (Bytes_Per_File - In_Part, Natural (Last - First_Byte + 1));
               Final := First_Byte + Ada.Streams.Stream_Element_Offset (Amount) - 1;
               Write_Output (Buffer (First_Byte .. Final));
               In_Part := In_Part + Amount;
               First_Byte := Final + 1;
               if In_Part = Bytes_Per_File then
                  Close_Output;
               end if;
            end loop;
         end Copy_Chunk;

         procedure Copy_Line_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
            First_Byte : Ada.Streams.Stream_Element_Offset := Buffer'First;
         begin
            if Last < Buffer'First then
               return;
            end if;
            for I in Buffer'First .. Last loop
               if Buffer (I) = Ada.Streams.Stream_Element (10) then
                  In_Part := In_Part + 1;
                  if In_Part = Lines_Per_File then
                     Write_Output (Buffer (First_Byte .. I));
                     Close_Output;
                     First_Byte := I + 1;
                  end if;
               end if;
               exit when not Operation_Ok;
            end loop;
            if Operation_Ok and then First_Byte <= Last then
               Write_Output (Buffer (First_Byte .. Last));
            end if;
         end Copy_Line_Chunk;

         procedure Copy_Chunks is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Copy_Chunk,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
         procedure Copy_Line_Chunks is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Copy_Line_Chunk,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         Ok := True;
         if Bytes_Per_File > 0 then
            Copy_Chunks (Context, To_String (Input), Ok);
         else
            Copy_Line_Chunks (Context, To_String (Input), Ok);
         end if;
         Close_Output;
         Ok := Ok and Operation_Ok;
      end;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;

end Posix_Tools.Commands.Split;
