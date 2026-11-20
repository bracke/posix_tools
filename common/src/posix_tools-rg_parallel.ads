--  Proved worker-count and protected-queue state transitions used by rg.
package Posix_Tools.Rg_Parallel
  with Pure,
       SPARK_Mode => On
is
   Max_Workers : constant Positive := 64;

   function Bounded_Worker_Count
     (Requested : Natural;
      Sorted    : Boolean) return Positive
     with Post => Bounded_Worker_Count'Result in 1 .. Max_Workers;

   type Queue_State is private;

   function Create (Job_Count : Natural) return Queue_State;
   function Job_Count (State : Queue_State) return Natural;
   function Is_Exhausted (State : Queue_State) return Boolean;
   function Is_Cancelled (State : Queue_State) return Boolean;

   procedure Take
     (State     : in out Queue_State;
      Index     : out Natural;
      Available : out Boolean)
     with Post =>
       Job_Count (State) = Job_Count (State)'Old
       and then
         (if Available
          then Index in 1 .. Job_Count (State)
          else Index = 0 and then Is_Exhausted (State));

   procedure Cancel (State : in out Queue_State)
     with Post => Is_Cancelled (State);
private
   type Queue_State is record
      Jobs       : Natural := 0;
      Next       : Natural := 0;
      Exhausted  : Boolean := True;
      Cancelled  : Boolean := False;
   end record
     with Dynamic_Predicate =>
       (if Queue_State.Exhausted
        then Queue_State.Next <= Queue_State.Jobs
        else Queue_State.Next in 1 .. Queue_State.Jobs);
end Posix_Tools.Rg_Parallel;
