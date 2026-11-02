with Ada.Calendar;
with Posix_Tools.Arguments;
with Test_Support;

package Command_Tests.Surface_Smoke.Helpers is
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

   function Work_Path (Name : String) return String
     renames Test_Support.Work_Path;
   function Contains (Text, Pattern : String) return Boolean
     renames Test_Support.Contains;
   function Occurrences (Text, Pattern : String) return Natural
     renames Test_Support.Occurrences;

   procedure Assert_Inventory_Status_Lines (Output_Text, Label : String)
     renames Test_Support.Assert_Inventory_Status_Lines;
   function Inventory_List_Output return String
     renames Test_Support.Inventory_List_Output;
   procedure Write_File (Path, Data : String)
     renames Test_Support.Write_File;

   procedure Remove_Any (Path : String);
   function Octal (Mode : Natural) return String;
   procedure Assert_Mode_When_Available (Path : String; Expected : Natural; Label : String);
   procedure Assert_Full_Mode_When_Available (Path : String; Expected : Natural; Label : String);
   function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean;
   function Large_Copy_Data return String;
   function Trim_Natural (Value : Natural) return String;

   --  Removes every fixture a surface test makes.
   procedure Remove_Fixtures;
   --  Removes them and makes the option-operands directory afresh.
   procedure Restore_Fixtures;
   --  Ignores a host that cannot make symbolic links; tests check Is_Link.
   procedure Create_Symbolic_Link_If_Supported (Target, Link : String);
   --  The files find and test examine: Source and Other, Made holding
   --  copies of both, Tree with sub/file.txt, a FIFO and a socket where the
   --  host makes them, and Symlinked naming Source where it links.
   procedure Prepare_Search_Fixtures;
end Command_Tests.Surface_Smoke.Helpers;
