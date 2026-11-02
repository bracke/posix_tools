with Project_Tools.Processes;

--  Paths and document rendering the tooling driver and its metadata checks
--  share: the project root and every generated file, so that what `docs`
--  writes and what the checks compare against are rendered by one body.
package Tooling_Support is
   function Root return String;

   --  Where the build put an executable: Base_Path, or Base_Path with
   --  ".exe", as a full name; Base_Path itself when neither exists.
   function Built_Path (Base_Path : String) return String;
   function Built_Command_Path (Executable : String) return String;
   function Built_Root_Path return String;
   function Built_Test_Runner_Path return String;
   --  The source archive a package or release makes, relative to Root.
   function Release_Archive_Path return String;

   --  Program run from Root with Args, Input on its standard input and
   --  its standard output captured, its standard error too with
   --  Err_To_Out. A run still going after Timeout seconds is killed:
   --  Timed_Out says so. Started is False when it could not be started,
   --  and Status is then 127.
   procedure Run_Within
     (Program    : String;
      Args       : Project_Tools.Processes.Argument_Vectors.Vector;
      Timeout    : Duration;
      Result     : out Project_Tools.Processes.Captured_Process;
      Started    : out Boolean;
      Timed_Out  : out Boolean;
      Input      : String := "";
      Err_To_Out : Boolean := False);

   --  Run_Within for a check: a run that cannot start or does not finish
   --  in time fails the check, naming Label.
   function Capture_Within
     (Label      : String;
      Program    : String;
      Args       : Project_Tools.Processes.Argument_Vectors.Vector;
      Input      : String := "";
      Err_To_Out : Boolean := False;
      Timeout    : Duration := 120.0) return Project_Tools.Processes.Captured_Process;

   --  Text with its line feeds, carriage returns and tabs escaped, for a
   --  diagnostic that quotes a program's output.
   function Display_Output (Text : String) return String;
   function Boolean_Text (Value : Boolean) return String;
   --  generated/command_inventory.csv from the compiled inventory.
   function Command_Inventory_Csv return String;
   --  generated/manual-index.md.
   function Manual_Index return String;
   --  docs/commands/index.md.
   function Command_Reference_Index return String;
   function Strip_Markdown_Ticks (Text : String) return String;
   function Trim_Blank_Lines (Text : String) return String;
   function Markdown_Section (Document : String; Heading : String) return String;
   function Roff_Text (Text : String) return String;
   function Command_Manpage (Index : Positive) return String;
   function Root_Manpage return String;
end Tooling_Support;
