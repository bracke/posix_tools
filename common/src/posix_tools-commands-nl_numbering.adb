with Ada.Streams;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Nl_Numbering is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.NL_Fields.Logical_Section;

   LF : constant Character := Character'Val (10);

   function Active_Mode (State : Numbering_State) return Posix_Tools.Text.NL_Fields.Number_Mode;

   procedure Emit_Prefix
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      State    : Numbering_State;
      Output   : in out Posix_Tools.Commands.Helpers.Output_Buffer;
      Numbered : Boolean);

   function Is_Logical_Delimiter
     (State       : Numbering_State;
      Line        : String;
      New_Section : out Posix_Tools.Text.NL_Fields.Logical_Section) return Boolean;

   function Active_Mode (State : Numbering_State) return Posix_Tools.Text.NL_Fields.Number_Mode is
   begin
      case State.Section is
         when Posix_Tools.Text.NL_Fields.Header_Section => return State.Header_Mode;
         when Posix_Tools.Text.NL_Fields.Body_Section => return State.Body_Mode;
         when Posix_Tools.Text.NL_Fields.Footer_Section => return State.Footer_Mode;
         when Posix_Tools.Text.NL_Fields.No_Section => return State.Body_Mode;
      end case;
   end Active_Mode;

   procedure Emit_Prefix
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      State    : Numbering_State;
      Output   : in out Posix_Tools.Commands.Helpers.Output_Buffer;
      Numbered : Boolean)
   is
      Text : constant String :=
        (if Numbered
         then Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (State.Value)
         else "");
      Spaces : constant String (1 .. 1_024) := [others => ' '];
      Remaining : Natural :=
        (if Text'Length < State.Width then State.Width - Text'Length else 0);
   begin
      while Remaining > 0 and then not Context.Output_Failed loop
         declare
            Amount : constant Positive := Positive'Min (Remaining, Spaces'Length);
         begin
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, Spaces (1 .. Amount));
            Remaining := Remaining - Amount;
         end;
      end loop;

      if not Context.Output_Failed and then Numbered then
         Posix_Tools.Commands.Helpers.Buffered_Put (Output, Context, Text);
      end if;

      if not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Buffered_Put
           (Output, Context, To_String (State.Separator));
      end if;
   end Emit_Prefix;

   function Is_Logical_Delimiter
     (State       : Numbering_State;
      Line        : String;
      New_Section : out Posix_Tools.Text.NL_Fields.Logical_Section) return Boolean
   is
   begin
      New_Section :=
        Posix_Tools.Text.NL_Fields.Logical_Section_For
          (Line, State.Delimiter (1), State.Delimiter (2));
      if New_Section = Posix_Tools.Text.NL_Fields.No_Section then
         New_Section := State.Section;
         return False;
      else
         return True;
      end if;
   end Is_Logical_Delimiter;

   procedure Number_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      State   : in out Numbering_State;
      Name    : String;
      Ok      : out Boolean)
   is
      use type Posix_Tools.Text.NL_Fields.Number_Mode;

      Probe         : String (1 .. 7);
      Probe_Length  : Natural := 0;
      Decided       : Boolean := False;
      Output_Buffer : Posix_Tools.Commands.Helpers.Output_Buffer;

      procedure Flush;
      procedure Put (Text : String);
      procedure Begin_Ordinary_Line;
      procedure Finish_Probe (Terminated : Boolean);
      procedure Each_Chunk
        (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);

      procedure Flush is
      begin
         Posix_Tools.Commands.Helpers.Flush_Output (Output_Buffer, Context);
      end Flush;

      procedure Put (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Buffered_Put
           (Output_Buffer, Context, Text);
      end Put;

      procedure Begin_Ordinary_Line is
         Mode     : constant Posix_Tools.Text.NL_Fields.Number_Mode :=
           Active_Mode (State);
         Numbered : constant Boolean :=
           Mode = Posix_Tools.Text.NL_Fields.All_Lines
           or else
             (Mode = Posix_Tools.Text.NL_Fields.Nonempty_Lines
              and then Probe_Length > 0);
      begin
         Emit_Prefix (Context, State, Output_Buffer, Numbered);
         if not Context.Output_Failed then
            Put (Probe (1 .. Probe_Length));
         end if;
         if Numbered then
            State.Value := State.Value + State.Increment;
         end if;
         Probe_Length := 0;
         Decided := True;
      end Begin_Ordinary_Line;

      procedure Finish_Probe (Terminated : Boolean) is
         New_Section : Posix_Tools.Text.NL_Fields.Logical_Section;
      begin
         if Is_Logical_Delimiter
           (State, Probe (1 .. Probe_Length), New_Section)
         then
            State.Section := New_Section;
            if New_Section = Posix_Tools.Text.NL_Fields.Header_Section
              and then not State.No_Restart
            then
               State.Value := State.Initial_Value;
            end if;
            Probe_Length := 0;
            Decided := False;
         else
            if State.Width <= 1_024 and then Length (State.Separator) <= 1_024 then
               declare
                  Mode : constant Posix_Tools.Text.NL_Fields.Number_Mode :=
                    Active_Mode (State);
                  Numbered : constant Boolean :=
                    Mode = Posix_Tools.Text.NL_Fields.All_Lines
                    or else
                      (Mode = Posix_Tools.Text.NL_Fields.Nonempty_Lines
                       and then Probe_Length > 0);
                  Number : constant String :=
                    (if Numbered
                     then Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                       (State.Value)
                     else "");
                  Spaces : constant String (1 .. 1_024) := [others => ' '];
                  Padding : constant Natural :=
                    (if Number'Length < State.Width
                     then State.Width - Number'Length else 0);
               begin
                  Posix_Tools.Commands.Helpers.Buffered_Put
                    (Output_Buffer, Context,
                     Spaces (1 .. Padding)
                     & Number
                     & To_String (State.Separator)
                     & Probe (1 .. Probe_Length)
                     & (if Terminated then [1 => LF] else ""));
                  if Numbered then
                     State.Value := State.Value + State.Increment;
                  end if;
                  Probe_Length := 0;
                  Decided := False;
               end;
            else
               Begin_Ordinary_Line;
               if Terminated then
                  Put ([1 => LF]);
               end if;
               Decided := False;
            end if;
         end if;
      end Finish_Probe;

      procedure Each_Chunk
        (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Ignored);
         I : Ada.Streams.Stream_Element_Offset := Buffer'First;
      begin
         if Last < Buffer'First then
            return;
         end if;

         while I <= Last loop
            if Decided and then Buffer (I) /= Ada.Streams.Stream_Element (10) then
               declare
                  First : constant Ada.Streams.Stream_Element_Offset := I;
               begin
                  while I <= Last and then Buffer (I) /= Ada.Streams.Stream_Element (10) loop
                     I := I + 1;
                  end loop;
                  Put
                    (Posix_Tools.Streams.Bytes.To_String
                       (Buffer (First .. I - 1), I - 1));
               end;
            elsif Buffer (I) = Ada.Streams.Stream_Element (10) then
               if Decided then
                  Put ([1 => LF]);
                  Decided := False;
               else
                  Finish_Probe (Terminated => True);
               end if;
               I := I + 1;
            else
               Probe_Length := Probe_Length + 1;
               Probe (Probe_Length) := Character'Val (Buffer (I));
               I := I + 1;
               if Probe_Length = Probe'Length then
                  Begin_Ordinary_Line;
               end if;
            end if;
            exit when Context.Output_Failed;
         end loop;
      end Each_Chunk;

      procedure Iterate is new
        Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
          (Action        => Each_Chunk,
           Buffer_Length =>
             Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
   begin
      Iterate (Context, Name, Ok);
      if Ok and then not Context.Output_Failed
        and then not Decided and then Probe_Length > 0
      then
         Finish_Probe (Terminated => False);
      end if;
      Flush;
      Ok := Ok and then not Context.Output_Failed;
   end Number_File;
end Posix_Tools.Commands.Nl_Numbering;
