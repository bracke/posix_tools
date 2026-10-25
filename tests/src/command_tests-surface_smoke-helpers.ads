with Ada.Calendar;
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

   procedure Remove_Any (Path : String);
   function Octal (Mode : Natural) return String;
   procedure Assert_Mode_When_Available (Path : String; Expected : Natural; Label : String);
   procedure Assert_Full_Mode_When_Available (Path : String; Expected : Natural; Label : String);
   function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean;
   function Large_Copy_Data return String;
   function Trim_Natural (Value : Natural) return String;

   --  Removes every fixture a surface test makes.
   procedure Remove_Fixtures;
   --  Removes them and puts the tracked option-operands fixture back.
   procedure Restore_Fixtures;
   --  Ignores a host that cannot make symbolic links; tests check Is_Link.
   procedure Create_Symbolic_Link_If_Supported (Target, Link : String);
   --  The files find and test examine: Source and Other, Made holding
   --  copies of both, Tree with sub/file.txt, a FIFO and a socket where the
   --  host makes them, and Symlinked naming Source where it links.
   procedure Prepare_Search_Fixtures;
end Command_Tests.Surface_Smoke.Helpers;
