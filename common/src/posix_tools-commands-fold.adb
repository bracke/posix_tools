with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Tab_Stops;

package body Posix_Tools.Commands.Fold is
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Width      : Natural := 80;
      Space_Mode : Boolean := False;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;

      procedure Emit_Folded_Line (Line : String; Had_Newline : Boolean);
      procedure Fold_File (Name : String; Ok : out Boolean);
      procedure Fold_Text (Text : String; Ok : out Boolean);
      procedure Put_LF;
      procedure Reject_Width (Text : String);

      function Valid_Width (Text : String; Value : out Natural) return Boolean;

      procedure Emit_Folded_Line (Line : String; Had_Newline : Boolean) is
         Start : Natural := Line'First;
         Stop  : Natural;
         Break : Natural;

         function Fits_Within_Width (From : Positive) return Boolean;
         function Fold_Stop (From : Positive) return Natural;
         function Next_Line_Column (Index : Positive; Column : Natural; Consumed : out Natural) return Natural;

         function Fits_Within_Width (From : Positive) return Boolean is
            Column      : Natural := 0;
            Consumed    : Natural;
            Next_Column : Natural;
            I           : Positive := From;
         begin
            while I <= Line'Last loop
               Next_Column := Next_Line_Column (I, Column, Consumed);
               if Next_Column > Width then
                  return False;
               end if;
               Column := Next_Column;
               I := I + Consumed;
            end loop;
            return True;
         end Fits_Within_Width;

         function Fold_Stop (From : Positive) return Natural is
            Column      : Natural := 0;
            Consumed    : Natural;
            Next_Column : Natural;
            I           : Positive := From;
            Last_Fit    : Natural := From - 1;
         begin
            while I <= Line'Last loop
               Next_Column := Next_Line_Column (I, Column, Consumed);
               if Next_Column > Width and then Last_Fit >= From then
                  return Last_Fit;
               end if;

               Last_Fit := I + Consumed - 1;
               Column := Next_Column;
               if Next_Column >= Width then
                  return Last_Fit;
               end if;
               I := I + Consumed;
            end loop;

            return Line'Last;
         end Fold_Stop;

         function Next_Line_Column (Index : Positive; Column : Natural; Consumed : out Natural) return Natural is
         begin
            if Line (Index) = HT then
               Consumed := 1;
               return Column + (8 - (Column mod 8));
            else
               return Posix_Tools.Commands.Text_Helpers.Display_Next_Column
                 (Line, Index, Column, Consumed);
            end if;
         end Next_Line_Column;
      begin
         if Line = "" then
            if Had_Newline then
               Put_LF;
            end if;
            return;
         end if;

         while Start <= Line'Last loop
            exit when Fits_Within_Width (Start);

            Stop := Fold_Stop (Start);
            Break := 0;
            if Space_Mode then
               for I in Start .. Stop loop
                  if Line (I) = ' ' or else Line (I) = HT then
                     Break := I;
                  end if;
               end loop;
            end if;

            if Break >= Start then
               Context.Put (Line (Start .. Break));
               Put_LF;
               Start := Break + 1;
            else
               Context.Put (Line (Start .. Stop));
               Put_LF;
               Start := Stop + 1;
            end if;

            exit when Context.Output_Failed;
         end loop;

         if not Context.Output_Failed then
            if Start <= Line'Last then
               Context.Put (Line (Start .. Line'Last));
            end if;
            if Had_Newline then
               Put_LF;
            end if;
         end if;
      end Emit_Folded_Line;

      procedure Fold_File (Name : String; Ok : out Boolean) is
         Data : Unbounded_String;
      begin
         Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
         if Ok then
            Fold_Text (To_String (Data), Ok);
         end if;
      end Fold_File;

      procedure Fold_Text (Text : String; Ok : out Boolean) is
         Start : Natural := Text'First;
      begin
         Ok := True;
         if Text = "" then
            return;
         end if;

         for I in Text'Range loop
            if Text (I) = LF then
               if Start <= I - 1 then
                  Emit_Folded_Line (Text (Start .. I - 1), True);
               else
                  Emit_Folded_Line ("", True);
               end if;
               if Context.Output_Failed then
                  Ok := False;
                  return;
               end if;
               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last then
            Emit_Folded_Line (Text (Start .. Text'Last), False);
         end if;
         Ok := not Context.Output_Failed;
      end Fold_Text;

      procedure Put_LF is
      begin
         Context.Put ("" & LF);
      end Put_LF;

      procedure Reject_Width (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Text & "'");
      end Reject_Width;

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
            elsif Arg = "-b" then
               First_File := First_File + 1;
            elsif Arg = "-s" then
               Space_Mode := True;
               First_File := First_File + 1;
            elsif Arg = "-w" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-w'");
                  return;
               elsif not Valid_Width (Context.Argument (First_File + 1), Width) then
                  Reject_Width (Context.Argument (First_File + 1));
                  return;
               end if;
               First_File := First_File + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'w'
            then
               if not Valid_Width (Arg (Arg'First + 2 .. Arg'Last), Width) then
                  Reject_Width (Arg (Arg'First + 2 .. Arg'Last));
                  return;
               end if;
               First_File := First_File + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

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

      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Fold;
