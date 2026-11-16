with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.Tab_Stops;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.Unexpand is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Tab_Config : Posix_Tools.Commands.Text_Helpers.Tab_Stops.Configuration;
      All_Blanks : Boolean := False;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;
      Output_Buffer : Unbounded_String;

      procedure Flush_Output;

      procedure Emit_Blanks
        (Count        : Natural;
         Start_Column : in out Natural;
         Compress     : Boolean);
      procedure Put_Byte (Ch : Character);
      procedure Put_Text (Text : String);
      procedure Unexpand_File (Name : String; Ok : out Boolean);

      procedure Flush_Output is
      begin
         if Length (Output_Buffer) > 0 and then not Context.Output_Failed then
            Context.Put (To_String (Output_Buffer));
         end if;
         Output_Buffer := Null_Unbounded_String;
      end Flush_Output;

      procedure Emit_Blanks
        (Count        : Natural;
         Start_Column : in out Natural;
         Compress     : Boolean)
      is
         Block     : constant String (1 .. 1_024) := (others => ' ');
         Remaining : Natural := Count;
         Needed    : Natural;
      begin
         if not Compress then
            while Remaining > 0 loop
               declare
                  Written : constant Natural := Natural'Min (Remaining, Block'Length);
               begin
                  Put_Text (Block (1 .. Written));
                  Start_Column := Start_Column + Written;
                  Remaining := Remaining - Written;
               end;
               exit when Context.Output_Failed;
            end loop;
            return;
         end if;

         while Remaining > 0 loop
            Needed :=
              Posix_Tools.Commands.Text_Helpers.Tab_Stops.Spaces_To_Next_Tab
                (Tab_Config, Start_Column);
            if Remaining >= Needed and then Needed > 1 then
               Put_Byte (HT);
               Start_Column := Start_Column + Needed;
               Remaining := Remaining - Needed;
            elsif Remaining < Needed then
               --  Fewer blanks than the next tab stop cannot form a tab;
               --  their whole remainder can be copied in blocks.
               declare
                  Written : constant Natural := Natural'Min (Remaining, Block'Length);
               begin
                  Put_Text (Block (1 .. Written));
                  Start_Column := Start_Column + Written;
                  Remaining := Remaining - Written;
               end;
            else
               --  A one-column tab is not shorter than a space, but later
               --  blanks may still reach a wider tab stop.
               Put_Byte (' ');
               Start_Column := Start_Column + 1;
               Remaining := Remaining - 1;
            end if;

            exit when Context.Output_Failed;
         end loop;
      end Emit_Blanks;

      procedure Put_Byte (Ch : Character) is
      begin
         Append (Output_Buffer, Ch);
         if Length (Output_Buffer) >= 64 * 1024 then
            Flush_Output;
         end if;
      end Put_Byte;

      procedure Put_Text (Text : String) is
      begin
         Append (Output_Buffer, Text);
         if Length (Output_Buffer) >= 64 * 1024 then
            Flush_Output;
         end if;
      end Put_Text;

      procedure Unexpand_File (Name : String; Ok : out Boolean) is
         Action_Ok : Boolean := True;
         Carry     : Unbounded_String;
         Column    : Natural := 0;
         Leading   : Boolean := True;
         Pending   : Natural := 0;

         procedure Unexpand_Data (Text : String; At_End : Boolean);
         procedure Each_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Flush_Blanks is
         begin
            if Pending > 0 then
               Emit_Blanks (Pending, Column, All_Blanks or else Leading);
               Pending := 0;
            end if;
         end Flush_Blanks;

         procedure Unexpand_Data (Text : String; At_End : Boolean) is
            Width      : Natural;
            Code_Point : Long_Long_Integer;
            I          : Positive := Text'First;
         begin
            while I <= Text'Last loop
               if Text (I) = ' ' then
                  Pending := Pending + 1;
                  I := I + 1;
               else
                  Flush_Blanks;
                  if Context.Output_Failed then
                     Action_Ok := False;
                     return;
                  end if;

                  if Text (I) = LF then
                     Put_Byte (LF);
                     Column := 0;
                     Leading := True;
                     I := I + 1;
                  elsif Text (I) = HT then
                     Put_Byte (HT);
                     Column :=
                       Column
                       + Posix_Tools.Commands.Text_Helpers.Tab_Stops.Spaces_To_Next_Tab
                           (Tab_Config, Column);
                     I := I + 1;
                  elsif Character'Pos (Text (I)) > 16#7F# then
                     Posix_Tools.Commands.Text_Helpers.Tr_Sets.Decode_At
                       (Text, I, At_End, Width, Code_Point);
                     if Width = 0 then
                        Carry := To_Unbounded_String (Text (I .. Text'Last));
                        return;
                     end if;
                     Put_Text (Text (I .. I + Width - 1));
                     Column :=
                       Column
                       + (if Code_Point =
                               Posix_Tools.Commands.Text_Helpers.Tr_Sets.No_Code_Point
                          then 1
                          else Posix_Tools.Commands.Text_Helpers.Display.Display_Width
                            (Code_Point));
                     Leading := False;
                     I := I + Width;
                  elsif Text (I) = Character'Val (8) then
                     Put_Byte (Text (I));
                     Column := (if Column = 0 then 0 else Column - 1);
                     Leading := False;
                     I := I + 1;
                  elsif Text (I) = Character'Val (13) then
                     Put_Byte (Text (I));
                     Column := 0;
                     Leading := False;
                     I := I + 1;
                  else
                     declare
                        First : constant Positive := I;
                     begin
                        while I <= Text'Last
                          and then Text (I) /= ' '
                          and then Text (I) /= HT
                          and then Text (I) /= LF
                          and then Text (I) /= Character'Val (8)
                          and then Text (I) /= Character'Val (13)
                          and then Character'Pos (Text (I)) <= 16#7F#
                        loop
                           I := I + 1;
                        end loop;
                        Put_Text (Text (First .. I - 1));
                        Column := Column + I - First;
                        Leading := False;
                     end;
                  end if;
               end if;

               if Context.Output_Failed then
                  Action_Ok := False;
                  return;
               end if;
            end loop;
         end Unexpand_Data;

         procedure Each_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Ignored);
            Data : constant String :=
              (if Length (Carry) = 0
               then Posix_Tools.Streams.Bytes.To_String (Buffer, Last)
               else To_String (Carry)
                 & Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
         begin
            Carry := Null_Unbounded_String;
            Unexpand_Data (Data, At_End => False);
         end Each_Chunk;

         procedure Iterate is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
             (Action        => Each_Chunk,
              Buffer_Length =>
                Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      begin
         Iterate (Context, Name, Ok);
         if Ok and then Action_Ok and then Length (Carry) > 0 then
            declare
               Final_Data : constant String := To_String (Carry);
            begin
               Carry := Null_Unbounded_String;
               Unexpand_Data (Final_Data, At_End => True);
            end;
         end if;
         if Ok and then Action_Ok then
            Flush_Blanks;
         end if;
         Flush_Output;
         Ok := Ok and then Action_Ok and then not Context.Output_Failed;
      end Unexpand_File;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First_File <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First_File);
         begin
            if Arg = "--" then
               First_File := First_File + 1;
               exit;
            elsif Arg = "-a" then
               All_Blanks := True;
               First_File := First_File + 1;
            elsif Arg = "-t" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, "-t");
                  return;
               elsif not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse
                 (Tab_Config, Context.Argument (First_File + 1))
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Invalid_Operand, Context.Argument (First_File + 1));
                  return;
               end if;
               First_File := First_File + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 't'
            then
               if not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse
                 (Tab_Config, Arg (Arg'First + 2 .. Arg'Last))
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Invalid_Operand, Arg (Arg'First + 2 .. Arg'Last));
                  return;
               end if;
               First_File := First_File + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, Unknown_Option,
                  Posix_Tools.Commands.Helpers.Unknown_Option_Subject (Arg, "at"));
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if Context.Argument_Count < First_File then
         Unexpand_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Unexpand_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Unexpand;
