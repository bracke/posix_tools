with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Awk_CLI.Environment;
with Awk_CLI.Options;

package Awk_CLI.Platform is
   --  Small host adapter for process, filesystem, terminal, and locale state.
   --
   --  Platform code must stay free of AWK syntax and runtime semantics.

   package U renames Ada.Strings.Unbounded;
   type Read_Status is (Read_Success, Open_Failed, Read_Failed);
   type Input_Stream is limited private;

   --  @return Raw process arguments excluding executable name.
   function Process_Arguments return Awk_CLI.Options.String_Vectors.Vector;

   --  @return Normalized process environment entries.
   function Process_Environment return Awk_CLI.Environment.Entry_Vectors.Vector;

   --  @param Path Host file path to read.
   --  @param Content Complete file text when reading succeeds.
   --  @return Read status distinguishing success, open failure, and read failure.
   function Read_File (Path : String; Content : out U.Unbounded_String) return Read_Status;

   --  @param Path Host file path to open.
   --  @param Stream Stream object receiving the opened input state.
   --  @return Read status for opening the input file.
   function Open_Input_File (Path : String; Stream : in out Input_Stream) return Read_Status;

   --  @param Stream Stream object receiving standard-input state.
   --  @return Read status for preparing standard input.
   function Open_Standard_Input (Stream : in out Input_Stream) return Read_Status;

   --  @param Stream Open input stream to read.
   --  @param Content Text read for this chunk.
   --  @param End_Of_File Whether the stream has reached end-of-file.
   --  @return Read status for the chunk operation.
   function Read_Input_Chunk
     (Stream : in out Input_Stream;
      Content : out U.Unbounded_String;
      End_Of_File : out Boolean) return Read_Status;

   --  @param Stream Input stream to close.
   procedure Close_Input (Stream : in out Input_Stream);

   --  @param Command Host command text requested by awklib.
   --  @param Output Captured command standard output when the command succeeds.
   --  @return True when command execution succeeds.
   --  This is not a system-AWK fallback and must not parse AWK source.
   function Run_Command (Command : String; Output : out U.Unbounded_String) return Boolean;

   --  @param Path Host file path to write.
   --  @param Content Exact bytes to write as Ada string text.
   --  @param Append Whether to append instead of overwriting.
   --  @return True when the write succeeds.
   function Write_File (Path : String; Content : String; Append : Boolean) return Boolean;

   --  @param Content Exact AWK output to write.
   --  @return True when standard-output writing succeeds.
   function Write_Standard_Output (Content : String) return Boolean;

   --  @param Content CLI-owned diagnostic or help text to write.
   --  @return True when standard-error writing succeeds.
   function Write_Standard_Error (Content : String) return Boolean;

   --  @return True when standard output is an interactive terminal.
   function Standard_Output_Is_Terminal return Boolean;

   --  @return True when standard error is an interactive terminal.
   function Standard_Error_Is_Terminal return Boolean;

   --  @return True when host policy disables color output.
   function No_Color_Active return Boolean;

   --  @return Host locale name for CLI-owned text.
   function Locale return String;

   --  @return Best-known message catalog path for the current layout.
   function Catalog_Path return String;

private
   package SIO renames Ada.Streams.Stream_IO;

   type Input_Stream is limited record
      File       : SIO.File_Type;
      Opened     : Boolean := False;
      Is_Stdin   : Boolean := False;
      Stdin_Done : Boolean := False;
   end record;
end Awk_CLI.Platform;
