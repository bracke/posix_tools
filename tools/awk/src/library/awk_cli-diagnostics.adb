with Ada.Characters.Latin_1;

package body Awk_CLI.Diagnostics is
   function Make
     (Message_Id : String;
      Severity   : Diagnostic_Severity;
      Category   : Diagnostic_Category;
      Name       : String := "";
      Value      : String := "";
      Detail     : String := "";
      Hint_Id    : String := "") return Diagnostic
   is
   begin
      return
        (Message_Id  => U.To_Unbounded_String (Message_Id),
         Severity    => Severity,
         Category    => Category,
         Name        => U.To_Unbounded_String (Name),
         Value       => U.To_Unbounded_String (Value),
         Detail      => U.To_Unbounded_String (Detail),
         Hint_Id     => U.To_Unbounded_String (Hint_Id),
         Source_Name => U.Null_Unbounded_String,
         Line        => 0,
         Column      => 0);
   end Make;

   function With_Source
     (Item        : Diagnostic;
      Source_Name : String;
      Line        : Positive;
      Column      : Natural := 0) return Diagnostic
   is
      Result : Diagnostic := Item;
   begin
      Result.Source_Name := U.To_Unbounded_String (Source_Name);
      Result.Line := Line;
      Result.Column := Column;
      return Result;
   end With_Source;

   function Escape (Text : String) return String is
      Result : U.Unbounded_String;
      C      : Character;
   begin
      for Index in Text'Range loop
         C := Text (Index);
         case C is
            when Ada.Characters.Latin_1.LF =>
               U.Append (Result, "\n");
            when Ada.Characters.Latin_1.CR =>
               U.Append (Result, "\r");
            when Ada.Characters.Latin_1.HT =>
               U.Append (Result, "\t");
            when Character'Val (27) =>
               U.Append (Result, "\e");
            when Character'Val (0) .. Character'Val (8)
               | Character'Val (11) .. Character'Val (12)
               | Character'Val (14) .. Character'Val (26)
               | Character'Val (28) .. Character'Val (31)
               | Character'Val (127) =>
               U.Append (Result, "?");
            when others =>
               U.Append (Result, C);
         end case;
      end loop;
      return U.To_String (Result);
   end Escape;

   function Status_For (Item : Diagnostic) return Exit_Code is
   begin
      case Item.Category is
         when Usage =>
            return Usage_Exit;
         when Program_Source | Input | Output | Platform | Environment =>
            return IO_Exit;
         when Interpreter =>
            return Interpreter_Exit;
         when Internal =>
            return Internal_Exit;
      end case;
   end Status_For;
end Awk_CLI.Diagnostics;
