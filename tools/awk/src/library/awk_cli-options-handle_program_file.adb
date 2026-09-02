with Ada.Containers;

separate (Awk_CLI.Options)
function Handle_Program_File
  (Result    : in out Parsed_Options;
   Arguments : String_Vectors.Vector;
   Index     : in out Positive;
   Current   : String) return Handler_Result
is
   use type Ada.Containers.Count_Type;

   function Arg (Position : Positive) return String is
     (U.To_String (Arguments.Element (Position)));

   procedure Add_Program_File (Name : String; Original_Index : Positive) is
   begin
      Result.Program_Files.Append
        (Program_File'(Name => U.To_Unbounded_String (Name),
                       Original_Index => Original_Index));
   end Add_Program_File;
begin
   if Current = "-f" then
      if Index = Positive (Arguments.Length) then
         return (Ok => False, Failure => Missing ("-f", Result.Color));
      end if;

      Index := Index + 1;
      if Arg (Index) = "-" then
         return (Ok => False, Failure => Stdin_Program_File (Result.Color, "-f -"));
      end if;
      Add_Program_File (Arg (Index), Index);
   else
      declare
         Name : constant String := Current (Current'First + 2 .. Current'Last);
      begin
         if Name = "-" then
            return (Ok => False, Failure => Stdin_Program_File (Result.Color, "-f-"));
         end if;
         Add_Program_File (Name, Index);
      end;
   end if;

   return (Ok => True);
end Handle_Program_File;
