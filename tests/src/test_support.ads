with Posix_Tools.Arguments;

--  Helpers the AUnit tests share: argument vectors, work paths, text
--  searches, file writing and removal, and the generators behind the
--  deterministic property tests.
package Test_Support is
   function No_Args return Posix_Tools.Arguments.Vector;
   function One_Arg (A : String) return Posix_Tools.Arguments.Vector;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector;
   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector;
   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector;

   --  Generated/test-work/Name, where tests make their files.
   function Work_Path (Name : String) return String;
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
end Test_Support;
