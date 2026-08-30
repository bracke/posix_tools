with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Numbers;
with Posix_Tools.Text.DD_Blocks;
with Posix_Tools.Text.DD_Conversion_Engine;
with Posix_Tools.Text.DD_Operands;

package body Posix_Tools.Commands.Dd is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;
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

      function Read_Dd_Standard_Input (Read_Ok : out Boolean) return String is
         Buffer : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset
                   (Posix_Tools.Numbers.Count'Min
                      (Options.Input_Block_Size, Posix_Tools.Numbers.Count (16 * 1024))));
         Last   : Ada.Streams.Stream_Element_Offset;
         Text   : Unbounded_String;
      begin
         Read_Ok := True;
         loop
            if not Context.Try_Read_Standard_Input (Buffer, Last) then
               Read_Ok := False;
               exit;
            end if;

            exit when Last < Buffer'First;

            for I in Buffer'First .. Last loop
               Append (Text, Character'Val (Integer (Buffer (I))));
            end loop;
         end loop;

         return To_String (Text);
      end Read_Dd_Standard_Input;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      declare
         Error : Unbounded_String;
      begin
         for I in 1 .. Context.Argument_Count loop
            if not Posix_Tools.Text.DD_Operands.Parse_Argument
              (Context.Argument (I), Options, Error)
            then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, To_String (Error));
               return;
            end if;
         end loop;

         if not Posix_Tools.Text.DD_Operands.Validate (Options, Error) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, To_String (Error));
            return;
         end if;
      end;

      Data :=
        To_Unbounded_String
          ((if Length (Options.Input) = 0 then Read_Dd_Standard_Input (Ok)
            else Posix_Tools.Commands.File_Helpers.Read_File
              (Context, To_String (Options.Input), Ok)));
      if not Ok then
         if not Options.Continue_After_Read_Error then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context,
            (if Length (Options.Input) = 0 then "standard input" else To_String (Options.Input)),
            "posix_tools.diagnostic.file.read_failed",
            "cannot read file");
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
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "offset overflow");
            return;
         end if;

         if Transfer.Status = Posix_Tools.Text.DD_Blocks.Count_Overflow then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "count overflow");
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

            procedure Write_Dd_Output_File is
               use Ada.Streams.Stream_IO;
               File : File_Type;
            begin
               Ok := False;
               if Options.No_Truncate_Output and then FS.Exists (To_String (Options.Output)) then
                  declare
                     Existing_Ok : Boolean := False;
                     Existing    : constant String :=
                       Posix_Tools.Commands.File_Helpers.Read_File
                         (Context, To_String (Options.Output), Existing_Ok);
                     Combined    : Unbounded_String;
                     Offset      : constant Natural := Natural (Transfer.Prefix_Count);
                     Write_Last  : constant Natural := Offset + Slice'Length;
                  begin
                     if not Existing_Ok then
                        return;
                     end if;

                     for I in 1 .. Offset loop
                        if I <= Existing'Length then
                           Append (Combined, Existing (Existing'First + I - 1));
                        else
                           Append (Combined, Character'Val (0));
                        end if;
                     end loop;

                     Append (Combined, Slice);

                     if Write_Last < Existing'Length then
                        Append (Combined, Existing (Existing'First + Write_Last .. Existing'Last));
                     end if;
                     Posix_Tools.Commands.File_Helpers.Write_File
                       (To_String (Options.Output), To_String (Combined), False, Ok);
                  end;
               else
                  Create (File, Out_File, To_String (Options.Output));

                  if Slice'Length > 0 then
                     Set_Index (File, Ada.Streams.Stream_IO.Count (Transfer.Prefix_Count) + 1);
                     declare
                        Buffer : Ada.Streams.Stream_Element_Array
                          (1 .. Ada.Streams.Stream_Element_Offset (Slice'Length));
                     begin
                        for I in Slice'Range loop
                           Buffer (Ada.Streams.Stream_Element_Offset (I - Slice'First + 1)) :=
                             Ada.Streams.Stream_Element (Character'Pos (Slice (I)));
                        end loop;
                        Write (File, Buffer);
                     end;
                  end if;

                  Close (File);
                  Ok := True;
               end if;
            exception
               when others =>
                  if Is_Open (File) then
                     Close (File);
                  end if;
                  Ok := False;
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

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
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
