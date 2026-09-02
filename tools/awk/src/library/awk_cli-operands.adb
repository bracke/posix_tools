package body Awk_CLI.Operands is
   function Classify
     (Operands : Awk_CLI.Options.Operand_Vectors.Vector) return Operand_Vectors.Vector
   is
      Result : Operand_Vectors.Vector;
   begin
      for Item of Operands loop
         declare
            Text  : constant String := U.To_String (Item.Text);
            Name  : U.Unbounded_String;
            Value : U.Unbounded_String;
         begin
            if Text = "-" then
               Result.Append
                 (Classified_Operand'
                    (Kind => Standard_Input, Text => Item.Text,
                     Name => U.Null_Unbounded_String, Value => U.Null_Unbounded_String,
                     Original_Index => Item.Original_Index));
            elsif Awk_CLI.Options.Is_Assignment_Text (Text) then
               Awk_CLI.Options.Split_Assignment (Text, Name, Value);
               Result.Append
                 (Classified_Operand'
                    (Kind => Runtime_Assignment, Text => Item.Text, Name => Name,
                     Value => Value, Original_Index => Item.Original_Index));
            else
               Result.Append
                 (Classified_Operand'
                    (Kind => Named_File, Text => Item.Text,
                     Name => U.Null_Unbounded_String, Value => U.Null_Unbounded_String,
                     Original_Index => Item.Original_Index));
            end if;
         end;
      end loop;
      return Result;
   end Classify;
end Awk_CLI.Operands;
