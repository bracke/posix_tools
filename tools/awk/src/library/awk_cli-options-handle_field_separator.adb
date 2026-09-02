with Ada.Containers;

separate (Awk_CLI.Options)
function Handle_Field_Separator
  (Result    : in out Parsed_Options;
   Arguments : String_Vectors.Vector;
   Index     : in out Positive) return Handler_Result
is
   use type Ada.Containers.Count_Type;

   function Arg (Position : Positive) return String is
     (U.To_String (Arguments.Element (Position)));

   Current : constant String := Arg (Index);
begin
   if Current = "-F" then
      if Index = Positive (Arguments.Length) then
         return (Ok => False, Failure => Missing ("-F", Result.Color));
      end if;

      Index := Index + 1;
      Result.Field_Separator := U.To_Unbounded_String (Arg (Index));
   else
      Result.Field_Separator :=
        U.To_Unbounded_String (Current (Current'First + 2 .. Current'Last));
   end if;

   Result.Has_Field_Separator := True;
   return (Ok => True);
end Handle_Field_Separator;
