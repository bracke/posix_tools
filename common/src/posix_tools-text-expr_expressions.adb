with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Expr_Regex;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Text.Expr_Expressions is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.Expr_Regex.Match_Status;

   type Expr_Value is record
      Text : Unbounded_String;
   end record;

   function Make (Text : String) return Expr_Value is
   begin
      return (Text => To_Unbounded_String (Text));
   end Make;

   function Parse_Integer (Text : String; Value : out Long_Long_Integer) return Boolean is
      Parsed : Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long;
   begin
      Value := 0;
      if Text /= "" and then Text (Text'First) = '+' then
         return False;
      else
         Parsed := Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text);
         if Parsed.Valid then
            Value := Parsed.Value;
            return True;
         else
            return False;
         end if;
      end if;
   end Parse_Integer;

   function Failed_Result
     (Status  : Evaluation_Status;
      Operand : String := "") return Evaluation_Result
   is
   begin
      return
        (Status       => Status,
         Value        => Null_Unbounded_String,
         Error_Operand => To_Unbounded_String (Operand));
   end Failed_Result;

   function Successful_Result (Value : Expr_Value) return Evaluation_Result is
   begin
      return
        (Status       => Valid,
         Value        => Value.Text,
         Error_Operand => Null_Unbounded_String);
   end Successful_Result;

   function Evaluate (Arguments : Posix_Tools.Arguments.Vector) return Evaluation_Result is
      Position : Positive := 1;
      Failed   : Boolean := False;
      Failure  : Evaluation_Result;

      procedure Fail (Status : Evaluation_Status; Operand : String := "") is
      begin
         if not Failed then
            Failure := Failed_Result (Status, Operand);
            Failed := True;
         end if;
      end Fail;

      function Argument_Count return Natural is
      begin
         return Natural (Arguments.Length);
      end Argument_Count;

      function Argument (Index : Positive) return String is
      begin
         return Arguments.Element (Index);
      end Argument;

      function Have (Token : String) return Boolean is
      begin
         return Position <= Argument_Count and then Argument (Position) = Token;
      end Have;

      function Consume (Token : String) return Boolean is
      begin
         if Have (Token) then
            Position := Position + 1;
            return True;
         else
            return False;
         end if;
      end Consume;

      function Eval_Or return Expr_Value;
      function Regex_Match (Left, Pattern : String) return Expr_Value;

      function Eval_Primary return Expr_Value is
         Token : Unbounded_String;
      begin
         if Failed then
            return Make ("");
         elsif Position > Argument_Count then
            Fail (Missing_Operand);
            return Make ("");
         end if;

         Token := To_Unbounded_String (Argument (Position));
         Position := Position + 1;

         if To_String (Token) = "(" then
            declare
               Value : constant Expr_Value := Eval_Or;
            begin
               if not Consume (")") then
                  Fail (Missing_Right_Parenthesis);
               end if;
               return Value;
            end;
         elsif To_String (Token) = ")" then
            Fail (Unexpected_Right_Parenthesis);
            return Make ("");
         elsif To_String (Token) = "length" then
            declare
               Value : constant Expr_Value := Eval_Primary;
            begin
               return Make
                 (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                    (Long_Long_Integer (Length (Value.Text))));
            end;
         elsif To_String (Token) = "index" then
            declare
               Source_Value : constant Expr_Value := Eval_Primary;
               Chars_Value  : constant Expr_Value := Eval_Primary;
               Source       : constant String := To_String (Source_Value.Text);
               Chars        : constant String := To_String (Chars_Value.Text);
            begin
               for I in Source'Range loop
                  for Ch of Chars loop
                     if Source (I) = Ch then
                        return Make
                          (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                             (Long_Long_Integer (I - Source'First + 1)));
                     end if;
                  end loop;
               end loop;
               return Make ("0");
            end;
         elsif To_String (Token) = "substr" then
            declare
               Source_Value : constant Expr_Value := Eval_Primary;
               Start_Value  : constant Expr_Value := Eval_Primary;
               Len_Value    : constant Expr_Value := Eval_Primary;
               Source       : constant String := To_String (Source_Value.Text);
               Start_Text   : constant String := To_String (Start_Value.Text);
               Len_Text     : constant String := To_String (Len_Value.Text);
               Start_Num  : Long_Long_Integer;
               Len_Num    : Long_Long_Integer;
            begin
               if not Parse_Integer (Start_Text, Start_Num) or else not Parse_Integer (Len_Text, Len_Num) then
                  Fail (Non_Numeric_Substr_Operand);
                  return Make ("");
               elsif Start_Num <= 0 or else Len_Num <= 0 or else Start_Num > Long_Long_Integer (Source'Length) then
                  return Make ("");
               else
                  declare
                     First : constant Positive := Source'First + Natural (Start_Num) - 1;
                     Last  : constant Natural := Natural'Min (Source'Last, First + Natural (Len_Num) - 1);
                  begin
                     return Make (Source (First .. Last));
                  end;
               end if;
            end;
         elsif To_String (Token) = "match" then
            declare
               Source  : constant Expr_Value := Eval_Primary;
               Pattern : constant Expr_Value := Eval_Primary;
            begin
               return Regex_Match (To_String (Source.Text), To_String (Pattern.Text));
            end;
         else
            return Make (To_String (Token));
         end if;
      end Eval_Primary;

      function Regex_Match (Left, Pattern : String) return Expr_Value is
         Result : constant Posix_Tools.Text.Expr_Regex.Match_Result :=
           Posix_Tools.Text.Expr_Regex.Match (Left, Pattern);
      begin
         if Result.Status = Posix_Tools.Text.Expr_Regex.Match_Invalid_Expression then
            Fail (Invalid_Regular_Expression, Pattern);
            return Make ("");
         else
            return (Text => Result.Value);
         end if;
      end Regex_Match;

      function Eval_Match return Expr_Value is
         Left : Expr_Value := Eval_Primary;
      begin
         while not Failed and then Consume (":") loop
            declare
               Right : constant Expr_Value := Eval_Primary;
            begin
               Left := Regex_Match (To_String (Left.Text), To_String (Right.Text));
            end;
         end loop;
         return Left;
      end Eval_Match;

      function Eval_Mul return Expr_Value is
         Left : Expr_Value := Eval_Match;
      begin
         while not Failed and then Position <= Argument_Count
           and then Argument (Position) in "*" | "/" | "%"
         loop
            declare
               Op    : constant String := Argument (Position);
               Right : Expr_Value;
               L_Int : Long_Long_Integer;
               R_Int : Long_Long_Integer;
            begin
               Position := Position + 1;
               Right := Eval_Match;
               if not Parse_Integer (To_String (Left.Text), L_Int)
                 or else not Parse_Integer (To_String (Right.Text), R_Int)
               then
                  Fail (Non_Numeric_Arithmetic_Operand);
                  return Make ("");
               elsif (Op = "/" or else Op = "%") and then R_Int = 0 then
                  Fail (Division_By_Zero);
                  return Make ("");
               end if;

               begin
                  if Op = "*" then
                     Left :=
                       Make
                         (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                            (L_Int * R_Int));
                  elsif Op = "/" then
                     Left :=
                       Make
                         (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                            (L_Int / R_Int));
                  else
                     Left :=
                       Make
                         (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                            (L_Int mod R_Int));
                  end if;
               exception
                  when Constraint_Error =>
                     Fail (Numeric_Overflow);
                     return Make ("");
               end;
            end;
         end loop;
         return Left;
      end Eval_Mul;

      function Eval_Add return Expr_Value is
         Left : Expr_Value := Eval_Mul;
      begin
         while not Failed and then Position <= Argument_Count
           and then Argument (Position) in "+" | "-"
         loop
            declare
               Op    : constant String := Argument (Position);
               Right : Expr_Value;
               L_Int : Long_Long_Integer;
               R_Int : Long_Long_Integer;
            begin
               Position := Position + 1;
               Right := Eval_Mul;
               if not Parse_Integer (To_String (Left.Text), L_Int)
                 or else not Parse_Integer (To_String (Right.Text), R_Int)
               then
                  Fail (Non_Numeric_Arithmetic_Operand);
                  return Make ("");
               end if;

               begin
                  if Op = "+" then
                     Left :=
                       Make
                         (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                            (L_Int + R_Int));
                  else
                     Left :=
                       Make
                         (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                            (L_Int - R_Int));
                  end if;
               exception
                  when Constraint_Error =>
                     Fail (Numeric_Overflow);
                     return Make ("");
               end;
            end;
         end loop;
         return Left;
      end Eval_Add;

      function Eval_Compare return Expr_Value is
         Left : Expr_Value := Eval_Add;
      begin
         while not Failed and then Position <= Argument_Count
           and then Argument (Position) in "=" | "!=" | "<" | "<=" | ">" | ">="
         loop
            declare
               Op    : constant String := Argument (Position);
               Right : Expr_Value;
               L_Int : Long_Long_Integer;
               R_Int : Long_Long_Integer;
               Truth : Boolean;
            begin
               Position := Position + 1;
               Right := Eval_Add;
               if Parse_Integer (To_String (Left.Text), L_Int)
                 and then Parse_Integer (To_String (Right.Text), R_Int)
               then
                  Truth :=
                    (if Op = "=" then L_Int = R_Int
                     elsif Op = "!=" then L_Int /= R_Int
                     elsif Op = "<" then L_Int < R_Int
                     elsif Op = "<=" then L_Int <= R_Int
                     elsif Op = ">" then L_Int > R_Int
                     else L_Int >= R_Int);
               else
                  declare
                     L_Text : constant String := To_String (Left.Text);
                     R_Text : constant String := To_String (Right.Text);
                  begin
                     Truth :=
                       (if Op = "=" then L_Text = R_Text
                        elsif Op = "!=" then L_Text /= R_Text
                        elsif Op = "<" then L_Text < R_Text
                        elsif Op = "<=" then L_Text <= R_Text
                        elsif Op = ">" then L_Text > R_Text
                        else L_Text >= R_Text);
                  end;
               end if;
               Left := Make (if Truth then "1" else "0");
            end;
         end loop;
         return Left;
      end Eval_Compare;

      function Eval_And return Expr_Value is
         Left : Expr_Value := Eval_Compare;
      begin
         while not Failed and then Consume ("&") loop
            declare
               Right : constant Expr_Value := Eval_Compare;
            begin
               Left :=
                 (if Is_False (To_String (Left.Text))
                    or else Is_False (To_String (Right.Text))
                  then Make ("0")
                  else Left);
            end;
         end loop;
         return Left;
      end Eval_And;

      function Eval_Or return Expr_Value is
         Left : Expr_Value := Eval_And;
      begin
         while not Failed and then Consume ("|") loop
            declare
               Right : constant Expr_Value := Eval_And;
            begin
               Left := (if Is_False (To_String (Left.Text)) then Right else Left);
            end;
         end loop;
         return Left;
      end Eval_Or;

      Value : Expr_Value;
   begin
      if Argument_Count = 0 then
         return Failed_Result (Missing_Expression);
      end if;

      Value := Eval_Or;
      if Failed then
         return Failure;
      elsif Position <= Argument_Count then
         return Failed_Result (Extra_Operand, Argument (Position));
      else
         return Successful_Result (Value);
      end if;
   end Evaluate;
end Posix_Tools.Text.Expr_Expressions;
