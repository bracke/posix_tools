with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
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

      function Description (Path : String) return String;

      function Content_Description (Data : String) return String is
         Magic_Ok   : Boolean := False;
         Magic_Text : constant String :=
           (if Has_Magic
            then Posix_Tools.Commands.File_Helpers.Streaming.Read_File
              (Context, To_String (Magic_Path), Magic_Ok)
            else "");
      begin
         return Posix_Tools.Text.File_Descriptions.Content_Description
           (Data       => Data,
            Mime_Mode  => Mime_Mode,
            Magic_Text => Magic_Text,
            Has_Magic  => Has_Magic and then Magic_Ok);
      end Content_Description;

      function Description (Path : String) return String is
         Data    : Unbounded_String;
         Read_Ok : Boolean := True;

         procedure Collect
           (Buffer : Ada.Streams.Stream_Element_Array;
            Last   : Ada.Streams.Stream_Element_Offset;
            Stop   : in out Boolean);

         procedure Collect
           (Buffer : Ada.Streams.Stream_Element_Array;
            Last   : Ada.Streams.Stream_Element_Offset;
            Stop   : in out Boolean)
         is
            pragma Unreferenced (Stop);
         begin
            Append (Data, Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
         end Collect;

         procedure Read_File_Data is new FS.For_Each_File_Chunk (Collect);
      begin
         if Path = "-" then
            declare
               Input : constant String := Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, "-", Read_Ok);
            begin
               if not Read_Ok then
                  All_Ok := False;
                  return "";
               end if;

               return Content_Description (Input);
            end;
         end if;

         case FS.Kind (Path) is
            when FS.Missing_File =>
               All_Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return "";
            when FS.Directory =>
               return (if Mime_Mode then "inode/directory" else "directory");
            when FS.Special_File =>
               return (if Mime_Mode then "application/octet-stream" else "special file");
            when FS.Ordinary_File =>
               Read_File_Data (Path, Read_Ok);
               if not Read_Ok then
                  All_Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
                  return "";
               else
                  return Content_Description (To_String (Data));
               end if;
         end case;
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

      for Index in First .. Context.Argument_Count loop
         declare
            Path : constant String := Context.Argument (Index);
            Text : constant String := Description (Path);
         begin
            if Text /= "" then
               Context.Put_Line (Path & ": " & Text);
            end if;
         end;
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.File;
