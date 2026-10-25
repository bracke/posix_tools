package body Posix_Tools.Commands.Usage_Messages is
   function Default (Message : Usage_Message) return String is
   begin
      case Message is
         when Count_Overflow =>
            return "count overflow";
         when Division_By_Zero =>
            return "division by zero";
         when Extra_Operand =>
            return "extra operand '{operand}'";
         when Invalid_Argument_Count =>
            return "invalid argument count '{count}'";
         when Invalid_Block_Size =>
            return "invalid block size '{size}'";
         when Invalid_Byte_Count =>
            return "invalid byte count '{count}'";
         when Invalid_Character_Count =>
            return "invalid character count '{count}'";
         when Invalid_Command_Size =>
            return "invalid command size '{size}'";
         when Invalid_Conversion =>
            return "invalid conversion '{conversion}'";
         when Invalid_Count =>
            return "invalid count '{count}'";
         when Invalid_Duration =>
            return "invalid duration '{duration}'";
         when Invalid_Expression =>
            return "invalid expression";
         when Invalid_Field_Count =>
            return "invalid field count '{count}'";
         when Invalid_Field_Option =>
            return "invalid field option";
         when Invalid_File_Count =>
            return "invalid file count '{count}'";
         when Invalid_Line_Count =>
            return "invalid line count '{count}'";
         when Invalid_Mode =>
            return "invalid mode '{mode}'";
         when Invalid_Number =>
            return "invalid number";
         when Invalid_Operand =>
            return "invalid operand '{operand}'";
         when Invalid_Operand_Count =>
            return "invalid operand count";
         when Invalid_Regular_Expression =>
            return "invalid regular expression '{pattern}'";
         when Invalid_Seek =>
            return "invalid seek '{count}'";
         when Invalid_Skip =>
            return "invalid skip '{count}'";
         when Invalid_Timestamp =>
            return "invalid timestamp '{timestamp}'";
         when Missing_Expression =>
            return "missing expression";
         when Missing_Expression_Operand =>
            return "missing expression operand";
         when Missing_Operand =>
            return "missing operand";
         when Missing_Option_Argument =>
            return "missing option argument '{option}'";
         when Missing_Right_Parenthesis =>
            return "missing ')' in expression";
         when Multiple_List_Options =>
            return "multiple list options";
         when Non_Numeric_Arithmetic_Operand =>
            return "non-numeric arithmetic operand";
         when Non_Numeric_Substr_Operand =>
            return "non-numeric substr operand";
         when Numeric_Overflow =>
            return "numeric overflow";
         when Offset_Overflow =>
            return "offset overflow";
         when Unexpected_Right_Parenthesis =>
            return "unexpected ')' in expression";
         when Unfinished_Escape =>
            return "unfinished escape";
         when Unknown_Command =>
            return "unknown command '{command}'";
         when Unknown_Operator =>
            return "unknown operator '{operator}'";
         when Unknown_Option =>
            return "unknown option '{option}'";
         when Unknown_Subcommand =>
            return "unknown subcommand '{subcommand}'";
         when Unmatched_Double_Quote =>
            return "unmatched double quote";
         when Unmatched_Single_Quote =>
            return "unmatched single quote";
         when Unsupported_Type =>
            return "unsupported type '{type}'";
      end case;
   end Default;

   function Key (Message : Usage_Message) return String is
   begin
      case Message is
         when Count_Overflow =>
            return "posix_tools.diagnostic.dd.count_overflow";
         when Division_By_Zero =>
            return "posix_tools.diagnostic.expr.division_by_zero";
         when Extra_Operand =>
            return "posix_tools.diagnostic.extra_operand";
         when Invalid_Argument_Count =>
            return "posix_tools.diagnostic.argument_count.invalid";
         when Invalid_Block_Size =>
            return "posix_tools.diagnostic.block_size.invalid";
         when Invalid_Byte_Count =>
            return "posix_tools.diagnostic.byte_count.invalid";
         when Invalid_Character_Count =>
            return "posix_tools.diagnostic.character_count.invalid";
         when Invalid_Command_Size =>
            return "posix_tools.diagnostic.command_size.invalid";
         when Invalid_Conversion =>
            return "posix_tools.diagnostic.conversion.invalid";
         when Invalid_Count =>
            return "posix_tools.diagnostic.count.invalid";
         when Invalid_Duration =>
            return "posix_tools.diagnostic.duration.invalid";
         when Invalid_Expression =>
            return "posix_tools.diagnostic.expression.invalid";
         when Invalid_Field_Count =>
            return "posix_tools.diagnostic.field_count.invalid";
         when Invalid_Field_Option =>
            return "posix_tools.diagnostic.cut.field_option";
         when Invalid_File_Count =>
            return "posix_tools.diagnostic.file_count.invalid";
         when Invalid_Line_Count =>
            return "posix_tools.diagnostic.line_count.invalid";
         when Invalid_Mode =>
            return "posix_tools.diagnostic.mode.invalid";
         when Invalid_Number =>
            return "posix_tools.diagnostic.number.invalid";
         when Invalid_Operand =>
            return "posix_tools.diagnostic.operand.invalid";
         when Invalid_Operand_Count =>
            return "posix_tools.diagnostic.operand_count.invalid";
         when Invalid_Regular_Expression =>
            return "posix_tools.diagnostic.expr.regular_expression.invalid";
         when Invalid_Seek =>
            return "posix_tools.diagnostic.dd.seek.invalid";
         when Invalid_Skip =>
            return "posix_tools.diagnostic.dd.skip.invalid";
         when Invalid_Timestamp =>
            return "posix_tools.diagnostic.timestamp.invalid";
         when Missing_Expression =>
            return "posix_tools.diagnostic.expr.expression.missing";
         when Missing_Expression_Operand =>
            return "posix_tools.diagnostic.expr.operand.missing";
         when Missing_Operand =>
            return "posix_tools.diagnostic.missing_operand";
         when Missing_Option_Argument =>
            return "posix_tools.diagnostic.missing_option_argument";
         when Missing_Right_Parenthesis =>
            return "posix_tools.diagnostic.expr.right_parenthesis.missing";
         when Multiple_List_Options =>
            return "posix_tools.diagnostic.cut.multiple_lists";
         when Non_Numeric_Arithmetic_Operand =>
            return "posix_tools.diagnostic.expr.arithmetic_operand.non_numeric";
         when Non_Numeric_Substr_Operand =>
            return "posix_tools.diagnostic.expr.substr_operand.non_numeric";
         when Numeric_Overflow =>
            return "posix_tools.diagnostic.expr.numeric_overflow";
         when Offset_Overflow =>
            return "posix_tools.diagnostic.dd.offset_overflow";
         when Unexpected_Right_Parenthesis =>
            return "posix_tools.diagnostic.expr.right_parenthesis.unexpected";
         when Unfinished_Escape =>
            return "posix_tools.diagnostic.xargs.escape.unfinished";
         when Unknown_Command =>
            return "posix_tools.diagnostic.command.unknown";
         when Unknown_Operator =>
            return "posix_tools.diagnostic.test.operator.unknown";
         when Unknown_Option =>
            return "posix_tools.diagnostic.option.unknown";
         when Unknown_Subcommand =>
            return "posix_tools.diagnostic.subcommand.unknown";
         when Unmatched_Double_Quote =>
            return "posix_tools.diagnostic.xargs.double_quote.unmatched";
         when Unmatched_Single_Quote =>
            return "posix_tools.diagnostic.xargs.single_quote.unmatched";
         when Unsupported_Type =>
            return "posix_tools.diagnostic.find.type.unsupported";
      end case;
   end Key;

   function Placeholder (Message : Usage_Message) return String is
   begin
      case Message is
         when Count_Overflow =>
            return "";
         when Division_By_Zero =>
            return "";
         when Extra_Operand =>
            return "operand";
         when Invalid_Argument_Count =>
            return "count";
         when Invalid_Block_Size =>
            return "size";
         when Invalid_Byte_Count =>
            return "count";
         when Invalid_Character_Count =>
            return "count";
         when Invalid_Command_Size =>
            return "size";
         when Invalid_Conversion =>
            return "conversion";
         when Invalid_Count =>
            return "count";
         when Invalid_Duration =>
            return "duration";
         when Invalid_Expression =>
            return "";
         when Invalid_Field_Count =>
            return "count";
         when Invalid_Field_Option =>
            return "";
         when Invalid_File_Count =>
            return "count";
         when Invalid_Line_Count =>
            return "count";
         when Invalid_Mode =>
            return "mode";
         when Invalid_Number =>
            return "";
         when Invalid_Operand =>
            return "operand";
         when Invalid_Operand_Count =>
            return "";
         when Invalid_Regular_Expression =>
            return "pattern";
         when Invalid_Seek =>
            return "count";
         when Invalid_Skip =>
            return "count";
         when Invalid_Timestamp =>
            return "timestamp";
         when Missing_Expression =>
            return "";
         when Missing_Expression_Operand =>
            return "";
         when Missing_Operand =>
            return "";
         when Missing_Option_Argument =>
            return "option";
         when Missing_Right_Parenthesis =>
            return "";
         when Multiple_List_Options =>
            return "";
         when Non_Numeric_Arithmetic_Operand =>
            return "";
         when Non_Numeric_Substr_Operand =>
            return "";
         when Numeric_Overflow =>
            return "";
         when Offset_Overflow =>
            return "";
         when Unexpected_Right_Parenthesis =>
            return "";
         when Unfinished_Escape =>
            return "";
         when Unknown_Command =>
            return "command";
         when Unknown_Operator =>
            return "operator";
         when Unknown_Option =>
            return "option";
         when Unknown_Subcommand =>
            return "subcommand";
         when Unmatched_Double_Quote =>
            return "";
         when Unmatched_Single_Quote =>
            return "";
         when Unsupported_Type =>
            return "type";
      end case;
   end Placeholder;
end Posix_Tools.Commands.Usage_Messages;
