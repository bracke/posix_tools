with Posix_Tools.Text.Tab_Stops;

package body Posix_Tools.Commands.Text_Helpers.Tab_Stops is
   function Next_Column
     (Config : Configuration;
      Column : Natural) return Natural
   is
      function Stop_Count return Natural;
      function Stop_Value (Index : Positive) return Natural;

      function Configured_Next_Column is
        new Posix_Tools.Text.Tab_Stops.Next_Column
          (Stop_Count => Stop_Count,
           Stop_Value => Stop_Value);

      function Stop_Count return Natural is
      begin
         return Natural (Config.Stops.Length);
      end Stop_Count;

      function Stop_Value (Index : Positive) return Natural is
      begin
         return Config.Stops.Element (Index);
      end Stop_Value;
   begin
      return Configured_Next_Column (Column, Config.Default_Stop);
   end Next_Column;

   function Parse
     (Config : in out Configuration;
      Text   : String) return Boolean
   is
      Valid     : Boolean;
      Last_Stop : Natural;

      procedure Append_Stop (Value : Natural);

      procedure Append_Stop (Value : Natural) is
      begin
         Config.Stops.Append (Value);
      end Append_Stop;

      procedure Parse_Configured_Stops is
        new Posix_Tools.Text.Tab_Stops.For_Each_Stop (Handle => Append_Stop);
   begin
      Config.Stops.Clear;
      Parse_Configured_Stops (Text, Valid, Last_Stop);
      if Valid then
         Config.Default_Stop := Last_Stop;
      end if;
      return Valid;
   end Parse;

   function Spaces_To_Next_Tab
     (Config : Configuration;
      Column : Natural) return Natural is
   begin
      return Next_Column (Config, Column) - Column;
   end Spaces_To_Next_Tab;
end Posix_Tools.Commands.Text_Helpers.Tab_Stops;
