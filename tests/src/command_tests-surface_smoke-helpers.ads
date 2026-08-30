with Posix_Tools.Arguments;

package Command_Tests.Surface_Smoke.Helpers is
   function No_Args return Posix_Tools.Arguments.Vector;
   function One_Arg (A : String) return Posix_Tools.Arguments.Vector;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector;
   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector;
   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector;

   function Fixture_Path (Name : String) return String;
   function Work_Path (Name : String) return String;
   function Contains (Text, Pattern : String) return Boolean;
   function Occurrences (Text, Pattern : String) return Natural;

   procedure Assert_Inventory_Status_Lines (Output_Text, Label : String);
   function Inventory_List_Output return String;
   procedure Write_File (Path, Data : String);
end Command_Tests.Surface_Smoke.Helpers;
