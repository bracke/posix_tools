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
