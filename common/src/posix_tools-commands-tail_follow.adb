with Ada.Streams;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Tail_Follow is
   use type Ada.Streams.Stream_Element_Offset;

   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   is
      Result : String (1 .. Natural (Integer (Last) - Integer (Buffer'First) + 1));
      Target : Positive := Result'First;
   begin
      for I in Buffer'First .. Last loop
         Result (Target) := Character'Val (Integer (Buffer (I)));
         Target := Target + 1;
      end loop;

      return Result;
   end To_String;

   procedure Copy_File_From_Offset
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Offset    : Long_Long_Integer;
      Ok        : out Boolean)
   is
      procedure Copy_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         if Last >= Buffer'First then
            Context.Put (To_String (Buffer, Last));
            Stop := Context.Output_Failed;
         end if;
      end Copy_Chunk;

      procedure Iterate is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk_From
        (Action => Copy_Chunk);
   begin
      Iterate (File_Name, Offset, Ok);
      if Ok then
         Ok := not Context.Output_Failed;
      else
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, File_Name, "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
   end Copy_File_From_Offset;

   procedure Follow_File_Operands
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      First_File  : Positive;
      Last_File   : Natural;
      Sources     : Natural;
      Follow      : Follow_Mode;
      All_Ok      : in out Boolean)
   is
      type Offset_Array is array (Positive range <>) of Long_Long_Integer;
      Offsets : Offset_Array (First_File .. Last_File);
      Polls   : Natural := 0;
      Limit   : constant Natural := Context.Tail_Follow_Poll_Limit;
      Ok      : Boolean;
      Use_Watch : constant Boolean :=
        Sources = 1 and then First_File = Last_File and then Context.Argument (First_File) /= "-";

      procedure Emit_Header (File_Index : Positive) is
      begin
         if Sources > 1 then
            Context.Put_Line ("");
            if not Context.Output_Failed then
               Context.Put_Line ("==> " & Context.Argument (File_Index) & " <==");
            end if;
         end if;
      end Emit_Header;
   begin
      if Use_Watch then
         Context.Tail_Follow_Watch_Path (Context.Argument (First_File));
      end if;

      for I in First_File .. Last_File loop
         if Context.Argument (I) = "-" then
            Offsets (I) := 0;
         else
            Offsets (I) := Posix_Tools.Host_Adapters.File_System.Size (Context.Argument (I));
            if Offsets (I) < 0 then
               Offsets (I) := 0;
            end if;
         end if;
      end loop;

      loop
         exit when Limit /= 0 and then Polls >= Limit;
         Context.Tail_Follow_Wait;
         Polls := Polls + 1;

         if Use_Watch
           and then Context.Tail_Follow_Watch_Active
           and then not Context.Tail_Follow_Watch_Changed
         then
            goto Continue_Follow;
         end if;

         for I in First_File .. Last_File loop
            exit when Context.Output_Failed;
            if Context.Argument (I) = "-" then
               Posix_Tools.Commands.File_Helpers.Copy_Standard_Input (Context, Ok);
               All_Ok := All_Ok and Ok;
            else
               declare
                  Current_Size : constant Long_Long_Integer :=
                    Posix_Tools.Host_Adapters.File_System.Size (Context.Argument (I));
               begin
                  if Current_Size < 0 then
                     if Follow = Follow_Descriptor then
                        All_Ok := False;
                        Posix_Tools.Commands.Helpers.Subject_Operational_Error
                          (Context,
                           Context.Argument (I),
                           "posix_tools.diagnostic.file.read_failed",
                           "cannot read file");
                        return;
                     end if;
                  elsif Current_Size < Offsets (I) then
                     if Follow = Follow_Name then
                        if Sources > 1 then
                           Emit_Header (I);
                        end if;
                        Copy_File_From_Offset (Context, Context.Argument (I), 0, Ok);
                        All_Ok := All_Ok and Ok;
                        Offsets (I) := Current_Size;
                     else
                        Offsets (I) := Current_Size;
                     end if;
                  elsif Current_Size > Offsets (I) then
                     if Sources > 1 then
                        Emit_Header (I);
                     end if;
                     Copy_File_From_Offset (Context, Context.Argument (I), Offsets (I), Ok);
                     All_Ok := All_Ok and Ok;
                     Offsets (I) := Current_Size;
                  end if;
               end;
            end if;
         end loop;

         exit when Context.Output_Failed;
         <<Continue_Follow>>
         null;
      end loop;

      if Use_Watch then
         Context.Tail_Follow_Release_Watch;
      end if;

      if Context.Output_Failed then
         All_Ok := False;
      end if;
   exception
      when others =>
         if Use_Watch then
            Context.Tail_Follow_Release_Watch;
         end if;
         raise;
   end Follow_File_Operands;

   procedure Follow_Standard_Input
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      All_Ok  : in out Boolean)
   is
      Polls : Natural := 0;
      Limit : constant Natural := Context.Tail_Follow_Poll_Limit;
      Ok    : Boolean;
   begin
      loop
         exit when Limit /= 0 and then Polls >= Limit;
         Context.Tail_Follow_Wait;
         Polls := Polls + 1;
         Posix_Tools.Commands.File_Helpers.Copy_Standard_Input (Context, Ok);
         All_Ok := All_Ok and Ok;
         exit when Context.Output_Failed or else not Ok;
      end loop;
   end Follow_Standard_Input;
end Posix_Tools.Commands.Tail_Follow;
