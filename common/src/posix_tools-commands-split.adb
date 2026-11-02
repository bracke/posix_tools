with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Suffixes;

package body Posix_Tools.Commands.Split is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   --  -b's size: a positive number of bytes, n, followed by k for n
   --  kibibytes or m for n mebibytes.
   function Byte_Size (Text : String) return Posix_Tools.Text.Decimal_Parsing.Parsed_Natural;

   function Byte_Size (Text : String) return Posix_Tools.Text.Decimal_Parsing.Parsed_Natural is
      Invalid    : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural := (Valid => False, Value => 0);
      Has_Suffix : constant Boolean := Text'Length > 0 and then Text (Text'Last) in 'k' | 'm';
      Multiplier : constant Natural :=
        (if not Has_Suffix then 1 elsif Text (Text'Last) = 'k' then 1024 else 1024 * 1024);
      Count      : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
          (Text (Text'First .. (if Has_Suffix then Text'Last - 1 else Text'Last)), 1, Natural'Last);
   begin
      if not Count.Valid or else Count.Value > Natural'Last / Multiplier then
         return Invalid;
      end if;
      return (Valid => True, Value => Count.Value * Multiplier);
   end Byte_Size;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Lines_Per_File : Natural := 1000;
      Bytes_Per_File : Natural := 0;
      Suffix_Length  : Positive := 2;
      First          : Positive;
      Valid          : Boolean;
      Input          : Unbounded_String := To_Unbounded_String ("-");
      Prefix         : Unbounded_String := To_Unbounded_String ("x");
      Data           : Unbounded_String;
      Ok             : Boolean;

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
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
           (case Name is
               when 'a' => Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Value, 1, 12),
               when 'l' => Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Value, 1, Natural'Last),
               when others => Byte_Size (Value));
      begin
         Valid := Parsed.Valid;
         if not Valid then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            return;
         end if;
         case Name is
            when 'a' => Suffix_Length := Positive (Parsed.Value);
            when 'l' => Lines_Per_File := Parsed.Value;
            when others => Bytes_Per_File := Parsed.Value;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "abl", "abl", First, Valid);
      if not Valid then
         return;
      end if;
      declare
         Remaining : constant Natural :=
           (if First > Context.Argument_Count then 0 else Context.Argument_Count - First + 1);
      begin
         if Remaining > 2 then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + 2));
            return;
         elsif Remaining >= 1 then
            Input := To_Unbounded_String (Context.Argument (First));
            if Remaining = 2 then
               Prefix := To_Unbounded_String (Context.Argument (First + 1));
            end if;
         end if;
      end;

      Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, To_String (Input), Data, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         Text  : constant String := To_String (Data);
         Start : Positive := 1;
         Part  : Natural := 0;
      begin
         while Start <= Text'Length loop
            declare
               Last : Natural := Start - 1;
            begin
               if Bytes_Per_File > 0 then
                  Last := Natural'Min (Text'Length, Start + Bytes_Per_File - 1);
               else
                  for Count in 1 .. Lines_Per_File loop
                     exit when Last >= Text'Length;
                     Last := Last + 1;
                     while Last < Text'Length and then Text (Last) /= LF loop
                        Last := Last + 1;
                     end loop;
                  end loop;
               end if;
               if Part >= Posix_Tools.Text.Suffixes.Lowercase_Capacity (Suffix_Length) then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix),
                     "posix_tools.diagnostic.resource.limit",
                     "resource limit exceeded");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               Posix_Tools.Host_Adapters.File_System.Write_File
                 (To_String (Prefix)
                  & Posix_Tools.Text.Suffixes.Lowercase_Image (Part, Suffix_Length),
                  Text (Start .. Last),
                  False,
                  Ok);
               if not Ok then
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     To_String (Prefix)
                     & Posix_Tools.Text.Suffixes.Lowercase_Image (Part, Suffix_Length),
                     "posix_tools.diagnostic.file.open_failed",
                     "cannot open file");
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
               Part := Part + 1;
               Start := Last + 1;
            end;
         end loop;
      end;
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;

end Posix_Tools.Commands.Split;
