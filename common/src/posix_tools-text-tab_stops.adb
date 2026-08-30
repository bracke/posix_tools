with Posix_Tools.Text.Base_Parsing;

package body Posix_Tools.Text.Tab_Stops
  with SPARK_Mode => On
is
   function Invalid_Stop return Parsed_Stop is
   begin
      return (Valid => False, Value => 0);
   end Invalid_Stop;

   function Invalid_List return Parsed_Stop_List is
   begin
      return (Valid => False, Last_Stop => 0);
   end Invalid_List;

   procedure For_Each_Stop
     (Text      : String;
      Valid     : out Boolean;
      Last_Stop : out Natural)
   is
      Start    : Positive := Text'First;
      Previous : Natural := 0;
   begin
      Valid := False;
      Last_Stop := 0;

      if Text = "" then
         return;
      end if;

      for I in Text'Range loop
         pragma Loop_Invariant (Start in Text'Range);

         if Text (I) = ',' then
            if I = Start then
               return;
            end if;

            declare
               Parsed : constant Parsed_Stop := Parse_Stop (Text (Start .. I - 1), Previous);
            begin
               if not Parsed.Valid then
                  return;
               end if;
               Handle (Parsed.Value);
               Previous := Parsed.Value;
            end;

            if I = Text'Last then
               return;
            end if;

            Start := I + 1;
         end if;
      end loop;

      declare
         Parsed : constant Parsed_Stop := Parse_Stop (Text (Start .. Text'Last), Previous);
      begin
         if Parsed.Valid then
            Handle (Parsed.Value);
            Valid := True;
            Last_Stop := Parsed.Value;
         end if;
      end;
   end For_Each_Stop;

   function Parse_Stop (Text : String; Previous : Natural) return Parsed_Stop is
      Parsed : constant Posix_Tools.Text.Base_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Base_Parsing.Natural_Value (Text, 10);
   begin
      if Parsed.Valid and then Parsed.Value > 0 and then Parsed.Value > Previous then
         return (Valid => True, Value => Parsed.Value);
      else
         return Invalid_Stop;
      end if;
   end Parse_Stop;

   function Parse_List (Text : String) return Parsed_Stop_List is
   begin
      if Text = "" then
         return Invalid_List;
      end if;

      declare
         Start    : Positive := Text'First;
         Previous : Natural := 0;
      begin
         for I in Text'Range loop
            pragma Loop_Invariant (Start in Text'Range);

            if Text (I) = ',' then
               if I = Start then
                  return Invalid_List;
               end if;

               declare
                  Parsed : constant Parsed_Stop := Parse_Stop (Text (Start .. I - 1), Previous);
               begin
                  if not Parsed.Valid then
                     return Invalid_List;
                  end if;
                  Previous := Parsed.Value;
               end;

               if I = Text'Last then
                  return Invalid_List;
               end if;

               Start := I + 1;
            end if;
         end loop;

         declare
            Parsed : constant Parsed_Stop := Parse_Stop (Text (Start .. Text'Last), Previous);
         begin
            if Parsed.Valid then
               return (Valid => True, Last_Stop => Parsed.Value);
            else
               return Invalid_List;
            end if;
         end;
      end;
   end Parse_List;

   function Next_Column (Column, Default_Stop : Natural) return Natural is
      Count     : constant Natural := Stop_Count;
      Last_Stop : Natural := 0;
      Step      : Natural := Default_Stop;
   begin
      if Count = 0 then
         return Column + (Default_Stop - (Column mod Default_Stop));
      end if;

      for I in 1 .. Count loop
         declare
            Stop : constant Natural := Stop_Value (I);
         begin
            if Stop > Column then
               return Stop;
            end if;
            if I > 1 then
               Step := Stop - Last_Stop;
            end if;
            Last_Stop := Stop;
         end;
      end loop;

      if Step = 0 then
         Step := Default_Stop;
      end if;
      return Last_Stop + (((Column - Last_Stop) / Step) + 1) * Step;
   end Next_Column;
end Posix_Tools.Text.Tab_Stops;
