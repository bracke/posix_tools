package body Posix_Tools.Rg_Parallel
  with SPARK_Mode => On
is
   function Bounded_Worker_Count
     (Requested : Natural;
      Sorted    : Boolean) return Positive is
     (if Sorted
      then 1
      else Natural'Min (Max_Workers, Natural'Max (1, Requested)));

   function Create (Job_Count : Natural) return Queue_State is
     (Jobs      => Job_Count,
      Next      => (if Job_Count = 0 then 0 else 1),
      Exhausted => Job_Count = 0,
      Cancelled => False);

   function Job_Count (State : Queue_State) return Natural is
     (State.Jobs);

   function Is_Exhausted (State : Queue_State) return Boolean is
     (State.Exhausted);

   function Is_Cancelled (State : Queue_State) return Boolean is
     (State.Cancelled);

   procedure Take
     (State     : in out Queue_State;
      Index     : out Natural;
      Available : out Boolean)
   is
   begin
      if State.Exhausted then
         Index := 0;
         Available := False;
      else
         Index := State.Next;
         Available := True;
         if State.Next = State.Jobs then
            State.Exhausted := True;
         else
            State.Next := State.Next + 1;
         end if;
      end if;
   end Take;

   procedure Cancel (State : in out Queue_State) is
   begin
      State.Cancelled := True;
   end Cancel;
end Posix_Tools.Rg_Parallel;
