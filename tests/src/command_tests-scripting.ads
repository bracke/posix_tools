--  Tests for the scripting utilities find, test, expr and printf: what XCU
--  says each does with symbolic links, argument counts, extension-like
--  operands and C-constant arguments.
package Command_Tests.Scripting is
   procedure Test_Expr_Extension_Operands (T : in out Fixture);
   procedure Test_Find_Exec_Batches (T : in out Fixture);
   procedure Test_Find_Missing_Operands (T : in out Fixture);
   procedure Test_Find_Symbolic_Links (T : in out Fixture);
   procedure Test_Printf_Character_Conversion (T : in out Fixture);
   procedure Test_Printf_Escapes (T : in out Fixture);
   procedure Test_Printf_Extension_Operands (T : in out Fixture);
   procedure Test_Printf_Numeric_Arguments (T : in out Fixture);
   procedure Test_Test_Argument_Counts (T : in out Fixture);
   procedure Test_Test_Extension_Operands (T : in out Fixture);
   procedure Test_Test_Integer_Operands (T : in out Fixture);
end Command_Tests.Scripting;
