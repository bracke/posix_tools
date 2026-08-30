with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find_Validation is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   function Parse_Find_Count
     (Text     : String;
      Count    : out Long_Long_Integer;
      Relation : out Posix_Tools.Text.Find_Expressions.Count_Relation;
      Bytes    : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
        Posix_Tools.Text.Find_Expressions.Parse_Find_Count (Text);
   begin
      Count := Parsed.Count;
      Relation := Parsed.Relation;
      Bytes := Parsed.Bytes;
      return Parsed.Valid;
   end Parse_Find_Count;

   function Parse_Permission_Mode
     (Text      : String;
      Mode      : out Natural;
      Match_All : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
        Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode (Text);
   begin
      Mode := Parsed.Mode;
      Match_All := Parsed.Match_All;
      case Parsed.Status is
         when Posix_Tools.Text.File_Modes.Invalid_Permission_Mode =>
            return False;
         when Posix_Tools.Text.File_Modes.Octal_Permission_Mode
            | Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode =>
            return True;
      end case;
   end Parse_Permission_Mode;

   function Validate_Expression
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result     : out Posix_Tools.Commands.Results.Result;
      Expression : Posix_Tools.Arguments.Vector) return Boolean
   is
      Depth : Integer := 0;
      I     : Positive := 1;
      Valid : Boolean := True;
   begin
      while I <= Natural (Expression.Length) loop
         declare
            Token : constant String := Expression.Element (I);
         begin
            if Token = "(" then
               Depth := Depth + 1;
               I := I + 1;
            elsif Token = ")" then
               Depth := Depth - 1;
               if Depth < 0 then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand ')'");
                  return False;
               end if;
               I := I + 1;
            elsif Token = "!"
              or else Token = "-a"
              or else Token = "-o"
              or else Token = "-depth"
              or else Token = "-prune"
              or else Token = "-xdev"
              or else Token = "-print"
            then
               I := I + 1;
            elsif Token = "-exec" or else Token = "-ok" then
               declare
                  Terminator : Natural := 0;
               begin
                  for J in I + 1 .. Natural (Expression.Length) loop
                     if Expression.Element (J) = ";"
                       or else (Token = "-exec" and then Expression.Element (J) = "+")
                     then
                        Terminator := J;
                        exit;
                     end if;
                  end loop;

                  if Terminator = 0 then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing option argument '-exec'");
                     return False;
                  elsif Terminator = I + 1 then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing operand");
                     return False;
                  elsif Token = "-exec"
                    and then Expression.Element (Terminator) = "+"
                    and then Expression.Element (Terminator - 1) /= "{}"
                  then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '+'");
                     return False;
                  end if;

                  I := Terminator + 1;
               end;
            elsif Token = "-name" or else Token = "-path" or else Token = "-newer"
              or else Token = "-user" or else Token = "-group"
            then
               if I = Natural (Expression.Length) then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '" & Token & "'");
                  return False;
               end if;
               if Token = "-newer" and then not FS.Exists (Expression.Element (I + 1)) then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                  return False;
               end if;
               I := I + 2;
            elsif Token = "-nouser" or else Token = "-nogroup" then
               I := I + 1;
            elsif Token = "-mtime" then
               if I = Natural (Expression.Length) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-mtime'");
                  return False;
               end if;
               declare
                  Count    : Long_Long_Integer;
                  Relation : Posix_Tools.Text.Find_Expressions.Count_Relation;
                  Bytes    : Boolean;
               begin
                  if not Parse_Find_Count (Expression.Element (I + 1), Count, Relation, Bytes)
                    or else Bytes
                  then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                     return False;
                  end if;
               end;
               I := I + 2;
            elsif Token = "-perm" then
               if I = Natural (Expression.Length) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-perm'");
                  return False;
               end if;
               declare
                  Mode      : Natural;
                  Match_All : Boolean;
               begin
                  if not Parse_Permission_Mode (Expression.Element (I + 1), Mode, Match_All) then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                     return False;
                  end if;
               end;
               I := I + 2;
            elsif Token = "-size" then
               if I = Natural (Expression.Length) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-size'");
                  return False;
               end if;
               declare
                  Count    : Long_Long_Integer;
                  Relation : Posix_Tools.Text.Find_Expressions.Count_Relation;
                  Bytes    : Boolean;
               begin
                  if not Parse_Find_Count (Expression.Element (I + 1), Count, Relation, Bytes) then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid operand '" & Expression.Element (I + 1) & "'");
                     return False;
                  end if;
               end;
               I := I + 2;
            elsif Token = "-type" then
               if I = Natural (Expression.Length) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-type'");
                  return False;
               end if;
               declare
                  Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
                    Posix_Tools.Text.Find_Expressions.Parse_Type_Filter
                      (Expression.Element (I + 1));
               begin
                  Valid := Valid and then Parsed.Valid;
               end;
               if not Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "unsupported type '" & Expression.Element (I + 1) & "'");
                  return False;
               end if;
               I := I + 2;
            elsif Token'Length > 0 and then Token (Token'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "unknown option '" & Token & "'");
               return False;
            else
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Token & "'");
               return False;
            end if;
         end;
      end loop;

      if Depth /= 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '('");
         return False;
      end if;

      return True;
   end Validate_Expression;
end Posix_Tools.Commands.Find_Validation;
