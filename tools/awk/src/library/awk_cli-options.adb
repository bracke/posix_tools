package body Awk_CLI.Options is
   package D renames Awk_CLI.Diagnostics;

   function Starts_With (Text, Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Missing (Option : String; Color : Color_Mode := Color_Auto) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.missing_option_argument", D.Error, D.Usage,
                Name => "option", Value => Option, Hint_Id => "awk.hint.use_help"));

   function Missing_Program (Color : Color_Mode := Color_Auto) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.missing_program", D.Error, D.Usage,
                Hint_Id => "awk.hint.use_help"));

   function Invalid_Assignment (Color : Color_Mode; Text : String) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.invalid_assignment", D.Error, D.Usage,
                Name => "assignment", Value => Text,
                Hint_Id => "awk.hint.use_help"));

   function Invalid_Color (Color : Color_Mode; Value : String) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.invalid_color_mode", D.Error, D.Usage,
                Name => "value", Value => Value,
                Hint_Id => "awk.hint.use_help"));

   function Stdin_Program_File (Color : Color_Mode; Option : String) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.program_file_stdin_unsupported", D.Error, D.Usage,
                Name => "option", Value => Option,
                Hint_Id => "awk.hint.option_terminator"));

   function Unknown_Option (Color : Color_Mode; Option : String) return Parse_Result is
     (Ok => False,
      Color => Color,
      Diagnostic =>
        D.Make ("awk.usage.unknown_option", D.Error, D.Usage,
                Name => "option", Value => Option,
                Hint_Id => "awk.hint.use_help"));

   type Handler_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;
         when False =>
            Failure : Parse_Result;
      end case;
   end record;

   function Is_Assignment_Text (Text : String) return Boolean is separate;

   procedure Split_Assignment (Text : String; Name, Value : out U.Unbounded_String) is separate;

   function Handle_Color
     (Result  : in out Parsed_Options;
      Current : String) return Handler_Result is separate;

   function Handle_Field_Separator
     (Result    : in out Parsed_Options;
      Arguments : String_Vectors.Vector;
      Index     : in out Positive) return Handler_Result is separate;

   function Handle_Initial_Assignment
     (Result    : in out Parsed_Options;
      Arguments : String_Vectors.Vector;
      Index     : in out Positive;
      Current   : String) return Handler_Result is separate;

   function Handle_Program_File
     (Result    : in out Parsed_Options;
      Arguments : String_Vectors.Vector;
      Index     : in out Positive;
      Current   : String) return Handler_Result is separate;

   function Parse (Arguments : String_Vectors.Vector) return Parse_Result is separate;

end Awk_CLI.Options;
