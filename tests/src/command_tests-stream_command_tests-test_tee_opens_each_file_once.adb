separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Tee_Opens_Each_File_Once (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Context    : Test_Contexts.Capturing_Context;
      Result     : Posix_Tools.Commands.Results.Result;
      FIFO       : constant String := Work_Path ("tee-once.fifo");
      Data       : constant String (1 .. 40_000) := [others => 'x'];
      Read_Total : Natural := 0 with Atomic;
      Removed    : Boolean;

      --  Reads the FIFO to end of file. A writer that closed and reopened it
      --  between chunks would end the reading after the first chunk.
      task type Reader_Task;

      task body Reader_Task is
         use type Ada.Streams.Stream_Element_Offset;
         Input  : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Last   : Ada.Streams.Stream_Element_Offset;
      begin
         if Hostkit.Descriptors.Open_File (FIFO, Hostkit.Descriptors.Open_Read, Input) then
            loop
               case Hostkit.Descriptors.Read (Input, Buffer, Last) is
                  when Hostkit.Descriptors.Transfer_Ok =>
                     Read_Total := Read_Total + Natural (Last - Buffer'First + 1);
                  when Hostkit.Descriptors.Transfer_Interrupted =>
                     null;
                  when others =>
                     exit;
               end case;
            end loop;
            Hostkit.Descriptors.Close (Input);
         end if;
      end Reader_Task;
   begin
      Ada.Directories.Create_Path (Work_Path (""));
      GNAT.OS_Lib.Delete_File (FIFO, Removed);
      if not Hostkit.Fs.Create_FIFO (FIFO, 8#600#) then
         Test_Support.Skip_Without_FIFOs ("tee opens each file once");
         return;
      end if;

      declare
         Reader   : Reader_Task;
         Deadline : constant Ada.Calendar.Time := Ada.Calendar.Clock + 5.0;
         Unblock  : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
      begin
         Context.Initialize ("tee", One_Arg (FIFO));
         Test_Contexts.Set_Standard_Input (Context, Data);
         Posix_Tools.Commands.Tee.Run (Context, Result);
         while not Reader'Terminated and then Ada.Calendar.Clock < Deadline loop
            delay 0.01;
         end loop;
         --  A reader still waiting is released by a writer of our own.
         if not Reader'Terminated
           and then Hostkit.Descriptors.Open_File (FIFO, Hostkit.Descriptors.Open_Write_Append, Unblock)
         then
            Hostkit.Descriptors.Close (Unblock);
         end if;
      end;
      GNAT.OS_Lib.Delete_File (FIFO, Removed);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = Data,
         "tee copies standard input");
      AUnit.Assertions.Assert
        (Read_Total = Data'Length, "tee writes all input through one open of a FIFO");
   end Test_Tee_Opens_Each_File_Once;
