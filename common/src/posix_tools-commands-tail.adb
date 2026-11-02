with Posix_Tools.Commands.File_Helpers.Tailing;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Tail_Bytes;
with Posix_Tools.Commands.Tail_Follow;
with Posix_Tools.Numbers;
with Posix_Tools.Tail_Counts;

package body Posix_Tools.Commands.Tail is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Posix_Tools.Commands.Tail_Follow.Follow_Mode;
   use type Posix_Tools.Numbers.Parse_Status;
   use type Posix_Tools.Tail_Counts.Count_Origin;

   type Mode is (Line_Mode, Byte_Mode);
   subtype Count_Origin is Posix_Tools.Tail_Counts.Count_Origin;
   From_End : constant Count_Origin := Posix_Tools.Tail_Counts.From_End;
   From_Start : constant Count_Origin := Posix_Tools.Tail_Counts.From_Start;
   subtype Follow_Mode is Posix_Tools.Commands.Tail_Follow.Follow_Mode;
   No_Follow : constant Follow_Mode := Posix_Tools.Commands.Tail_Follow.No_Follow;
   Follow_Descriptor : constant Follow_Mode := Posix_Tools.Commands.Tail_Follow.Follow_Descriptor;
   Follow_Name : constant Follow_Mode := Posix_Tools.Commands.Tail_Follow.Follow_Name;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First_File : Positive;
      Count      : constant Natural := Context.Argument_Count;
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Sources    : Natural;
      Current_Mode : Mode := Line_Mode;
      Requested  : Posix_Tools.Numbers.Count := 10;
      Origin     : Count_Origin := From_End;
      Follow     : Follow_Mode := No_Follow;
      Valid      : Boolean;

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
      begin
         Valid := True;
         case Name is
            when 'f' => Follow := Follow_Descriptor;
            when 'F' => Follow := Follow_Name;
            when others =>
               Current_Mode := (if Name = 'c' then Byte_Mode else Line_Mode);
               declare
                  Parsed : constant Posix_Tools.Tail_Counts.Parsed_Count :=
                    Posix_Tools.Tail_Counts.Parse_Count (Value);
               begin
                  Requested := Parsed.Value;
                  Origin := Parsed.Origin;
                  if Parsed.Status /= Posix_Tools.Numbers.Valid then
                     --  The count as given: its own argument, or attached
                     --  to its option.
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, Invalid_Count,
                        (if (for some I in 1 .. Count => Context.Argument (I) = Value) then Value
                         else "-" & Name & Value));
                     Valid := False;
                  end if;
               end;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options
        (Handle, Long_Options => "--follow", Long_Name => 'F');
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "cfFn", "cn", First_File, Valid);
      if not Valid then
         return;
      end if;

      Sources := (if First_File > Count then 1 else Count - First_File + 1);
      if First_File > Count then
         if Current_Mode = Byte_Mode then
            Posix_Tools.Commands.Tail_Bytes.Copy (Context, "-", Requested, Origin, Ok);
         elsif Origin = From_Start then
            Posix_Tools.Commands.File_Helpers.Tailing.Copy_Lines_From (Context, "-", Requested, Ok);
         else
            Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix (Context, "-", Requested, Ok);
         end if;
         All_Ok := Ok;
      else
         declare
            procedure Emit_Header (File_Index : Positive) is
            begin
               Context.Put_Line ("==> " & Context.Argument (File_Index) & " <==");
            end Emit_Header;
         begin
            for I in First_File .. Count loop
               if Sources > 1 then
                  if I > First_File then
                     Context.Put_Line ("");
                     if Context.Output_Failed then
                        All_Ok := False;
                        exit;
                     end if;
                  end if;
                  Emit_Header (I);
                  if Context.Output_Failed then
                     All_Ok := False;
                     exit;
                  end if;
               end if;

               if Current_Mode = Byte_Mode then
                  Posix_Tools.Commands.Tail_Bytes.Copy
                    (Context, Context.Argument (I), Requested, Origin, Ok);
               elsif Origin = From_Start then
                  Posix_Tools.Commands.File_Helpers.Tailing.Copy_Lines_From
                    (Context, Context.Argument (I), Requested, Ok);
               else
                  Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix
                    (Context, Context.Argument (I), Requested, Ok);
               end if;
               All_Ok := All_Ok and Ok;
            end loop;
         end;
      end if;

      if Follow /= No_Follow and then All_Ok and then not Context.Output_Failed then
         if First_File <= Count then
            Posix_Tools.Commands.Tail_Follow.Follow_File_Operands
              (Context, First_File, Count, Sources, Follow, All_Ok);
         else
            Posix_Tools.Commands.Tail_Follow.Follow_Standard_Input (Context, All_Ok);
         end if;
      end if;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Tail;
