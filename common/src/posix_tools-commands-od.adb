with Ada.Streams;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Od_Rendering;
with Posix_Tools.Exit_Status;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.OD_Formats;

package body Posix_Tools.Commands.Od is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Text.OD_Formats.Address_Base;

   --  What od's options ask for.
   type Settings is record
      Address   : Posix_Tools.Text.OD_Formats.Address_Base := Posix_Tools.Text.OD_Formats.Octal_Address;
      --  The -t formats and shorthands, in order; one octal word without any.
      Formats   : Posix_Tools.Commands.Od_Rendering.Dump_Spec_Vectors.Vector;
      Skip      : Natural := 0;
      Limit     : Natural := 0;
      Has_Limit : Boolean := False;
      Verbose   : Boolean := False;
   end record;

   --  Read od's options into Options; First is the first operand. Valid is
   --  False, with the usage error given, when one is wrong.
   procedure Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : out Settings;
      First   : out Positive;
      Valid   : out Boolean);

   procedure Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : out Settings;
      First   : out Positive;
      Valid   : out Boolean)
   is
      function Set_Address_Base (Spec : String) return Boolean is
         Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
           Posix_Tools.Text.OD_Formats.Address_Base_For (Spec);
      begin
         if not Parsed.Valid then
            return False;
         end if;
         Options.Address := Parsed.Base;
         return True;
      end Set_Address_Base;

      function Append_Dump_Formats (Spec : String) return Boolean is
         Index : Positive := Spec'First;
      begin
         if Spec = "" then
            return False;
         end if;

         while Index <= Spec'Last loop
            declare
               Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
                 Posix_Tools.Text.OD_Formats.Dump_Format_Item (Spec, Index);
            begin
               if not Parsed.Valid then
                  return False;
               end if;

               Posix_Tools.Commands.Od_Rendering.Append_Dump_Format (Options.Formats, Parsed);
               if Parsed.At_End then
                  exit;
               end if;
               Index := Parsed.Next_Index;
            end;
         end loop;
         return True;
      end Append_Dump_Formats;

      --  Set Target to the -j offset or -N count Text, Skip_Form saying
      --  which.
      procedure Set_Number_Option
        (Text      : String;
         Skip_Form : Boolean;
         Target    : out Natural;
         Result    : in out Posix_Tools.Commands.Results.Result;
         Valid     : out Boolean)
      is
         Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
           Posix_Tools.Text.OD_Formats.Offset_Count (Text, Skip_Form);
      begin
         if not Parsed.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Text);
            Valid := False;
            Target := 0;
         else
            Valid := True;
            Target := Parsed.Value;
         end if;
      end Set_Number_Option;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
      begin
         Valid := True;
         case Name is
            when 'v' =>
               Options.Verbose := True;
            when 'A' =>
               if not Set_Address_Base (Value) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when 'j' =>
               Set_Number_Option (Value, True, Options.Skip, Result, Valid);
            when 'N' =>
               Set_Number_Option (Value, False, Options.Limit, Result, Valid);
               Options.Has_Limit := True;
            when 't' =>
               if not Append_Dump_Formats (Value) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when others =>
               --  One of the shorthand formats, -a, -b, -c, -d, -o, -s
               --  or -x.
               if not Posix_Tools.Commands.Od_Rendering.Append_Shorthand_Format (Options.Formats, Name) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, "-" & Name);
                  Valid := False;
               end if;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      Options := (others => <>);
      Parse (Context, Result, "AabcdjNostvx", "AjNt", First, Valid);
      if Valid and then Options.Formats.Is_Empty then
         Options.Formats.Append
           (Posix_Tools.Commands.Od_Rendering.Dump_Spec'
              (Kind => Posix_Tools.Commands.Od_Rendering.Octal_Integer,
               Size => 2));
      end if;
   end Parse_Options;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Settings;
      First   : Positive;
      Valid   : Boolean;
      Ok      : Boolean := True;
      State   : Posix_Tools.Commands.Od_Rendering.Renderer;
      Seen    : Natural := 0;
      Emitted : Natural := 0;

      function Done return Boolean is
        (Seen >= Options.Skip
         and then Options.Has_Limit
         and then Emitted >= Options.Limit);

      procedure Consume
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset);

      procedure Consume
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         Length     : constant Natural :=
           (if Last < Buffer'First then 0
            else Natural (Last - Buffer'First + 1));
         Before     : constant Natural := Seen;
         Drop       : constant Natural :=
           (if Before >= Options.Skip then 0
            else Natural'Min (Length, Options.Skip - Before));
         Available  : constant Natural := Length - Drop;
         Take       : constant Natural :=
           (if not Options.Has_Limit then Available
            else Natural'Min (Available, Options.Limit - Emitted));
      begin
         Seen := Seen + Length;
         if Take > 0 then
            declare
               First_Byte : constant Ada.Streams.Stream_Element_Offset :=
                 Buffer'First + Ada.Streams.Stream_Element_Offset (Drop);
               Last_Byte  : constant Ada.Streams.Stream_Element_Offset :=
                 First_Byte + Ada.Streams.Stream_Element_Offset (Take) - 1;
            begin
               Posix_Tools.Commands.Od_Rendering.Feed
                 (State, Context,
                  Posix_Tools.Streams.Bytes.To_String
                    (Buffer (First_Byte .. Last_Byte), Last_Byte));
            end;
            Emitted := Emitted + Take;
         end if;
      end Consume;

      procedure Read_Bounded_Input is new
        Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
          (Action => Consume);
      procedure Read_Bulk_Input is new
        Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
          (Action        => Consume,
           Buffer_Length =>
             Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);

      procedure Read_Input (Name : String; Read_Ok : out Boolean) is
      begin
         if Options.Has_Limit then
            Read_Bounded_Input (Context, Name, Read_Ok, Done'Access);
         else
            Read_Bulk_Input (Context, Name, Read_Ok, Done'Access);
         end if;
      end Read_Input;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse_Options (Context, Result, Options, First, Valid);
      if not Valid then
         return;
      end if;
      Posix_Tools.Commands.Od_Rendering.Initialize
        (State, Options.Skip, Options.Address, Options.Formats, Options.Verbose);
      if Context.Argument_Count < First then
         Read_Input ("-", Ok);
      else
         for I in First .. Context.Argument_Count loop
            Read_Input (Context.Argument (I), Ok);
            exit when not Ok or else Done;
         end loop;
      end if;
      if not Ok then
         Posix_Tools.Commands.Od_Rendering.Flush_Output (State, Context);
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      if Options.Skip > Seen then
         Posix_Tools.Commands.Od_Rendering.Flush_Output (State, Context);
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Posix_Tools.Commands.Od_Rendering.Finish (State, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;

end Posix_Tools.Commands.Od;
