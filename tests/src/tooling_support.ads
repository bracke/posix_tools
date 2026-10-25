--  Paths and document rendering the tooling driver and its metadata checks
--  share: the project root and the generated man pages they compare against.
package Tooling_Support is
   function Root return String;
   function Strip_Markdown_Ticks (Text : String) return String;
   function Trim_Blank_Lines (Text : String) return String;
   function Markdown_Section (Document : String; Heading : String) return String;
   function Roff_Text (Text : String) return String;
   function Command_Manpage (Index : Positive) return String;
   function Root_Manpage return String;
end Tooling_Support;
