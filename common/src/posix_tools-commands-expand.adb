with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.Tab_Stops;

package body Posix_Tools.Commands.Expand is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Tab_Config : Posix_Tools.Commands.Text_Helpers.Tab_Stops.Configuration;
      First_File : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;

      procedure Expand_File (Name : String; Ok : out Boolean);
      procedure Expand_Text (Text : String; Ok : out Boolean);

      procedure Expand_File (Name : String; Ok : out Boolean) is
         Data : Unbounded_String;
      begin
         Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Name, Data, Ok);
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
                          Posix_Tools.Commands.Text_Helpers.Display.Display_Next_Column
                            (Text, I, Column, Consumed);
                     begin
                        if Consumed > 1 then
                           Context.Put (Text (I + 1 .. I + Consumed - 1));
                        end if;
                        Column := Next_Column;
                     end;
                  else
                     Column :=
                       Posix_Tools.Commands.Text_Helpers.Display.Display_Next_Column
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
         pragma Unreferenced (Name);
      begin
         Valid := True;
         if not Posix_Tools.Commands.Text_Helpers.Tab_Stops.Parse (Tab_Config, Value) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
            Valid := False;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "t", "t", First_File, Valid);
      if not Valid then
         return;
      end if;

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

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Expand;
