with Ada.Streams;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Input_Files;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Cmp is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Array;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Host_Adapters.Input_Files.Read_Outcome;
   package Inputs renames Posix_Tools.Host_Adapters.Input_Files;

   Buffer_Size : constant := 64 * 1024;
   subtype Buffer_Type is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
      List   : Boolean := False;
      First  : Positive;
      Valid  : Boolean;

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
         pragma Unreferenced (Value, Result);
      begin
         if Name = 's' then Silent := True; else List := True; end if;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "ls", "", First, Valid);
      if not Valid then
         return;
      elsif Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      elsif Context.Argument_Count > First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, Extra_Operand, Context.Argument (First + 2));
         return;
      end if;

      if Context.Argument (First) = "-" and then Context.Argument (First + 1) = "-" then
         Result.Status := Posix_Tools.Exit_Status.Success;
         return;
      end if;

      declare
         type Source is limited record
            File       : Inputs.Input_File;
            Is_Stdin   : Boolean := False;
            Buffer     : Buffer_Type;
            Next       : Ada.Streams.Stream_Element_Offset := Buffer_Type'First;
            Last       : Ada.Streams.Stream_Element_Offset := Buffer_Type'First - 1;
            At_End     : Boolean := False;
            Failed     : Boolean := False;
         end record;

         Left, Right : Source;
         Byte_Number : Long_Long_Integer := 0;
         Line_Number : Long_Long_Integer := 1;
         Different   : Boolean := False;
         Advanced    : Boolean := False;

         procedure Close_Source (Item : in out Source);
         procedure Fill (Item : in out Source);
         procedure Open_Source (Item : in out Source; Name : String);

         procedure Close_Source (Item : in out Source) is
            Closed : Boolean;
         begin
            if Inputs.Is_Open (Item.File) then
               Inputs.Close (Item.File, Closed);
               Item.Failed := Item.Failed or else not Closed;
            end if;
         end Close_Source;

         procedure Fill (Item : in out Source) is
            Outcome : Inputs.Read_Outcome;
         begin
            if Item.At_End or else Item.Failed or else Item.Next <= Item.Last then
               return;
            end if;
            if Item.Is_Stdin then
               if Context.Try_Read_Standard_Input (Item.Buffer, Item.Last) then
                  Item.At_End := Item.Last < Item.Buffer'First;
               else
                  Item.Failed := True;
               end if;
            else
               Inputs.Read (Item.File, Item.Buffer, Item.Last, Outcome);
               Item.At_End := Outcome = Inputs.Read_End;
               Item.Failed := Outcome = Inputs.Read_Failed;
            end if;
            Item.Next := Item.Buffer'First;
         end Fill;

         procedure Open_Source (Item : in out Source; Name : String) is
            Opened : Boolean;
         begin
            Item.Is_Stdin := Name = "-";
            if not Item.Is_Stdin then
               Inputs.Open (Item.File, Name, Opened);
               Item.Failed := not Opened;
            end if;
         end Open_Source;
      begin
         Open_Source (Left, Context.Argument (First));
         Open_Source (Right, Context.Argument (First + 1));
         if Left.Failed or else Right.Failed then
            Close_Source (Left);
            Close_Source (Right);
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Result.Status := Posix_Tools.Exit_Status.Cmp_Trouble;
            return;
         end if;

         loop
            Fill (Left);
            Fill (Right);
            exit when Left.Failed or else Right.Failed;
            exit when Left.At_End or else Right.At_End;
            Advanced := False;

            declare
               Left_Available : constant Ada.Streams.Stream_Element_Offset :=
                 Left.Last - Left.Next + 1;
               Right_Available : constant Ada.Streams.Stream_Element_Offset :=
                 Right.Last - Right.Next + 1;
               Amount : constant Ada.Streams.Stream_Element_Offset :=
                 Ada.Streams.Stream_Element_Offset'Min
                   (Left_Available, Right_Available);
               Left_Last  : constant Ada.Streams.Stream_Element_Offset :=
                 Left.Next + Amount - 1;
               Right_Last : constant Ada.Streams.Stream_Element_Offset :=
                 Right.Next + Amount - 1;
               Equal : constant Boolean :=
                 Left.Buffer (Left.Next .. Left_Last)
                   = Right.Buffer (Right.Next .. Right_Last);
            begin
               if Equal then
                  if not Silent and then not List then
                     for I in Left.Next .. Left_Last loop
                        if Left.Buffer (I) = Ada.Streams.Stream_Element (10) then
                           Line_Number := Line_Number + 1;
                        end if;
                     end loop;
                  end if;
                  Byte_Number := Byte_Number + Long_Long_Integer (Amount);
                  Left.Next := Left_Last + 1;
                  Right.Next := Right_Last + 1;
                  Advanced := True;
               elsif Silent then
                  Different := True;
                  exit;
               elsif not List then
                  for Offset in Ada.Streams.Stream_Element_Offset range 0 .. Amount - 1 loop
                     Byte_Number := Byte_Number + 1;
                     if Left.Buffer (Left.Next + Offset) /=
                       Right.Buffer (Right.Next + Offset)
                     then
                        Different := True;
                        Context.Put_Line
                          (Context.Argument (First) & " " & Context.Argument (First + 1)
                           & " differ: byte "
                           & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Byte_Number)
                           & ", line "
                           & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Line_Number));
                        exit;
                     elsif Left.Buffer (Left.Next + Offset) =
                       Ada.Streams.Stream_Element (10)
                     then
                        Line_Number := Line_Number + 1;
                     end if;
                  end loop;
                  Advanced := True;
               end if;
            end;

            if not Advanced then
               Byte_Number := Byte_Number + 1;
               if Left.Buffer (Left.Next) /= Right.Buffer (Right.Next) then
                  Different := True;
                  if Silent then
                     exit;
                  elsif List then
                     Context.Put_Line
                       (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Byte_Number) & " "
                        & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                            (Natural (Left.Buffer (Left.Next)), 3) & " "
                        & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                            (Natural (Right.Buffer (Right.Next)), 3));
                  else
                     Context.Put_Line
                       (Context.Argument (First) & " " & Context.Argument (First + 1)
                        & " differ: byte "
                        & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Byte_Number)
                        & ", line "
                        & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Line_Number));
                     exit;
                  end if;
               end if;
               if Left.Buffer (Left.Next) = Ada.Streams.Stream_Element (10) then
                  Line_Number := Line_Number + 1;
               end if;
               Left.Next := Left.Next + 1;
               Right.Next := Right.Next + 1;
            end if;
            exit when Context.Output_Failed or else (Different and then not List);
         end loop;

         Close_Source (Left);
         Close_Source (Right);
         if Left.Failed or else Right.Failed or else Context.Output_Failed then
            if not Context.Output_Failed then
               Posix_Tools.Commands.Helpers.Operational_Error
                 (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
            end if;
            Result.Status := Posix_Tools.Exit_Status.Cmp_Trouble;
         elsif not Different and then Left.At_End /= Right.At_End then
            if not Silent then
               Posix_Tools.Commands.Helpers.Operational_Error
                 (Context, "posix_tools.cmp.eof", "file",
                  (if Left.At_End then Context.Argument (First) else Context.Argument (First + 1)),
                  "EOF on {file}");
            end if;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         elsif Different then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         else
            Result.Status := Posix_Tools.Exit_Status.Success;
         end if;
      end;
   end Run;
end Posix_Tools.Commands.Cmp;
