with Ada.Environment_Variables;

package body Posix_Tools.Host_Adapters.Environment is
   function Pairs return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;

      procedure Append_Pair (Name, Value : String) is
      begin
         Result.Append (Name & "=" & Value);
      end Append_Pair;
   begin
      Ada.Environment_Variables.Iterate (Append_Pair'Access);
      return Result;
   end Pairs;

   function Defined (Name : String) return Boolean is
   begin
      return Ada.Environment_Variables.Exists (Name);
   end Defined;

   function Value (Name : String) return String is
   begin
      return Ada.Environment_Variables.Value (Name);
   exception
      when Constraint_Error =>
         return "";
   end Value;
end Posix_Tools.Host_Adapters.Environment;
