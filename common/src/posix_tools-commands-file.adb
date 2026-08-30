with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Descriptions;

package body Posix_Tools.Commands.File is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element_Offset;

   package FS renames Posix_Tools.Host_Adapters.File_System;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive := 1;
      All_Ok     : Boolean := True;
      Mime_Mode  : Boolean := False;
      Magic_Path : Unbounded_String;
      Has_Magic  : Boolean := False;

      function Description (Path : String) return String;

      function Content_Description (Data : String) return String is
         Magic_Ok   : Boolean := False;
         Magic_Text : constant String :=
           (if Has_Magic
            then Posix_Tools.Commands.File_Helpers.Read_File
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
            for Index in Buffer'First .. Last loop
               Append (Data, Character'Val (Integer (Buffer (Index))));
            end loop;
         end Collect;

         procedure Read_File_Data is new FS.For_Each_File_Chunk (Collect);
      begin
         if Path = "-" then
            return Content_Description
              (Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));
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
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "-i" or else Arg = "--mime" or else Arg = "--mime-type" then
               Mime_Mode := True;
               First := First + 1;
            elsif Arg = "-m" then
               if First >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '-m'");
                  return;
               end if;
               Magic_Path := To_Unbounded_String (Context.Argument (First + 1));
               Has_Magic := True;
               First := First + 2;
            elsif Arg'Length > 2
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) = 'm'
            then
               Magic_Path := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
               Has_Magic := True;
               First := First + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
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

      Result.Status :=
        (if Context.Output_Failed or else not All_Ok
         then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.File;
