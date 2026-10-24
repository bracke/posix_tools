with Ada.Streams;

private with Hostkit.Terminal_Control;

--  The process's terminal, as an interactive full-screen program drives it:
--  raw mode on the way in and back to how it was on the way out, its size in
--  cells, and unbuffered reads and writes on the standard streams.
--
--  Input is read from standard input and output written to standard output;
--  both must be the terminal, which Is_Interactive answers.
package Posix_Tools.Host_Adapters.Terminal_IO is
   use type Ada.Streams.Stream_Element_Offset;

   type Saved_Mode is private;

   --  Whether standard input and standard output are both a terminal.
   function Is_Interactive return Boolean;

   --  Save the terminal's settings into Saved and switch it to raw mode: no
   --  line buffering, no echo, and no interpretation of control keys into
   --  signals. False leaves the terminal as it was and Saved empty.
   function Enter_Raw (Saved : out Saved_Mode) return Boolean;

   --  Put back the settings Enter_Raw saved. Does nothing for an empty Saved,
   --  so it is safe on every exit path, including one where Enter_Raw failed.
   procedure Restore (Saved : Saved_Mode);

   type Window_Size is record
      Rows    : Natural := 0;
      Columns : Natural := 0;
   end record;

   --  The terminal's size in character cells, as the host reports it.
   function Size (Into : out Window_Size) return Boolean;

   type Read_Outcome is (Read_Data, Read_Timeout, Read_End_Of_File, Read_Failed);

   --  Read what standard input has, waiting at most Timeout_Ms for the first
   --  byte; a negative timeout waits for as long as it takes. Last is
   --  Into'First - 1 unless Outcome is Read_Data.
   procedure Read
     (Into       : out Ada.Streams.Stream_Element_Array;
      Last       : out Ada.Streams.Stream_Element_Offset;
      Timeout_Ms : Integer;
      Outcome    : out Read_Outcome)
     with Post => (if Outcome /= Read_Data then Last = Into'First - 1);

   --  Write all of Data to standard output, resuming after short writes and
   --  interruptions. False when the terminal stopped accepting output.
   function Write (Data : String) return Boolean;

private
   type Saved_Mode is record
      Valid : Boolean := False;
      Mode  : Hostkit.Terminal_Control.Mode;
   end record;
end Posix_Tools.Host_Adapters.Terminal_IO;
