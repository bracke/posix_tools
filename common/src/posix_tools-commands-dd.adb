with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Output_Files;
with Posix_Tools.Numbers;
with Posix_Tools.Text.DD_Blocks;
with Posix_Tools.Text.DD_Conversion_Engine;
with Posix_Tools.Text.DD_Operands;

package body Posix_Tools.Commands.Dd is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   subtype Usage_Message is Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Text.DD_Blocks.Transfer_Plan_Status;

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

   --  Write Slice to the of= file, from Offset on: emptied first unless
   --  conv=notrunc and it is there to keep. A failure is reported.
   procedure Write_Output_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Offset  : Posix_Tools.Numbers.Count;
      Slice   : String;
      Ok      : out Boolean);

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
      Ok      : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse_Operands (Context, Result, Options, Valid);
      if not Valid then
         return;
      end if;

      declare
         --  The if= file, or standard input without one. A read failure has
         --  been reported; conv=noerror carries on with what was read.
         Full     : constant String :=
           Posix_Tools.Commands.File_Helpers.Streaming.Read_File
             (Context, (if Length (Options.Input) = 0 then "-" else To_String (Options.Input)), Ok);
         Transfer : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => Full'Length,
              Count             => Options.Count,
              Input_Block_Size  => Options.Input_Block_Size,
              Output_Block_Size => Options.Output_Block_Size,
              Skip_Blocks       => Options.Skip_Blocks,
              Seek_Blocks       => Options.Seek_Blocks);
      begin
         if not Ok and then not Options.Continue_After_Read_Error then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         elsif Transfer.Status = Posix_Tools.Text.DD_Blocks.Offset_Overflow then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Offset_Overflow);
            return;
         elsif Transfer.Status = Posix_Tools.Text.DD_Blocks.Count_Overflow then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Count_Overflow);
            return;
         end if;

         declare
            Raw_Slice : constant String :=
              Posix_Tools.Text.DD_Blocks.Selected_Input
                ((if Transfer.Last_Index < Transfer.Start_Index
                  then ""
                  else Full (Transfer.Start_Index .. Transfer.Last_Index)),
                 Options.Input_Block_Size,
                 Options.Count);
            Converted : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Result :=
              Posix_Tools.Text.DD_Conversion_Engine.Apply (Raw_Slice, Options.Conversion_Settings);
            Slice     : constant String := To_String (Converted.Output);
         begin
            if Length (Options.Output) = 0 then
               Context.Put (String'(1 .. Natural (Transfer.Prefix_Count) => Character'Val (0)) & Slice);
               Ok := True;
            else
               Write_Output_File (Context, Options, Transfer.Prefix_Count, Slice, Ok);
            end if;

            Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
            if Result.Status = Posix_Tools.Exit_Status.Success then
               Report_Records
                 (Context,
                  Input     =>
                    Posix_Tools.Text.DD_Blocks.Counts_For
                      (Posix_Tools.Numbers.Count (Raw_Slice'Length), Options.Input_Block_Size),
                  Output    =>
                    Posix_Tools.Text.DD_Blocks.Counts_For
                      (Posix_Tools.Numbers.Count (Slice'Length), Options.Output_Block_Size),
                  Truncated => Converted.Truncated_Records);
            end if;
         end;
      end;
   end Run;

   procedure Write_Output_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Offset  : Posix_Tools.Numbers.Count;
      Slice   : String;
      Ok      : out Boolean)
   is
      Path : constant String := To_String (Options.Output);
   begin
      Posix_Tools.Host_Adapters.Output_Files.Write_At
        (Path     => Path,
         Offset   => Long_Long_Integer (Offset),
         Text     => Slice,
         Truncate => not (Options.No_Truncate_Output and then FS.Exists (Path)),
         Ok       => Ok);
      if not Ok then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Path, "posix_tools.diagnostic.file.write_failed", "cannot write file");
      end if;
   end Write_Output_File;
end Posix_Tools.Commands.Dd;
