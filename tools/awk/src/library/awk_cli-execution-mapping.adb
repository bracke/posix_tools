separate (Awk_CLI.Execution)
package body Mapping is
   function Pair (Name, Value : String) return I.Var_Assignment is
     (Name  => U.To_Unbounded_String (Name),
      Value => U.To_Unbounded_String (Value));

   function Build_Assignments
     (Options : Awk_CLI.Options.Parsed_Options) return I.Assignment_Vectors.Vector
   is
      Result : I.Assignment_Vectors.Vector;
   begin
      if Options.Has_Field_Separator then
         Result.Append (Pair ("FS", U.To_String (Options.Field_Separator)));
      end if;

      for Item of Options.Initial_Assignments loop
         Result.Append (Pair (U.To_String (Item.Name), U.To_String (Item.Value)));
      end loop;

      return Result;
   end Build_Assignments;

   function Build_Environment
     (Environment : Awk_CLI.Environment.Entry_Vectors.Vector)
      return I.Assignment_Vectors.Vector
   is
      Result : I.Assignment_Vectors.Vector;
   begin
      for Item of Environment loop
         Result.Append (Pair (U.To_String (Item.Name), U.To_String (Item.Value)));
      end loop;
      return Result;
   end Build_Environment;

   function Build_Auxiliary_Files
     (Inputs          : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Auxiliary_Files : Awk_CLI.Inputs.Input_File_Vectors.Vector;
      Live_Input      : Live_Input_Reader) return I.Assignment_Vectors.Vector
   is
      Source : constant Awk_CLI.Inputs.Input_File_Vectors.Vector :=
        (if Live_Input = null then Inputs else Auxiliary_Files);
      Result : I.Assignment_Vectors.Vector;
   begin
      for Item of Source loop
         if U.To_String (Item.Name) /= "-" and then U.To_String (Item.Name) /= "" then
            Result.Append (Pair (U.To_String (Item.Name), U.To_String (Item.Content)));
         end if;
      end loop;
      return Result;
   end Build_Auxiliary_Files;

   function Build_Arguments
     (Operands : Awk_CLI.Operands.Operand_Vectors.Vector) return I.String_Vectors.Vector
   is
      Result : I.String_Vectors.Vector;
   begin
      for Item of Operands loop
         Result.Append (Item.Text);
      end loop;
      return Result;
   end Build_Arguments;

   function Build_Runtime_Operands
     (Operands : Awk_CLI.Operands.Operand_Vectors.Vector) return I.Runtime_Operand_Vectors.Vector
   is
      Result    : I.Runtime_Operand_Vectors.Vector;
      Has_Input : Boolean := False;
   begin
      for Item of Operands loop
         case Item.Kind is
            when Awk_CLI.Operands.Named_File | Awk_CLI.Operands.Standard_Input =>
               Has_Input := True;
               Result.Append
                 (I.Runtime_Operand'
                    (Kind  => I.Input_Operand,
                     Text  => Item.Text,
                     Name  => U.Null_Unbounded_String,
                     Value => U.Null_Unbounded_String));
            when Awk_CLI.Operands.Runtime_Assignment =>
               Result.Append
                 (I.Runtime_Operand'
                    (Kind  => I.Assignment_Operand,
                     Text  => Item.Text,
                     Name  => Item.Name,
                     Value => Item.Value));
         end case;
      end loop;

      if not Has_Input then
         Result.Append
           (I.Runtime_Operand'
              (Kind  => I.Input_Operand,
               Text  => U.Null_Unbounded_String,
               Name  => U.Null_Unbounded_String,
               Value => U.Null_Unbounded_String));
      end if;

      return Result;
   end Build_Runtime_Operands;
end Mapping;
