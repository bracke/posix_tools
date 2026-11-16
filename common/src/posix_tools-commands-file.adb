with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Bytes;
with Posix_Tools.Text.File_Descriptions;

package body Posix_Tools.Commands.File is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   package FS renames Posix_Tools.Host_Adapters.File_System;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;
      Mime_Mode  : Boolean := False;
      Magic_Path : Unbounded_String;
      Has_Magic  : Boolean := False;
      Magic_Text : Unbounded_String;
      Magic_Need : Natural := 0;
      Output     : Posix_Tools.Commands.Helpers.Output_Buffer;

      function Description (Path : String) return String;

      function Description (Path : String) return String is
         Read_Ok : Boolean := True;

         function Streamed return String;

         function Streamed return String is
            State : Posix_Tools.Text.File_Descriptions.Classifier;
            Magic_Data : Unbounded_String;

            function Classification_Complete return Boolean is
              (Posix_Tools.Text.File_Descriptions.Classification_Complete (State)
               and then Length (Magic_Data) >= Magic_Need);

            procedure Classify
              (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset);

            procedure Classify
              (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset)
            is
               pragma Unreferenced (Ignored);
            begin
               if Last >= Buffer'First then
                  declare
                     Text : constant String := Posix_Tools.Streams.Bytes.To_String (Buffer, Last);
                     Remaining : constant Natural :=
                       (if Length (Magic_Data) >= Magic_Need then 0
                        else Magic_Need - Length (Magic_Data));
                  begin
                     Posix_Tools.Text.File_Descriptions.Update (State, Text);
                     if Remaining > 0 and then Text'Length > 0 then
                        Append
                          (Magic_Data,
                           Text (Text'First .. Text'First
                             + Natural'Min (Remaining, Text'Length) - 1));
                     end if;
                  end;
               end if;
            end Classify;

            procedure Iterate is new
              Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
                (Action => Classify);
         begin
            Iterate (Context, Path, Read_Ok, Classification_Complete'Access);
            if Read_Ok then
               if Has_Magic then
                  declare
                     Found : Boolean;
                     Text  : constant String :=
                       Posix_Tools.Text.File_Descriptions.Magic_Description
                         (To_String (Magic_Data), Mime_Mode,
                          To_String (Magic_Text), Found);
                  begin
                     if Found then
                        return Text;
                     end if;
                  end;
               end if;
               return Posix_Tools.Text.File_Descriptions.Description (State, Mime_Mode);
            else
               All_Ok := False;
               return "";
            end if;
         end Streamed;
      begin
         if Path = "-" then
            return Streamed;
         end if;

         declare
            Kind : constant FS.File_Kind := FS.Kind (Path);
         begin
            case Kind is
               when FS.Missing_File =>
                  All_Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                  return "";
               when FS.Uninspectable_File =>
                  All_Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                  return "";
               when FS.Directory =>
                  return (if Mime_Mode then "inode/directory" else "directory");
               when FS.Special_File =>
                  return (if Mime_Mode then "application/octet-stream" else "special file");
               when FS.Ordinary_File =>
                  return Streamed;
            end case;
         end;
      exception
         when Ada.IO_Exceptions.Use_Error =>
            All_Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path,
               "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return "";
      end Description;

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
         pragma Unreferenced (Result);
      begin
         Valid := True;
         if Name = 'm' then
            Magic_Path := To_Unbounded_String (Value);
            Has_Magic := True;
         else
            Mime_Mode := True;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options
        (Handle, Long_Options => "--mime --mime-type", Long_Name => 'i');
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "im", "m", First, Valid);
      if not Valid then
         return;
      end if;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      if Has_Magic then
         declare
            Magic_Ok : Boolean;
         begin
            Posix_Tools.Commands.File_Helpers.Streaming.Read_All
              (Context, To_String (Magic_Path), Magic_Text, Magic_Ok);
            if not Magic_Ok then
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
               return;
            end if;
            Magic_Need := Posix_Tools.Text.File_Descriptions.Magic_Prefix_Length
              (To_String (Magic_Text));
         end;
      end if;

      for Index in First .. Context.Argument_Count loop
         declare
            Path : constant String := Context.Argument (Index);
            Text : constant String := Description (Path);
         begin
            if Text /= "" then
               Posix_Tools.Commands.Helpers.Buffered_Put_Line
                 (Output, Context, Path & ": " & Text);
            end if;
         end;
      end loop;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.File;
