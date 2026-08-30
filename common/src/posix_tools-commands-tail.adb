with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Tail_Bytes;
with Posix_Tools.Commands.Tail_Follow;
with Posix_Tools.Exit_Status;
with Posix_Tools.Numbers;
with Posix_Tools.Tail_Counts;

package body Posix_Tools.Commands.Tail is
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
      First_File : Positive := 1;
      Count      : constant Natural := Context.Argument_Count;
      Parsed_Status : Posix_Tools.Numbers.Parse_Status;
      Ok         : Boolean;
      All_Ok     : Boolean := True;
      Sources    : Natural;
      Current_Mode : Mode := Line_Mode;
      Requested  : Posix_Tools.Numbers.Count := 10;
      Origin     : Count_Origin := From_End;
      Follow     : Follow_Mode := No_Follow;
      Index      : Positive := 1;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while Index <= Count loop
         if Context.Argument (Index) = "--" then
            Index := Index + 1;
            exit;
         elsif Context.Argument (Index) = "-f"
           or else Context.Argument (Index) = "-F"
           or else Context.Argument (Index) = "--follow"
         then
            Follow := (if Context.Argument (Index) = "-f" then Follow_Descriptor else Follow_Name);
            Index := Index + 1;
         elsif Context.Argument (Index) = "-n" or else Context.Argument (Index) = "-c" then
            if Index = Count then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "missing option argument '" & Context.Argument (Index) & "'");
               return;
            end if;

            Current_Mode := (if Context.Argument (Index) = "-c" then Byte_Mode else Line_Mode);
            declare
               Parsed : constant Posix_Tools.Tail_Counts.Parsed_Count :=
                 Posix_Tools.Tail_Counts.Parse_Count (Context.Argument (Index + 1));
            begin
               Parsed_Status := Parsed.Status;
               Requested := Parsed.Value;
               Origin := Parsed.Origin;
            end;
            if Parsed_Status /= Posix_Tools.Numbers.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid count '" & Context.Argument (Index + 1) & "'");
               return;
            end if;
            Index := Index + 2;
         elsif Context.Argument (Index)'Length > 2
           and then Context.Argument (Index) (1) = '-'
           and then (Context.Argument (Index) (2) = 'n' or else Context.Argument (Index) (2) = 'c')
         then
            Current_Mode := (if Context.Argument (Index) (2) = 'c' then Byte_Mode else Line_Mode);
            declare
               Parsed : constant Posix_Tools.Tail_Counts.Parsed_Count :=
                 Posix_Tools.Tail_Counts.Parse_Count
                   (Context.Argument (Index) (3 .. Context.Argument (Index)'Last));
            begin
               Parsed_Status := Parsed.Status;
               Requested := Parsed.Value;
               Origin := Parsed.Origin;
            end;
            if Parsed_Status /= Posix_Tools.Numbers.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid count '" & Context.Argument (Index) & "'");
               return;
            end if;
            Index := Index + 1;
         elsif Context.Argument (Index)'Length > 1
           and then Context.Argument (Index) (1) = '-'
         then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "unknown option '" & Context.Argument (Index) & "'");
            return;
         else
            exit;
         end if;
      end loop;
      First_File := Index;

      Sources := (if First_File > Count then 1 else Count - First_File + 1);
      if First_File > Count then
         if Current_Mode = Byte_Mode then
            Posix_Tools.Commands.Tail_Bytes.Copy (Context, "-", Requested, Origin, Ok);
         elsif Origin = From_Start then
            Posix_Tools.Commands.File_Helpers.Copy_Lines_From (Context, "-", Requested, Ok);
         else
            Posix_Tools.Commands.File_Helpers.Copy_Line_Suffix (Context, "-", Requested, Ok);
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
                  Posix_Tools.Commands.File_Helpers.Copy_Lines_From
                    (Context, Context.Argument (I), Requested, Ok);
               else
                  Posix_Tools.Commands.File_Helpers.Copy_Line_Suffix
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

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Tail;
