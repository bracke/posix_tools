with Ada.Containers;

separate (Awk_CLI.Options)
function Parse (Arguments : String_Vectors.Vector) return Parse_Result is
   use type Ada.Containers.Count_Type;

   Result       : Parsed_Options;
   Index        : Positive := 1;
   Stop_Options : Boolean := False;

   function Arg (Position : Positive) return String is
     (U.To_String (Arguments.Element (Position)));

   procedure Add_Operand (Text : String; Original_Index : Positive) is
   begin
      Result.Operands.Append
        (Operand'(Text => U.To_Unbounded_String (Text), Original_Index => Original_Index));
   end Add_Operand;

begin
   if Arguments.Is_Empty then
      return Missing_Program;
   end if;

   while Index <= Positive (Arguments.Length) loop
      declare
         Current : constant String := Arg (Index);
      begin
         if Stop_Options
           or else Current = ""
           or else Current (Current'First) /= '-'
           or else Current = "-"
         then
            Add_Operand (Current, Index);
            Stop_Options := True;
         elsif Current = "--" then
            Stop_Options := True;
         elsif Current = "--help" then
            Result.Help_Requested := True;
         elsif Current = "--version" then
            Result.Version_Requested := True;
         elsif Starts_With (Current, "--color=") then
            declare
               Outcome : constant Handler_Result := Handle_Color (Result, Current);
            begin
               if not Outcome.Ok then
                  return Outcome.Failure;
               end if;
            end;
         elsif Current = "-F" or else Starts_With (Current, "-F") then
            declare
               Outcome : constant Handler_Result :=
                 Handle_Field_Separator (Result, Arguments, Index);
            begin
               if not Outcome.Ok then
                  return Outcome.Failure;
               end if;
            end;
         elsif Current = "-v" or else Starts_With (Current, "-v") then
            declare
               Outcome : constant Handler_Result :=
                 Handle_Initial_Assignment (Result, Arguments, Index, Current);
            begin
               if not Outcome.Ok then
                  return Outcome.Failure;
               end if;
            end;
         elsif Current = "-f" or else Starts_With (Current, "-f") then
            declare
               Outcome : constant Handler_Result :=
                 Handle_Program_File (Result, Arguments, Index, Current);
            begin
               if not Outcome.Ok then
                  return Outcome.Failure;
               end if;
            end;
         else
            return Unknown_Option (Result.Color, Current);
         end if;
      end;
      Index := Index + 1;
   end loop;

   if not Result.Help_Requested
     and then not Result.Version_Requested
     and then Result.Program_Files.Is_Empty
     and then Result.Operands.Is_Empty
   then
      return Missing_Program (Result.Color);
   end if;

   return (Ok => True, Options => Result);
end Parse;
