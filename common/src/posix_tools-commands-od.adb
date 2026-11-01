with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Od_Rendering;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.OD_Formats;

package body Posix_Tools.Commands.Od is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.OD_Formats.Address_Base;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Address : Posix_Tools.Text.OD_Formats.Address_Base := Posix_Tools.Text.OD_Formats.Octal_Address;
      Formats : Posix_Tools.Commands.Od_Rendering.Dump_Spec_Vectors.Vector;
      Skip    : Natural := 0;
      Limit   : Natural := 0;
      Has_Limit : Boolean := False;
      Verbose : Boolean := False;
      First : Positive;
      Valid : Boolean;
      Data  : Unbounded_String;
      Ok    : Boolean := True;

      function Set_Address_Base (Spec : String) return Boolean is
         Parsed : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
           Posix_Tools.Text.OD_Formats.Address_Base_For (Spec);
      begin
         if not Parsed.Valid then
            return False;
         end if;
         Address := Parsed.Base;
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

               Posix_Tools.Commands.Od_Rendering.Append_Dump_Format (Formats, Parsed);
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
               Verbose := True;
            when 'A' =>
               if not Set_Address_Base (Value) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when 'j' =>
               Set_Number_Option (Value, True, Skip, Result, Valid);
            when 'N' =>
               Set_Number_Option (Value, False, Limit, Result, Valid);
               Has_Limit := True;
            when 't' =>
               if not Append_Dump_Formats (Value) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when others =>
               --  One of the shorthand formats, -a, -b, -c, -d, -o, -s
               --  or -x.
               if not Posix_Tools.Commands.Od_Rendering.Append_Shorthand_Format (Formats, Name) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, "-" & Name);
                  Valid := False;
               end if;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "AabcdjNostvx", "AjNt", First, Valid);
      if not Valid then
         return;
      end if;
      if Formats.Is_Empty then
         Formats.Append
           (Posix_Tools.Commands.Od_Rendering.Dump_Spec'
              (Kind => Posix_Tools.Commands.Od_Rendering.Octal_Integer,
               Size => 2));
      end if;
      if Context.Argument_Count < First then
         Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, "-", Data, Ok);
      else
         for I in First .. Context.Argument_Count loop
            declare
               Chunk : Unbounded_String;
            begin
               Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Context.Argument (I), Chunk, Ok);
               exit when not Ok;
               Append (Data, To_String (Chunk));
            end;
         end loop;
      end if;
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Source : constant String := To_String (Data);
         Actual_Skip : constant Natural := Natural'Min (Skip, Source'Length);
         Available : constant Natural := Source'Length - Actual_Skip;
         Selected_Length : constant Natural := (if Has_Limit then Natural'Min (Limit, Available) else Available);
         Text   : constant String :=
           (if Selected_Length = 0 then ""
            else Source (Source'First + Actual_Skip .. Source'First + Actual_Skip + Selected_Length - 1));
      begin
         if Skip > Source'Length then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         Posix_Tools.Commands.Od_Rendering.Render
           (Context     => Context,
            Text        => Text,
            Actual_Skip => Actual_Skip,
            Address     => Address,
            Formats     => Formats,
            Verbose     => Verbose);
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;

end Posix_Tools.Commands.Od;
