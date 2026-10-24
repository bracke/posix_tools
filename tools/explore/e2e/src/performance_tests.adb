with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Real_Time;
with Ada.Text_IO;
with E2E_Rig;
with GNAT.OS_Lib;

package body Performance_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   Entries : constant := 100_000;

   --  The budgets, in milliseconds: the first frame -- from explore's first
   --  output, so with its handshake but without the time the system takes to
   --  start a program -- and the answer to a key, whatever the size of the
   --  directory and whether it is still being read.
   First_Paint_Budget : constant := 100;
   Key_Budget         : constant := 100;

   --  Not a budget but a bound, against a listing that never ends.
   Listing_Bound : constant := 10_000;

   --  The directory of Entries empty files, made once and kept between runs.
   function Large_Directory return String;

   --  Milliseconds since Since.
   function Elapsed (Since : Ada.Real_Time.Time) return Natural is
     (Natural (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Since) * 1000));

   function Image (Value : Natural) return String is (Natural'Image (Value) (2 .. Natural'Image (Value)'Last));

   function Large_Directory return String is
      Path   : constant String := Ada.Directories.Full_Name ("obj/fixtures-kept/large");
      Marker : constant String := Path & "/.complete";
   begin
      if not Ada.Directories.Exists (Marker) then
         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_Tree (Path);
         end if;

         Ada.Directories.Create_Path (Path);

         for I in 1 .. Entries loop
            declare
               Name   : constant String := Image (I);
               Handle : constant GNAT.OS_Lib.File_Descriptor :=
                 GNAT.OS_Lib.Create_File (Path & "/file" & [1 .. 6 - Name'Length => '0'] & Name, GNAT.OS_Lib.Binary);
            begin
               GNAT.OS_Lib.Close (Handle);
            end;
         end loop;

         E2E_Rig.Write_File (Marker, "");
      end if;

      return Path;
   end Large_Directory;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("performance:large directory", Test_Large_Directory'Access));
      return Result;
   end Suite;

   procedure Test_Large_Directory (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Large_Directory;
      Total   : constant String := "/" & Image (Entries);
      Session : E2E_Rig.Rig;
      Started : Ada.Real_Time.Time;
      First_Paint, Launched, Listed, To_Bottom, Worst_Step, Filtered : Natural := 0;
      Ended   : Boolean;
      Code    : Integer;
   begin
      Started := Ada.Real_Time.Clock;
      E2E_Rig.Start (Session, Root, Rows => 40, Columns => 120);
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "q quit"), "a first frame");
      First_Paint := Elapsed (E2E_Rig.First_Output (Session));
      Launched := Elapsed (Started);

      --  Keys are answered while the directory is still being read.
      AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, "1" & Total, 30_000), "all entries listed");
      Listed := Elapsed (Started);

      declare
         Pressed : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         E2E_Rig.Send (Session, "G");
         AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, Image (Entries) & Total), "to the last entry");
         To_Bottom := Elapsed (Pressed);
      end;

      for Step in 1 .. 20 loop
         declare
            Pressed : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         begin
            E2E_Rig.Send (Session, "k");
            AUnit.Assertions.Assert
              (E2E_Rig.Wait_For (Session, Image (Entries - Step) & Total), "one entry up");
            Worst_Step := Natural'Max (Worst_Step, Elapsed (Pressed));
         end;
      end loop;

      declare
         Pressed : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      begin
         E2E_Rig.Send (Session, "ffile099999");
         AUnit.Assertions.Assert (E2E_Rig.Wait_For (Session, " 1/1 "), "filtered to one:" & E2E_Rig.Screen (Session));
         Filtered := Elapsed (Pressed);
      end;

      --  Escape and q apart, or they would be read as Alt-q.
      E2E_Rig.Send (Session, "" & Character'Val (27));
      E2E_Rig.Pump (Session, 300);
      E2E_Rig.Send (Session, "q");
      E2E_Rig.Wait_Exit (Session, Ended, Code, 10_000);
      E2E_Rig.Stop (Session);

      Ada.Text_IO.Put_Line
        ("explore on" & Natural'Image (Entries) & " entries: first frame" & Natural'Image (First_Paint)
         & " ms (" & Image (Launched) & " ms from launch), all listed" & Natural'Image (Listed) & " ms, to the bottom" & Natural'Image (To_Bottom)
         & " ms, slowest step" & Natural'Image (Worst_Step) & " ms, filter typed" & Natural'Image (Filtered) & " ms");

      AUnit.Assertions.Assert (Ended and then Code = 0, "quit");
      AUnit.Assertions.Assert (First_Paint <= First_Paint_Budget, "the first frame within its budget");
      AUnit.Assertions.Assert (Listed <= Listing_Bound, "the directory listed");
      AUnit.Assertions.Assert
        (To_Bottom <= Key_Budget and then Worst_Step <= Key_Budget, "moving within the budget of a key");
      AUnit.Assertions.Assert (Filtered <= Key_Budget * 11, "each key of the filter within its budget");
   end Test_Large_Directory;
end Performance_Tests;
