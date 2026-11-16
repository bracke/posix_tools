with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.Tab_Stops;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.Expand is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Tab_Config : Posix_Tools.Commands.Text_Helpers.Tab_Stops.Configuration;
      First_File : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;
      Pending    : Unbounded_String;
      Space_Block : constant String (1 .. 1_024) := (others => ' ');

      procedure Flush_Output;
      procedure Put_Output (Text : String);
      procedure Put_Spaces (Count : Natural);

      procedure Expand_File (Name : String; Ok : out Boolean);

      procedure Flush_Output is
      begin
         if Length (Pending) > 0 and then not Context.Output_Failed then
            Context.Put (To_String (Pending));
         end if;
         Pending := Null_Unbounded_String;
      end Flush_Output;

      procedure Put_Output (Text : String) is
      begin
         Append (Pending, Text);
         if Length (Pending) >= 64 * 1024 then
            Flush_Output;
         end if;
      end Put_Output;

      procedure Put_Spaces (Count : Natural) is
         Remaining : Natural := Count;
      begin
         while Remaining > 0 loop
            declare
               Amount : constant Natural := Natural'Min (Remaining, Space_Block'Length);
            begin
               Put_Output (Space_Block (1 .. Amount));
               Remaining := Remaining - Amount;
            end;
            exit when Context.Output_Failed;
         end loop;
      end Put_Spaces;

      procedure Expand_File (Name : String; Ok : out Boolean) is
         Action_Ok : Boolean := True;
         Carry     : Unbounded_String;
         Column    : Natural := 0;

         procedure Expand_Data (Text : String; At_End : Boolean);
         procedure Each_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Expand_Data (Text : String; At_End : Boolean)
         is
            Spaces     : Natural;
            Width      : Natural;
            Code_Point : Long_Long_Integer;
            I          : Positive := Text'First;
         begin
            while I <= Text'Last loop
               if Text (I) = HT then
                  Spaces :=
                    Posix_Tools.Commands.Text_Helpers.Tab_Stops.Next_Column
                      (Tab_Config, Column) - Column;
                  Put_Spaces (Spaces);
                  Column := Column + Spaces;
                  I := I + 1;
               elsif Text (I) = LF then
                  Put_Output ([1 => LF]);
                  Column := 0;
                  I := I + 1;
               elsif Character'Pos (Text (I)) > 16#7F# then
                  Posix_Tools.Commands.Text_Helpers.Tr_Sets.Decode_At
                    (Text, I, At_End, Width, Code_Point);
                  if Width = 0 then
                     Carry := To_Unbounded_String (Text (I .. Text'Last));
                     return;
                  end if;
                  Put_Output (Text (I .. I + Width - 1));
                  Column :=
                    Column
                    + (if Code_Point =
                            Posix_Tools.Commands.Text_Helpers.Tr_Sets.No_Code_Point
                       then 1
                       else Posix_Tools.Commands.Text_Helpers.Display.Display_Width
                         (Code_Point));
                  I := I + Width;
               elsif Text (I) = Character'Val (8) then
                  Put_Output ([1 => Text (I)]);
                  Column := (if Column = 0 then 0 else Column - 1);
                  I := I + 1;
               elsif Text (I) = Character'Val (13) then
                  Put_Output ([1 => Text (I)]);
                  Column := 0;
                  I := I + 1;
               else
                  declare
                     First : constant Positive := I;
                  begin
                     while I <= Text'Last
                       and then Text (I) /= HT
                       and then Text (I) /= LF
                       and then Text (I) /= Character'Val (8)
                       and then Text (I) /= Character'Val (13)
                       and then Character'Pos (Text (I)) <= 16#7F#
                     loop
                        I := I + 1;
                     end loop;
                     Put_Output (Text (First .. I - 1));
                     Column := Column + I - First;
                  end;
               end if;

               if Context.Output_Failed then
                  Action_Ok := False;
                  return;
               end if;
            end loop;
         end Expand_Data;

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
            Expand_Data (Data, At_End => False);
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
               Expand_Data (Final_Data, At_End => True);
            end;
         end if;
         Flush_Output;
         Ok := Ok and then Action_Ok and then not Context.Output_Failed;
      end Expand_File;

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
         pragma Unreferenced (Name);
      begin
         Valid := True;
         if not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse (Tab_Config, Value) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            Valid := False;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "t", "t", First_File, Valid);
      if not Valid then
         return;
      end if;

      if Context.Argument_Count < First_File then
         Expand_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Expand_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Expand;
