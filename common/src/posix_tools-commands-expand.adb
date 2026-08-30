with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Commands.Text_Helpers.Tab_Stops;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Expand is
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Tab_Config : Posix_Tools.Commands.Text_Helpers.Tab_Stops.Configuration;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;

      procedure Expand_File (Name : String; Ok : out Boolean);
      procedure Expand_Text (Text : String; Ok : out Boolean);

      procedure Expand_File (Name : String; Ok : out Boolean) is
         Data : Unbounded_String;
      begin
         Posix_Tools.Commands.File_Helpers.Read_All (Context, Name, Data, Ok);
         if Ok then
            Expand_Text (To_String (Data), Ok);
         end if;
      end Expand_File;

      procedure Expand_Text (Text : String; Ok : out Boolean) is
         Column   : Natural := 0;
         Spaces   : Natural;
         Consumed : Natural;
         I        : Positive := Text'First;
      begin
         Ok := True;
         if Text = "" then
            return;
         end if;

         while I <= Text'Last loop
            if Text (I) = HT then
               Spaces :=
                 Posix_Tools.Commands.Text_Helpers.Tab_Stops.Next_Column
                   (Tab_Config, Column) - Column;
               for Count in 1 .. Spaces loop
                  Context.Put (" ");
                  exit when Context.Output_Failed;
               end loop;
               Column := Column + Spaces;
               I := I + 1;
            else
               Consumed := 1;
               Context.Put (Text (I .. I));
               if Text (I) = LF then
                  Column := 0;
                  I := I + 1;
               else
                  if Character'Pos (Text (I)) > 16#7F# then
                     declare
                        Next_Column : constant Natural :=
                          Posix_Tools.Commands.Text_Helpers.Display_Next_Column
                            (Text, I, Column, Consumed);
                     begin
                        if Consumed > 1 then
                           Context.Put (Text (I + 1 .. I + Consumed - 1));
                        end if;
                        Column := Next_Column;
                     end;
                  else
                     Column :=
                       Posix_Tools.Commands.Text_Helpers.Display_Next_Column
                         (Text, I, Column, Consumed);
                  end if;
                  I := I + Consumed;
               end if;
            end if;

            if Context.Output_Failed then
               Ok := False;
               return;
            end if;
         end loop;
      end Expand_Text;
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
            elsif Arg = "-t" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-t'");
                  return;
               elsif not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse
                 (Tab_Config, Context.Argument (First_File + 1))
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First_File + 1) & "'");
                  return;
               end if;
               First_File := First_File + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 't'
            then
               if not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse
                 (Tab_Config, Arg (Arg'First + 2 .. Arg'Last))
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Arg (Arg'First + 2 .. Arg'Last) & "'");
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

      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Expand;
