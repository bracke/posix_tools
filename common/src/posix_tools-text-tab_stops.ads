package Posix_Tools.Text.Tab_Stops
  with SPARK_Mode => On
is
   type Parsed_Stop is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   type Parsed_Stop_List is record
      Valid : Boolean := False;
      Last_Stop : Natural := 0;
   end record;

   function Parse_Stop (Text : String; Previous : Natural) return Parsed_Stop
     with
       Post =>
         (if Parse_Stop'Result.Valid then
            Parse_Stop'Result.Value > 0
            and then Parse_Stop'Result.Value > Previous
          else
            Parse_Stop'Result.Value = 0);

   function Parse_List (Text : String) return Parsed_Stop_List
     with
       Post =>
         (if not Parse_List'Result.Valid then Parse_List'Result.Last_Stop = 0);

   generic
      with procedure Handle (Value : Natural);
   procedure For_Each_Stop
     (Text      : String;
      Valid     : out Boolean;
      Last_Stop : out Natural);

   generic
      with function Stop_Count return Natural;
      with function Stop_Value (Index : Positive) return Natural;
   function Next_Column (Column, Default_Stop : Natural) return Natural
     with Pre => Default_Stop > 0;
end Posix_Tools.Text.Tab_Stops;
