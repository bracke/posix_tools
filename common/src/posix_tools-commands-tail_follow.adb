with Ada.Streams;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Tail_Follow is
   use type Ada.Streams.Stream_Element_Offset;
   procedure Copy_Follow_File
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      File      : in out Posix_Tools.Host_Adapters.File_System.Follow_File;
      Header    : Boolean;
      Produced  : out Boolean;
      Ok        : out Boolean)
   is
      Started : Boolean := False;

      procedure Copy_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
      begin
         if Last >= Buffer'First then
            if Header and then not Started then
               Context.Put_Line ("");
               if not Context.Output_Failed then
                  Context.Put_Line ("==> " & File_Name & " <==");
               end if;
            end if;
            Started := True;
            if not Context.Output_Failed then
               Context.Put_Bytes (Buffer, Last);
            end if;
         end if;
      end Copy_Chunk;

      procedure Iterate is new
        Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Follow_Chunk
        (Action => Copy_Chunk);
   begin
      Iterate (Context, File_Name, File, Ok);
      Produced := Started;
   end Copy_Follow_File;

   procedure Follow_File_Operands
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      First_File  : Positive;
      Last_File   : Natural;
      Sources     : Natural;
      Follow      : Follow_Mode;
      Files       : in out Follow_File_Array;
      Eligible    : in out Follow_Eligibility_Array;
      All_Ok      : in out Boolean)
   is
      Polls   : Natural := 0;
      Limit   : constant Natural := Context.Tail_Follow_Poll_Limit;
      Ok      : Boolean;
      Produced : Boolean;
      Last_Emitting_Operand : Natural := 0;
      Reported_Error : array (First_File .. Last_File) of Boolean :=
        (others => False);

      function Any_Eligible return Boolean is
      begin
         return (for some Item of Eligible => Item);
      end Any_Eligible;
   begin
      loop
         exit when not Any_Eligible
           or else (Limit /= 0 and then Polls >= Limit);
         Context.Tail_Follow_Wait;
         Polls := Polls + 1;

         for I in First_File .. Last_File loop
            exit when Context.Output_Failed;
            if not Eligible (I) then
               goto Continue_Operand;
            elsif Context.Argument (I) = "-" then
               Posix_Tools.Commands.File_Helpers.Streaming.Copy_Standard_Input (Context, Ok);
               All_Ok := All_Ok and Ok;
               if not Ok then
                  Eligible (I) := False;
               end if;
            else
               if Follow = Follow_Name then
                  declare
                     Reopened : Boolean;
                     Status   : Posix_Tools.Host_Adapters.File_System.Follow_Open_Status;
                  begin
                     Posix_Tools.Host_Adapters.File_System.Refresh_Follow_File
                       (Context.Argument (I), Files (I), Reopened, Status);
                     case Status is
                        when Posix_Tools.Host_Adapters.File_System.Follow_Missing =>
                           goto Continue_Operand;
                        when Posix_Tools.Host_Adapters.File_System.Follow_Error =>
                           All_Ok := False;
                           if not Reported_Error (I) then
                              Posix_Tools.Commands.Helpers.Subject_Operational_Error
                                (Context,
                                 Context.Argument (I),
                                 "posix_tools.diagnostic.file.read_failed",
                                 "cannot read file");
                              Reported_Error (I) := True;
                           end if;
                           goto Continue_Operand;
                        when Posix_Tools.Host_Adapters.File_System.Follow_Ready =>
                           Reported_Error (I) := False;
                     end case;
                  end;
               elsif not Posix_Tools.Host_Adapters.File_System.Follow_File_Is_Open
                 (Files (I))
               then
                  goto Continue_Operand;
               end if;

               Copy_Follow_File
                 (Context,
                  Context.Argument (I),
                  Files (I),
                  Header => Sources > 1 and then Last_Emitting_Operand /= I,
                  Produced => Produced,
                  Ok     => Ok);
               if Produced and then not Context.Output_Failed then
                  Last_Emitting_Operand := I;
               end if;
               All_Ok := All_Ok and Ok;
               if not Ok then
                  Posix_Tools.Host_Adapters.File_System.Close_Follow_File
                    (Files (I));
                  Eligible (I) := Follow = Follow_Name;
               end if;
            end if;
            <<Continue_Operand>>
            null;
         end loop;

         exit when Context.Output_Failed;
      end loop;

      if Context.Output_Failed then
         All_Ok := False;
      end if;
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
         Posix_Tools.Commands.File_Helpers.Streaming.Copy_Standard_Input (Context, Ok);
         All_Ok := All_Ok and Ok;
         exit when Context.Output_Failed or else not Ok;
      end loop;
   end Follow_Standard_Input;
end Posix_Tools.Commands.Tail_Follow;
