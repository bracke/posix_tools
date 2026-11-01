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

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Posix_Tools.Text.DD_Operands.Settings;
      Data   : Unbounded_String;
      Ok     : Boolean := True;
      Input_Full_Records : Posix_Tools.Numbers.Count := 0;
      Input_Partial_Records : Posix_Tools.Numbers.Count := 0;
      Output_Full_Records : Posix_Tools.Numbers.Count := 0;
      Output_Partial_Records : Posix_Tools.Numbers.Count := 0;
      Truncated_Records : Posix_Tools.Numbers.Count := 0;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      declare
         Error : Posix_Tools.Text.DD_Operands.Operand_Error;

         procedure Refuse;

         procedure Refuse is
            Messages : constant array (Posix_Tools.Text.DD_Operands.Operand_Error_Kind) of Usage_Message :=
              [Posix_Tools.Text.DD_Operands.No_Error           => Invalid_Operand,
               Posix_Tools.Text.DD_Operands.Invalid_Block_Size => Invalid_Block_Size,
               Posix_Tools.Text.DD_Operands.Invalid_Conversion => Invalid_Conversion,
               Posix_Tools.Text.DD_Operands.Invalid_Count      => Invalid_Count,
               Posix_Tools.Text.DD_Operands.Invalid_File_Count => Invalid_File_Count,
               Posix_Tools.Text.DD_Operands.Invalid_Operand    => Invalid_Operand,
               Posix_Tools.Text.DD_Operands.Invalid_Seek       => Invalid_Seek,
               Posix_Tools.Text.DD_Operands.Invalid_Skip       => Invalid_Skip];
         begin
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, Messages (Error.Kind), To_String (Error.Subject));
         end Refuse;
      begin
         for I in 1 .. Context.Argument_Count loop
            if not Posix_Tools.Text.DD_Operands.Parse_Argument
              (Context.Argument (I), Options, Error)
            then
               Refuse;
               return;
            end if;
         end loop;

         if not Posix_Tools.Text.DD_Operands.Validate (Options, Error) then
            Refuse;
            return;
         end if;
      end;

      --  The if= file, or standard input without one. A read failure has
      --  been reported; conv=noerror carries on with what was read.
      Data :=
        To_Unbounded_String
          (Posix_Tools.Commands.File_Helpers.Streaming.Read_File
             (Context, (if Length (Options.Input) = 0 then "-" else To_String (Options.Input)), Ok));
      if not Ok then
         if not Options.Continue_After_Read_Error then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         Ok := True;
      end if;

      declare
         Full : constant String := To_String (Data);
         Transfer : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => Full'Length,
              Count             => Options.Count,
              Input_Block_Size  => Options.Input_Block_Size,
              Output_Block_Size => Options.Output_Block_Size,
              Skip_Blocks       => Options.Skip_Blocks,
              Seek_Blocks       => Options.Seek_Blocks);
      begin
         if Transfer.Status = Posix_Tools.Text.DD_Blocks.Offset_Overflow then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Offset_Overflow);
            return;
         end if;

         if Transfer.Status = Posix_Tools.Text.DD_Blocks.Count_Overflow then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Count_Overflow);
            return;
         end if;

         declare
            Prefix : constant String (1 .. Natural (Transfer.Prefix_Count)) :=
              [others => Character'Val (0)];
            Raw_Slice : constant String :=
              Posix_Tools.Text.DD_Blocks.Selected_Input
                ((if Transfer.Last_Index < Transfer.Start_Index
                  then ""
                  else Full (Transfer.Start_Index .. Transfer.Last_Index)),
                 Options.Input_Block_Size,
                 Options.Count);
            Converted : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Result :=
              Posix_Tools.Text.DD_Conversion_Engine.Apply
                (Raw_Slice, Options.Conversion_Settings);
            Slice  : constant String := To_String (Converted.Output);

            --  The of= file, from the seek= offset on: emptied first unless
            --  conv=notrunc and it is there to keep.
            procedure Write_Dd_Output_File is
               Path : constant String := To_String (Options.Output);
            begin
               Posix_Tools.Host_Adapters.Output_Files.Write_At
                 (Path     => Path,
                  Offset   => Long_Long_Integer (Transfer.Prefix_Count),
                  Text     => Slice,
                  Truncate => not (Options.No_Truncate_Output and then FS.Exists (Path)),
                  Ok       => Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Path, "posix_tools.diagnostic.file.write_failed", "cannot write file");
               end if;
            end Write_Dd_Output_File;
         begin
            declare
               Input_Records : constant Posix_Tools.Text.DD_Blocks.Record_Counts :=
                 Posix_Tools.Text.DD_Blocks.Counts_For
                   (Posix_Tools.Numbers.Count (Raw_Slice'Length),
                    Options.Input_Block_Size);
               Output_Records : constant Posix_Tools.Text.DD_Blocks.Record_Counts :=
                 Posix_Tools.Text.DD_Blocks.Counts_For
                   (Posix_Tools.Numbers.Count (Slice'Length),
                    Options.Output_Block_Size);
            begin
               Input_Full_Records := Input_Records.Full;
               Input_Partial_Records := Input_Records.Partial;
               Output_Full_Records := Output_Records.Full;
               Output_Partial_Records := Output_Records.Partial;
            end;
            Truncated_Records := Converted.Truncated_Records;

            if Length (Options.Output) = 0 then
               Context.Put (Prefix & Slice);
            else
               Write_Dd_Output_File;
            end if;
         end;
      end;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
      if Result.Status = Posix_Tools.Exit_Status.Success then
         Context.Put_Error_Line
           (Posix_Tools.Numbers.Count_Image (Input_Full_Records)
            & "+"
            & Posix_Tools.Numbers.Count_Image (Input_Partial_Records)
            & " records in");
         Context.Put_Error_Line
           (Posix_Tools.Numbers.Count_Image (Output_Full_Records)
            & "+"
            & Posix_Tools.Numbers.Count_Image (Output_Partial_Records)
            & " records out");
         if Truncated_Records > 0 then
            Context.Put_Error_Line
              (Posix_Tools.Numbers.Count_Image (Truncated_Records)
               & (if Truncated_Records = 1 then " truncated record" else " truncated records"));
         end if;
      end if;
   end Run;

end Posix_Tools.Commands.Dd;
