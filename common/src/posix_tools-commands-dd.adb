with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Input_Files;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Numbers;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.DD_Blocks;
with Posix_Tools.Text.DD_Conversion_Engine;
with Posix_Tools.Text.DD_Conversions;
with Posix_Tools.Text.DD_Operands;

package body Posix_Tools.Commands.Dd is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Streams.Stream_Element_Offset;
   subtype Usage_Message is Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind;
   use type Posix_Tools.Text.DD_Conversions.Case_Conversion_Kind;
   use type Posix_Tools.Text.DD_Conversions.Character_Set_Conversion_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   --  The records dd copied, as it reports them on standard error.
   procedure Report_Records
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Input     : Posix_Tools.Text.DD_Blocks.Record_Counts;
      Output    : Posix_Tools.Text.DD_Blocks.Record_Counts;
      Truncated : Posix_Tools.Numbers.Count);

   --  Read dd's operands into Options. Valid is False, with the usage error
   --  given, when one is wrong.
   procedure Parse_Operands
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : out Posix_Tools.Text.DD_Operands.Settings;
      Valid   : out Boolean);

   procedure Stream_Copy
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Result  : out Posix_Tools.Commands.Results.Result);

   procedure Parse_Operands
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : out Posix_Tools.Text.DD_Operands.Settings;
      Valid   : out Boolean)
   is
      Messages : constant array (Posix_Tools.Text.DD_Operands.Operand_Error_Kind) of Usage_Message :=
        [Posix_Tools.Text.DD_Operands.No_Error           => Invalid_Operand,
         Posix_Tools.Text.DD_Operands.Invalid_Block_Size => Invalid_Block_Size,
         Posix_Tools.Text.DD_Operands.Invalid_Conversion => Invalid_Conversion,
         Posix_Tools.Text.DD_Operands.Invalid_Count      => Invalid_Count,
         Posix_Tools.Text.DD_Operands.Invalid_File_Count => Invalid_File_Count,
         Posix_Tools.Text.DD_Operands.Invalid_Operand    => Invalid_Operand,
         Posix_Tools.Text.DD_Operands.Invalid_Seek       => Invalid_Seek,
         Posix_Tools.Text.DD_Operands.Invalid_Skip       => Invalid_Skip];
      Error    : Posix_Tools.Text.DD_Operands.Operand_Error;
   begin
      Options := (others => <>);
      Valid := True;
      for I in 1 .. Context.Argument_Count loop
         Valid := Posix_Tools.Text.DD_Operands.Parse_Argument (Context.Argument (I), Options, Error);
         exit when not Valid;
      end loop;

      Valid := Valid and then Posix_Tools.Text.DD_Operands.Validate (Options, Error);
      if not Valid then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Messages (Error.Kind), To_String (Error.Subject));
      end if;
   end Parse_Operands;

   procedure Report_Records
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Input     : Posix_Tools.Text.DD_Blocks.Record_Counts;
      Output    : Posix_Tools.Text.DD_Blocks.Record_Counts;
      Truncated : Posix_Tools.Numbers.Count)
   is
      function Image (Counts : Posix_Tools.Text.DD_Blocks.Record_Counts) return String is
        (Posix_Tools.Numbers.Count_Image (Counts.Full) & "+" & Posix_Tools.Numbers.Count_Image (Counts.Partial));
   begin
      Context.Put_Error_Line (Image (Input) & " records in");
      Context.Put_Error_Line (Image (Output) & " records out");
      if Truncated > 0 then
         Context.Put_Error_Line
           (Posix_Tools.Numbers.Count_Image (Truncated)
            & (if Truncated = 1 then " truncated record" else " truncated records"));
      end if;
   end Report_Records;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Valid   : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse_Operands (Context, Result, Options, Valid);
      if not Valid then
         return;
      end if;

      Stream_Copy (Context, Options, Result);
   end Run;

   procedure Stream_Copy
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      package Input_Files renames Posix_Tools.Host_Adapters.Input_Files;
      use type Input_Files.Read_Outcome;

      type Buffer_Access is access Ada.Streams.Stream_Element_Array;
      procedure Free is new Ada.Unchecked_Deallocation
        (Ada.Streams.Stream_Element_Array, Buffer_Access);

      Output            : Posix_Tools.Host_Adapters.Output_Files.Output_File;
      Positioned        : Posix_Tools.Host_Adapters.Output_Files.Positioned_Output_File;
      Input             : Input_Files.Input_File;
      Buffer            : Buffer_Access := null;
      Output_Open       : Boolean := False;
      Positioned_Output : Boolean := False;
      Input_Open        : Boolean := False;
      Output_Ok         : Boolean := True;
      Read_Ok           : Boolean := True;
      Input_Close_Ok    : Boolean := True;
      Input_Unrecoverable : Boolean := False;
      Converted_Count   : Posix_Tools.Numbers.Count := 0;
      Seek_Bytes        : Posix_Tools.Numbers.Count := 0;
      Input_Counts      : Posix_Tools.Text.DD_Blocks.Record_Counts :=
        (others => 0);
      Input_Name        : constant String :=
        (if Length (Options.Input) = 0 then "-" else To_String (Options.Input));
      Converter         : Posix_Tools.Text.DD_Conversion_Engine.Stream_Converter;
      Truncated         : Posix_Tools.Numbers.Count := 0;
      Identity_Conversion : constant Boolean :=
        Options.Conversion_Settings.Case_Conversion =
          Posix_Tools.Text.DD_Conversions.No_Case_Conversion
        and then Options.Conversion_Settings.Block_Conversion =
          Posix_Tools.Text.DD_Conversions.No_Block_Conversion
        and then Options.Conversion_Settings.Character_Set_Conversion =
          Posix_Tools.Text.DD_Conversions.No_Character_Set_Conversion
        and then not Options.Conversion_Settings.Swap_Adjacent_Bytes
        and then not Options.Conversion_Settings.Sync_Conversion;

      procedure Close_Input;
      procedure Copy_Input;
      procedure Note_Read_Failure;
      procedure Process_Record
        (Data       : Ada.Streams.Stream_Element_Array;
         Last       : Ada.Streams.Stream_Element_Offset;
         Read_Error : Boolean := False);
      procedure Read_Record
        (Outcome : out Input_Files.Read_Outcome;
         Last    : out Ada.Streams.Stream_Element_Offset);
      procedure Transform_And_Write (Text : String; Pad_Record : Boolean);
      procedure Write_Bytes (Data : Ada.Streams.Stream_Element_Array);
      procedure Write_Text (Text : String);

      procedure Close_Input is
         Closed : Boolean;
      begin
         if Input_Open then
            Input_Files.Close (Input, Closed);
            Input_Close_Ok := Input_Close_Ok and Closed;
            Input_Open := False;
         end if;
         if Buffer /= null then
            Free (Buffer);
         end if;
      end Close_Input;

      procedure Write_Text (Text : String) is
      begin
         if Text = "" then
            return;
         elsif Positioned_Output then
            Posix_Tools.Host_Adapters.Output_Files.Write
              (Positioned, Text, Output_Ok);
         elsif Output_Open then
            Posix_Tools.Host_Adapters.Output_Files.Write (Output, Text, Output_Ok);
         else
            Context.Put (Text);
            Output_Ok := not Context.Output_Failed;
         end if;
         if Output_Ok then
            Converted_Count := Converted_Count
              + Posix_Tools.Numbers.Count (Text'Length);
         end if;
      end Write_Text;

      procedure Write_Bytes (Data : Ada.Streams.Stream_Element_Array) is
      begin
         if Data'Length = 0 then
            return;
         elsif Positioned_Output then
            Posix_Tools.Host_Adapters.Output_Files.Write
              (Positioned, Data, Output_Ok);
         elsif Output_Open then
            Posix_Tools.Host_Adapters.Output_Files.Write
              (Output, Data, Output_Ok);
         else
            Context.Put_Bytes (Data, Data'Last);
            Output_Ok := not Context.Output_Failed;
         end if;
         if Output_Ok then
            Converted_Count := Converted_Count
              + Posix_Tools.Numbers.Count (Data'Length);
         end if;
      end Write_Bytes;

      procedure Transform_And_Write (Text : String; Pad_Record : Boolean) is
         Input_Text : Unbounded_String := To_Unbounded_String (Text);
         Converted : Unbounded_String;
      begin
         if Pad_Record and then Options.Conversion_Settings.Sync_Conversion then
            declare
               Padding : constant Natural :=
                 Natural (Options.Input_Block_Size)
                 - Text'Length;
               Pad_Byte : constant Character :=
                 (if Options.Conversion_Settings.Block_Conversion =
                       Posix_Tools.Text.DD_Conversions.No_Block_Conversion
                  then Character'Val (0)
                  else ' ');
            begin
               Append (Input_Text, String'(1 .. Padding => Pad_Byte));
            end;
         end if;
         Posix_Tools.Text.DD_Conversion_Engine.Update
           (Converter, To_String (Input_Text), Converted);
         Write_Text (To_String (Converted));
      end Transform_And_Write;

      procedure Note_Read_Failure is
      begin
         Read_Ok := False;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context,
            Posix_Tools.Commands.Helpers.File_Subject (Context, Input_Name),
            "posix_tools.diagnostic.file.read_failed",
            "cannot read file");
      end Note_Read_Failure;

      procedure Process_Record
        (Data       : Ada.Streams.Stream_Element_Array;
         Last       : Ada.Streams.Stream_Element_Offset;
         Read_Error : Boolean := False)
      is
         Length : constant Natural :=
           (if Last < Data'First then 0 else Natural (Last - Data'First + 1));
      begin
         if not Read_Error then
            if Posix_Tools.Numbers.Count (Length) = Options.Input_Block_Size then
               Input_Counts.Full := Input_Counts.Full + 1;
            else
               Input_Counts.Partial := Input_Counts.Partial + 1;
            end if;
         end if;

         if Identity_Conversion then
            if Length > 0 then
               Write_Bytes (Data (Data'First .. Last));
            end if;
         elsif Length > 0 then
            declare
               Text : constant String :=
                 Posix_Tools.Streams.Bytes.To_String
                   (Data (Data'First .. Last), Last);
            begin
               Transform_And_Write
                 (Text,
                  Pad_Record =>
                    Posix_Tools.Numbers.Count (Length) <
                      Options.Input_Block_Size);
            end;
         elsif Read_Error and then Options.Conversion_Settings.Sync_Conversion then
            Transform_And_Write ("", Pad_Record => True);
         end if;
      end Process_Record;

      procedure Read_Record
        (Outcome : out Input_Files.Read_Outcome;
         Last    : out Ada.Streams.Stream_Element_Offset) is
      begin
         if Input_Open then
            Input_Files.Read (Input, Buffer.all, Last, Outcome);
         elsif Context.Try_Read_Standard_Input (Buffer.all, Last) then
            Outcome :=
              (if Last < Buffer.all'First
               then Input_Files.Read_End
               else Input_Files.Read_Complete);
         else
            Last := Buffer.all'First - 1;
            Outcome := Input_Files.Read_Failed;
         end if;
      end Read_Record;

      procedure Copy_Input is
         Attempted : Posix_Tools.Numbers.Count := 0;
         Skipped   : Posix_Tools.Numbers.Count := 0;
         Last      : Ada.Streams.Stream_Element_Offset;
         Outcome   : Input_Files.Read_Outcome;
         Previous_Read_Failed : Boolean := False;
      begin
         while Skipped < Options.Skip_Blocks loop
            Read_Record (Outcome, Last);
            case Outcome is
               when Input_Files.Read_Complete =>
                  Skipped := Skipped + 1;
                  Previous_Read_Failed := False;
               when Input_Files.Read_End =>
                  return;
               when Input_Files.Read_Failed =>
                  if not Previous_Read_Failed then
                     Note_Read_Failure;
                  end if;
                  if not Options.Continue_After_Read_Error then
                     return;
                  elsif Input_Open then
                     declare
                        Recovery : Input_Files.Recovery_Outcome;
                     begin
                        Input_Files.Advance_After_Error
                          (Input, Options.Input_Block_Size, Recovery);
                        case Recovery is
                           when Input_Files.Recovery_Advanced =>
                              Skipped := Skipped + 1;
                              Previous_Read_Failed := False;
                           when Input_Files.Recovery_Not_Seekable =>
                              if Previous_Read_Failed then
                                 Input_Unrecoverable := True;
                                 return;
                              end if;
                              Previous_Read_Failed := True;
                           when Input_Files.Recovery_Failed =>
                              Input_Unrecoverable := True;
                              return;
                        end case;
                     end;
                  elsif Previous_Read_Failed then
                     Input_Unrecoverable := True;
                     return;
                  else
                     --  A nonseekable standard stream may recover from a
                     --  transient error, but no bytes can be skipped safely.
                     Previous_Read_Failed := True;
                  end if;
            end case;
         end loop;

         while Output_Ok
           and then not Context.Output_Failed
           and then
             (Options.Count = Posix_Tools.Numbers.Count'Last
              or else Attempted < Options.Count)
         loop
            Read_Record (Outcome, Last);
            case Outcome is
               when Input_Files.Read_Complete =>
                  Attempted := Attempted + 1;
                  Process_Record (Buffer.all, Last);
                  Previous_Read_Failed := False;
               when Input_Files.Read_End =>
                  exit;
               when Input_Files.Read_Failed =>
                  if not Previous_Read_Failed then
                     Note_Read_Failure;
                  end if;
                  if not Options.Continue_After_Read_Error then
                     exit;
                  elsif Input_Open then
                     declare
                        Recovery : Input_Files.Recovery_Outcome;
                     begin
                        Input_Files.Advance_After_Error
                          (Input, Options.Input_Block_Size, Recovery);
                        case Recovery is
                           when Input_Files.Recovery_Advanced =>
                              Attempted := Attempted + 1;
                              Process_Record
                                (Buffer.all,
                                 Buffer.all'First - 1,
                                 Read_Error => True);
                              Previous_Read_Failed := False;
                           when Input_Files.Recovery_Not_Seekable =>
                              if Previous_Read_Failed then
                                 Input_Unrecoverable := True;
                                 exit;
                              end if;
                              Previous_Read_Failed := True;
                           when Input_Files.Recovery_Failed =>
                              Input_Unrecoverable := True;
                              exit;
                        end case;
                     end;
                  elsif Previous_Read_Failed then
                     Input_Unrecoverable := True;
                     exit;
                  else
                     Previous_Read_Failed := True;
                  end if;
            end case;
         end loop;
      end Copy_Input;
   begin
      Result.Status := Posix_Tools.Exit_Status.Success;
      if not Identity_Conversion then
         Posix_Tools.Text.DD_Conversion_Engine.Initialize
           (Converter, Options.Conversion_Settings);
      end if;
      if Posix_Tools.Text.DD_Blocks.Offset_Overflows
        (Options.Skip_Blocks, Options.Input_Block_Size)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Offset_Overflow);
         return;
      elsif Options.Count /= Posix_Tools.Numbers.Count'Last
        and then Posix_Tools.Text.DD_Blocks.Offset_Overflows
          (Options.Count, Options.Input_Block_Size)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Count_Overflow);
         return;
      elsif Posix_Tools.Text.DD_Blocks.Offset_Overflows
        (Options.Seek_Blocks, Options.Output_Block_Size)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Offset_Overflow);
         return;
      end if;
      Seek_Bytes := Options.Seek_Blocks * Options.Output_Block_Size;

      --  Stream_IO positions are one based. The largest Count is a valid
      --  byte count, but it cannot be advanced by one to form an output
      --  position.
      if Seek_Bytes = Posix_Tools.Numbers.Count'Last then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, Offset_Overflow);
         return;
      end if;

      Buffer :=
        new Ada.Streams.Stream_Element_Array
          (1 .. Ada.Streams.Stream_Element_Offset
             (Natural (Options.Input_Block_Size)));
      if Input_Name /= "-" then
         Input_Files.Open (Input, Input_Name, Input_Open);
         if not Input_Open then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context,
               Posix_Tools.Commands.Helpers.File_Subject
                 (Context, Input_Name),
               "posix_tools.diagnostic.file.read_failed",
               "cannot read file");
            Close_Input;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      end if;

      if Length (Options.Output) > 0 then
         Positioned_Output := Options.Seek_Blocks > 0 or else Options.No_Truncate_Output;
         if Positioned_Output then
            Posix_Tools.Host_Adapters.Output_Files.Open_At
              (File     => Positioned,
               Path     => To_String (Options.Output),
               Offset   => Long_Long_Integer (Seek_Bytes),
               Truncate => not (Options.No_Truncate_Output
                 and then FS.Exists (To_String (Options.Output))),
               Ok       => Output_Ok);
         else
            Posix_Tools.Host_Adapters.Output_Files.Open
              (Output, To_String (Options.Output), False, Output_Ok);
            Output_Open := Output_Ok;
         end if;
         if not Output_Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Options.Output),
               "posix_tools.diagnostic.file.write_failed", "cannot write file");
            Close_Input;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      elsif Seek_Bytes > 0 then
         declare
            Zeros : constant String
              (1 .. Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length) :=
              [others => Character'Val (0)];
            Remaining : Posix_Tools.Numbers.Count := Seek_Bytes;
         begin
            while Remaining > 0 and then Output_Ok loop
               declare
                  Amount : constant Natural := Natural
                    (Posix_Tools.Numbers.Count'Min
                       (Remaining, Posix_Tools.Numbers.Count (Zeros'Length)));
               begin
                  Context.Put (Zeros (1 .. Amount));
                  Output_Ok := not Context.Output_Failed;
                  Remaining := Remaining - Posix_Tools.Numbers.Count (Amount);
               end;
            end loop;
         end;
      end if;

      Copy_Input;
      if Output_Ok and then not Identity_Conversion then
         declare
            Final_Output : Unbounded_String;
         begin
            Posix_Tools.Text.DD_Conversion_Engine.Finish
              (Converter, Final_Output, Truncated);
            Write_Text (To_String (Final_Output));
         end;
      end if;
      if Output_Open then
         declare
            Closed : Boolean;
         begin
            Posix_Tools.Host_Adapters.Output_Files.Close (Output, Closed);
            Output_Ok := Output_Ok and Closed;
         end;
      end if;
      if Positioned_Output
        and then Posix_Tools.Host_Adapters.Output_Files.Is_Open (Positioned)
      then
         declare
            Closed : Boolean;
         begin
            Posix_Tools.Host_Adapters.Output_Files.Close (Positioned, Closed);
            Output_Ok := Output_Ok and Closed;
         end;
      end if;
      Close_Input;

      if Input_Unrecoverable
        or else (not Read_Ok and then not Options.Continue_After_Read_Error)
        or else not Input_Close_Ok
        or else not Output_Ok
      then
         if not Input_Close_Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context,
               Posix_Tools.Commands.Helpers.File_Subject
                 (Context, Input_Name),
               "posix_tools.diagnostic.file.read_failed",
               "cannot read file");
         end if;
         if not Output_Ok and then not Context.Output_Failed then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, To_String (Options.Output),
               "posix_tools.diagnostic.file.write_failed", "cannot write file");
         end if;
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         if not Input_Unrecoverable
           or else not Options.Continue_After_Read_Error
         then
            return;
         end if;
      end if;

      Report_Records
        (Context,
         Input_Counts,
         Posix_Tools.Text.DD_Blocks.Counts_For (Converted_Count, Options.Output_Block_Size),
         Truncated);
      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   exception
      when others =>
         Close_Input;
         raise;
   end Stream_Copy;
end Posix_Tools.Commands.Dd;
