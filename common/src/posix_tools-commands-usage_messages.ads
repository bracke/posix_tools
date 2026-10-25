--  The usage diagnostics a command can report, each a catalog message with
--  at most one placeholder. A command names the diagnostic and hands over
--  the text that fills the placeholder; it never composes the message, so
--  every locale words it its own way and the filled-in text, which comes
--  from the command line, is escaped before it reaches the terminal.
package Posix_Tools.Commands.Usage_Messages is
   type Usage_Message is
     (Count_Overflow,
      Division_By_Zero,
      Extra_Operand,
      Invalid_Argument_Count,
      Invalid_Block_Size,
      Invalid_Byte_Count,
      Invalid_Character_Count,
      Invalid_Command_Size,
      Invalid_Conversion,
      Invalid_Count,
      Invalid_Duration,
      Invalid_Expression,
      Invalid_Field_Count,
      Invalid_Field_Option,
      Invalid_File_Count,
      Invalid_Line_Count,
      Invalid_Mode,
      Invalid_Number,
      Invalid_Operand,
      Invalid_Operand_Count,
      Invalid_Regular_Expression,
      Invalid_Seek,
      Invalid_Skip,
      Invalid_Timestamp,
      Missing_Expression,
      Missing_Expression_Operand,
      Missing_Operand,
      Missing_Option_Argument,
      Missing_Right_Parenthesis,
      Multiple_List_Options,
      Non_Numeric_Arithmetic_Operand,
      Non_Numeric_Substr_Operand,
      Numeric_Overflow,
      Offset_Overflow,
      Unexpected_Right_Parenthesis,
      Unfinished_Escape,
      Unknown_Command,
      Unknown_Operator,
      Unknown_Option,
      Unknown_Subcommand,
      Unmatched_Double_Quote,
      Unmatched_Single_Quote,
      Unsupported_Type);

   --  The catalog key of Message.
   function Key (Message : Usage_Message) return String;

   --  The name of Message's placeholder, or "" when it has none.
   function Placeholder (Message : Usage_Message) return String;

   function Has_Subject (Message : Usage_Message) return Boolean is (Placeholder (Message) /= "");

   --  Message's English text, its placeholder written "{name}": what is
   --  shown when the catalog cannot be read. It matches the catalog's "en"
   --  text.
   function Default (Message : Usage_Message) return String;
end Posix_Tools.Commands.Usage_Messages;
