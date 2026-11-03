with Posix_Tools.Arguments;
with Posix_Tools.Exit_Status;
with Test_Support;

package Command_Tests.Support is
   function No_Args return Posix_Tools.Arguments.Vector
     renames Test_Support.No_Args;
   function One_Arg (A : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.One_Arg;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Two_Args;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Three_Args;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Four_Args;
   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Five_Args;
   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Six_Args;
   function Fixture_Path (Name : String) return String
     renames Test_Support.Work_Path;
   function Work_Path (Name : String) return String
     renames Test_Support.Work_Path;
   function Contains (Text, Pattern : String) return Boolean
     renames Test_Support.Contains;
   function Occurrences (Text, Pattern : String) return Natural
     renames Test_Support.Occurrences;
   procedure Assert_Inventory_Status_Lines
     (Output_Text, Label : String)
     renames Test_Support.Assert_Inventory_Status_Lines;
   function Inventory_List_Output return String
     renames Test_Support.Inventory_List_Output;
   procedure Write_File (Path, Data : String)
     renames Test_Support.Write_File;
   procedure Delete_If_Exists (Path : String)
     renames Test_Support.Delete_If_Exists;

   function Expected_Verify_Status
     (Output_Text : String) return Posix_Tools.Exit_Status.Code;
end Command_Tests.Support;
