with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Contexts;

package Posix_Tools.Commands.Find_Evaluation is
   type Evaluation_State is private;

   type Path_Result is record
      Matches : Boolean := False;
      Valid   : Boolean := True;
      Pruned  : Boolean := False;
   end record;

   procedure Initialize
     (State      : out Evaluation_State;
      Expression : Posix_Tools.Arguments.Vector);

   function Has_Depth (State : Evaluation_State) return Boolean;
   function Has_Xdev (State : Evaluation_State) return Boolean;

   procedure Evaluate_Path
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Result  : out Path_Result);

   procedure Flush_Exec_Batches
     (State   : in out Evaluation_State;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ok      : in out Boolean);

private
   type Find_Exec_Batch is record
      Start_Index : Positive := 1;
      Utility     : Ada.Strings.Unbounded.Unbounded_String;
      Prefix      : Posix_Tools.Arguments.Vector;
      Paths       : Posix_Tools.Arguments.Vector;
   end record;

   package Find_Exec_Batch_Vectors is new Ada.Containers.Vectors (Positive, Find_Exec_Batch);

   type Evaluation_State is record
      Expression   : Posix_Tools.Arguments.Vector;
      Exec_Batches : Find_Exec_Batch_Vectors.Vector;
      Depth        : Boolean := False;
      Xdev         : Boolean := False;
   end record;
end Posix_Tools.Commands.Find_Evaluation;
