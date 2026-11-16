with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;

--  Helpers the AUnit tests share: argument vectors, work paths, text
--  searches, file writing and removal, and the generators behind the
--  deterministic property tests.
package Test_Support is
   type Work_Directory is limited private;

   function No_Args return Posix_Tools.Arguments.Vector;
   function One_Arg (A : String) return Posix_Tools.Arguments.Vector;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector;
   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector;
   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector;

   --  A private host temporary directory/Name, where this process makes its
   --  files. The root is allocated atomically so concurrent runners cannot
   --  share it, even across PID namespaces.
   function Work_Path (Name : String) return String;
   procedure Prepare_Work_Directory;
   --  Strict cleanup for normal driver termination.
   procedure Remove_Work_Directory;
   --  Best-effort cleanup that preserves an exception already in flight.
   procedure Remove_Work_Directory_Safely;

   --  Independent work directories for tests of the lifecycle itself. These
   --  operations never disturb the suite-wide directory used by Work_Path.
   function Work_Path
     (Directory : in out Work_Directory;
      Name      : String) return String;
   procedure Prepare_Work_Directory
     (Directory : in out Work_Directory);
   procedure Remove_Work_Directory
     (Directory : in out Work_Directory);
   procedure Remove_Work_Directory_Safely
     (Directory : in out Work_Directory);
   --  Restore a test's working directory without replacing an exception that
   --  is already being propagated.
   procedure Restore_Directory_Safely (Path : String);
   function Contains (Text, Pattern : String) return Boolean;
   --  Non-overlapping occurrences of Pattern in Text.
   function Occurrences (Text, Pattern : String) return Natural;

   --  Output_Text holds one "<command>: " line per inventory command, in
   --  inventory order.
   procedure Assert_Inventory_Status_Lines (Output_Text, Label : String);
   --  posix-tools list output for the compiled inventory.
   function Inventory_List_Output return String;

   --  Path holds exactly Data's bytes.
   procedure Write_File (Path, Data : String);
   --  Remove Path, a file or a whole directory tree, if it exists.
   procedure Delete_If_Exists (Path : String);

   --  Whether the host must be able to make symbolic links and FIFOs.
   --  Every POSIX host can; Windows may refuse links for want of privilege
   --  and has no FIFOs.
   function Symbolic_Links_Expected return Boolean;
   function FIFOs_Expected return Boolean;

   --  For a test about to skip because it could not make a symbolic link:
   --  fail where links must work, so that only a host without them skips.
   procedure Skip_Without_Links (Label : String);
   --  Likewise for a test that could not make a FIFO.
   procedure Skip_Without_FIFOs (Label : String);

   --  The property tests' generators: a fixed seed, advanced by a linear
   --  congruential step, so a failing case can be named and replayed.
   type Word_32 is mod 2 ** 32;

   --  Seed := Seed * 1_664_525 + 1_013_904_223 (Numerical Recipes).
   procedure Advance (Seed : in out Word_32);
   --  Seed := Seed * 1_103_515_245 + 12_345 (the C standard's example).
   procedure Advance_C (Seed : in out Word_32);
   --  Bits 16 .. 23 of Seed after Advance_C: the byte rand () would give.
   function Next_C_Byte (Seed : in out Word_32) return Character;

   --  "seed 0x" and Seed in eight hexadecimal digits, for an assertion
   --  label built from the seed a test really starts from.
   function Seed_Label (Seed : Word_32) return String;
private
   type Work_Directory is limited record
      Root : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Test_Support;
