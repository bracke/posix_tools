with Ada.Containers;

separate (Awk_CLI.Options)
function Handle_Initial_Assignment
  (Result    : in out Parsed_Options;
   Arguments : String_Vectors.Vector;
   Index     : in out Positive;
   Current   : String) return Handler_Result
is
   use type Ada.Containers.Count_Type;

   function Arg (Position : Positive) return String is
     (U.To_String (Arguments.Element (Position)));

   procedure Add_V (Text : String; Original_Index : Positive) is
      Name  : U.Unbounded_String;
      Value : U.Unbounded_String;
   begin
      Split_Assignment (Text, Name, Value);
      Result.Initial_Assignments.Append
        (Assignment'(Name => Name, Value => Value, Original_Index => Original_Index,
                     Original_Text => U.To_Unbounded_String (Text)));
   end Add_V;
begin
   if Current = "-v" then
      if Index = Positive (Arguments.Length) then
         return (Ok => False, Failure => Missing ("-v", Result.Color));
      end if;

      Index := Index + 1;
      if not Is_Assignment_Text (Arg (Index)) then
         return (Ok => False, Failure => Invalid_Assignment (Result.Color, Arg (Index)));
      end if;
      Add_V (Arg (Index), Index);
   else
      declare
         Text : constant String := Current (Current'First + 2 .. Current'Last);
      begin
         if not Is_Assignment_Text (Text) then
            return (Ok => False, Failure => Invalid_Assignment (Result.Color, Text));
         end if;
         Add_V (Text, Index);
      end;
   end if;

   return (Ok => True);
end Handle_Initial_Assignment;
