--  Paths and document rendering the tooling driver and its metadata checks
--  share: the project root and every generated file, so that what `docs`
--  writes and what the checks compare against are rendered by one body.
package Tooling_Support is
   function Root return String;
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
