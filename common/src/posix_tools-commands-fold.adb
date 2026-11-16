with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Commands.Text_Helpers.Tr_Sets;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.Tab_Stops;

package body Posix_Tools.Commands.Fold is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   Output_Chunk_Size : constant := 64 * 1024;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Width      : Natural := 80;
      Space_Mode : Boolean := False;
      First_File : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;
      Output_Buffer : Unbounded_String;

      procedure Fold_File (Name : String; Ok : out Boolean);
      procedure Flush_Output;
      procedure Put_Output (Text : String);
      procedure Put_LF;
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      function Valid_Width (Text : String; Value : out Natural) return Boolean;

      procedure Fold_File (Name : String; Ok : out Boolean) is
         Pending       : Unbounded_String;
         Carry         : Unbounded_String;
         Column        : Natural := 0;
         Tail_Column   : Natural := 0;
         Blank_Length  : Natural := 0;
         Have_Blank    : Boolean := False;
         Have_Content  : Boolean := False;
         Action_Ok     : Boolean := True;

         procedure Emit_Pending;
         procedure Break_Line;
         procedure Finish_Line (Terminated : Boolean);
         procedure Fold_Data (Text : String; At_End : Boolean);
         procedure Each_Chunk
           (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset);

         procedure Emit_Pending is
            First : Positive := 1;
         begin
            while First <= Length (Pending) loop
               declare
                  Last : constant Natural :=
                    Natural'Min
                      (Length (Pending), First + Output_Chunk_Size - 1);
               begin
                  Put_Output (Slice (Pending, First, Last));
                  First := Last + 1;
               end;
            end loop;
            Pending := Null_Unbounded_String;
         end Emit_Pending;

         procedure Break_Line is
         begin
            if Space_Mode and then Have_Blank then
               Put_Output (Slice (Pending, 1, Blank_Length));
               Put_LF;
               if Blank_Length < Length (Pending) then
                  Pending := To_Unbounded_String
                    (Slice (Pending, Blank_Length + 1, Length (Pending)));
               else
                  Pending := Null_Unbounded_String;
               end if;
               Column := Tail_Column;
               Have_Content := Length (Pending) > 0;
            else
               Emit_Pending;
               Put_LF;
               Column := 0;
               Have_Content := False;
            end if;
            Have_Blank := False;
            Blank_Length := 0;
            Tail_Column := 0;
         end Break_Line;

         procedure Finish_Line (Terminated : Boolean) is
         begin
            Emit_Pending;
            if Terminated then
               Put_LF;
            end if;
            Column := 0;
            Tail_Column := 0;
            Blank_Length := 0;
            Have_Blank := False;
            Have_Content := False;
         end Finish_Line;

         procedure Fold_Data (Text : String; At_End : Boolean) is
            I          : Positive := Text'First;
            Unit_Width : Natural;
            Code_Point : Long_Long_Integer;
            Next       : Natural;
            Tail_Next  : Natural;
            Is_Blank   : Boolean;

            function Ordinary_ASCII (Ch : Character) return Boolean is
              (Character'Pos (Ch) <= 16#7F#
               and then Ch not in LF | HT | Character'Val (8) | Character'Val (13));

            function Next_Column
              (Ch : Character;
               Code : Long_Long_Integer;
               From : Natural) return Natural;

            function Next_Column
              (Ch : Character;
               Code : Long_Long_Integer;
               From : Natural) return Natural
            is
            begin
               if Ch = HT then
                  return From + (8 - (From mod 8));
               elsif Ch = Character'Val (8) then
                  return (if From = 0 then 0 else From - 1);
               elsif Ch = Character'Val (13) then
                  return 0;
               elsif Character'Pos (Ch) <= 16#7F#
                 or else Code = Posix_Tools.Commands.Text_Helpers.Tr_Sets.No_Code_Point
               then
                  return From + 1;
               else
                  return From
                    + Posix_Tools.Commands.Text_Helpers.Display.Display_Width (Code);
               end if;
            end Next_Column;
         begin
            while I <= Text'Last loop
               if Text (I) = LF then
                  Finish_Line (Terminated => True);
                  I := I + 1;
               elsif not Space_Mode and then Ordinary_ASCII (Text (I)) then
                  declare
                     Run_Last : Natural := I;
                     Cursor   : Positive := I;
                  begin
                     while Run_Last < Text'Last
                       and then Ordinary_ASCII (Text (Run_Last + 1))
                     loop
                        Run_Last := Run_Last + 1;
                     end loop;

                     while Cursor <= Run_Last loop
                        if Column = Width and then Have_Content then
                           Break_Line;
                           if Context.Output_Failed then
                              Action_Ok := False;
                              return;
                           end if;
                        end if;
                        declare
                           Room : constant Positive := Width - Column;
                           Count : constant Positive :=
                             Natural'Min (Room, Run_Last - Cursor + 1);
                        begin
                           Append (Pending, Text (Cursor .. Cursor + Count - 1));
                           Column := Column + Count;
                           Have_Content := True;
                           Cursor := Cursor + Count;
                        end;

                        if Length (Pending) >= 64 * 1024 then
                           Emit_Pending;
                        end if;
                        exit when Context.Output_Failed;
                     end loop;
                     I := Run_Last + 1;
                  end;
               else
                  if Character'Pos (Text (I)) > 16#7F# then
                     Posix_Tools.Commands.Text_Helpers.Tr_Sets.Decode_At
                       (Text, I, At_End, Unit_Width, Code_Point);
                     if Unit_Width = 0 then
                        Carry := To_Unbounded_String (Text (I .. Text'Last));
                        return;
                     end if;
                  else
                     Unit_Width := 1;
                     Code_Point := Long_Long_Integer (Character'Pos (Text (I)));
                  end if;
                  Is_Blank := Text (I) = ' ' or else Text (I) = HT;

                  loop
                     Next := Next_Column (Text (I), Code_Point, Column);
                     exit when Next <= Width or else not Have_Content;
                     Break_Line;
                     if Context.Output_Failed then
                        Action_Ok := False;
                        return;
                     end if;
                  end loop;

                  if Space_Mode and then Is_Blank then
                     Emit_Pending;
                     Append (Pending, Text (I .. I + Unit_Width - 1));
                     Have_Blank := True;
                     Blank_Length := Unit_Width;
                     Tail_Column := 0;
                  else
                     Append (Pending, Text (I .. I + Unit_Width - 1));
                     if Have_Blank then
                        Tail_Next :=
                          Next_Column (Text (I), Code_Point, Tail_Column);
                        Tail_Column := Tail_Next;
                     end if;
                  end if;
                  Column := Next;
                  Have_Content := True;
                  I := I + Unit_Width;

                  if Column > Width then
                     Emit_Pending;
                     Put_LF;
                     Column := 0;
                     Tail_Column := 0;
                     Blank_Length := 0;
                     Have_Blank := False;
                     Have_Content := False;
                  elsif Length (Pending) >= 64 * 1024
                    and then (not Space_Mode or else not Have_Blank)
                  then
                     Emit_Pending;
                  end if;
               end if;

               if Context.Output_Failed then
                  Action_Ok := False;
                  return;
               end if;
            end loop;
         end Fold_Data;

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
            Fold_Data (Data, At_End => False);
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
               Fold_Data (Final_Data, At_End => True);
            end;
         end if;
         if Ok and then Action_Ok then
            Finish_Line (Terminated => False);
         end if;
         Flush_Output;
         Ok := Ok and then Action_Ok and then not Context.Output_Failed;
      end Fold_File;

      procedure Flush_Output is
      begin
         if Length (Output_Buffer) > 0 and then not Context.Output_Failed then
            Context.Put (To_String (Output_Buffer));
         end if;
         Output_Buffer := Null_Unbounded_String;
      end Flush_Output;

      procedure Put_Output (Text : String) is
      begin
         Append (Output_Buffer, Text);
         if Length (Output_Buffer) >= Output_Chunk_Size then
            Flush_Output;
         end if;
      end Put_Output;

      procedure Put_LF is
      begin
         Put_Output ([1 => LF]);
      end Put_LF;

      function Valid_Width (Text : String; Value : out Natural) return Boolean is
         Parsed : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop :=
           Posix_Tools.Text.Tab_Stops.Parse_Stop (Text, 0);
      begin
         if Parsed.Valid then
            Value := Parsed.Value;
            return True;
         else
            Value := 0;
            return False;
         end if;
      end Valid_Width;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
      begin
         --  -b is accepted and needs no handling of its own.
         Valid := True;
         if Name = 's' then
            Space_Mode := True;
         elsif Name = 'w' and then not Valid_Width (Value, Width) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            Valid := False;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "bsw", "w", First_File, Valid);
      if not Valid then
         return;
      end if;

      if Context.Argument_Count < First_File then
         Fold_File ("-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Fold_File (Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Fold;
