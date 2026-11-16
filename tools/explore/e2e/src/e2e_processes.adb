with Ada.Containers.Vectors;
with Ada.Finalization;
with Ada.Strings.Unbounded;
with Hostkit;
with Hostkit.Signals;
with Hostkit.Spawn;
with Hostkit.Spawn.Supervision;

package body E2E_Processes is
   use type Hostkit.Spawn.Process_Handle;

   package Process_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Hostkit.Spawn.Process_Handle);

   protected Deferred_Children is
      procedure Adopt (Child : Hostkit.Spawn.Process_Handle);
      procedure Take_All (Items : in out Process_Vectors.Vector);
   private
      Children : Process_Vectors.Vector;
   end Deferred_Children;

   protected body Deferred_Children is
      procedure Adopt (Child : Hostkit.Spawn.Process_Handle) is
      begin
         if Hostkit.Spawn.Is_Valid (Child) then
            Children.Append (Child);
         end if;
      end Adopt;

      procedure Take_All (Items : in out Process_Vectors.Vector) is
      begin
         Items.Clear;
         Process_Vectors.Move (Items, Children);
      end Take_All;
   end Deferred_Children;

   procedure Reap_Deferred;

   type Reaper_Guard is new Ada.Finalization.Limited_Controlled with null record;
   overriding procedure Finalize (Self : in out Reaper_Guard);

   overriding procedure Finalize (Self : in out Reaper_Guard) is
      pragma Unreferenced (Self);
   begin
      Reap_Deferred;
   exception
      when others =>
         --  intentional terminal exception barrier
         --  Package finalization must not mask the active program exception.
         null;
   end Finalize;

   procedure Reap_Deferred is
      Children : Process_Vectors.Vector;
      Result   : Hostkit.Spawn.Status;
   begin
      Deferred_Children.Take_All (Children);
      for Item of Children loop
         declare
            Child : Hostkit.Spawn.Process_Handle := Item;
         begin
            if Hostkit.Spawn.Supervision.Has_Ended (Child, Result) then
               Hostkit.Spawn.Release (Child);
            else
               Deferred_Children.Adopt (Child);
            end if;
         end;
      end loop;
   end Reap_Deferred;

   Reaper : Reaper_Guard;
   pragma Unreferenced (Reaper);

   function Run
     (Program    : String;
      Argument   : String;
      Timeout_Ms : Positive;
      Group      : Group_Policy := New_Process_Group) return Integer
   is
      use type Hostkit.Spawn.Spawn_Outcome;
      use type Hostkit.Spawn.Wait_State;

      Arguments : Hostkit.String_Vectors.Vector;
      Options   : Hostkit.Spawn.Options;
      Child     : Hostkit.Spawn.Process_Handle;
      Result    : Hostkit.Spawn.Status;
      Ended     : Boolean := False;
      Cleanup_Attempted : Boolean := False;

      function Stop_And_Reap return Boolean;

      function Stop_And_Reap return Boolean is
         Stop_Requested : Boolean;
      begin
         Cleanup_Attempted := True;
         Stop_Requested := False;
         if Group = New_Process_Group then
            Stop_Requested :=
              Hostkit.Signals.Send_To_Group
                (Hostkit.Spawn.Group_Id (Child),
                 Hostkit.Signals.Signal_Kill);
         end if;
         if not Stop_Requested then
            Stop_Requested := Hostkit.Spawn.Supervision.Stop_Now (Child);
         end if;

         for Attempt in 1 .. 500 loop
            Ended :=
              Hostkit.Spawn.Supervision.Has_Ended (Child, Result);
            exit when Ended;
            delay 0.01;
         end loop;

         if Ended then
            Hostkit.Spawn.Release (Child);
         else
            Deferred_Children.Adopt (Child);
            Child := Hostkit.Spawn.Invalid_Process;
         end if;

         --  A failed stop request can mean the process ended before the
         --  signal arrived; collection is the authoritative success test.
         return Ended;
      end Stop_And_Reap;
   begin
      Reap_Deferred;
      Arguments.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Argument));
      Options.Group :=
        (if Group = New_Process_Group
         then Hostkit.Spawn.Group_New
         else Hostkit.Spawn.Group_Inherit);

      if Hostkit.Spawn.Start (Program, Arguments, Options, Child)
        /= Hostkit.Spawn.Spawn_Ok
      then
         raise Program_Error with
           "could not start supervised E2E subprocess " & Program;
      end if;

      for Elapsed in 0 .. Timeout_Ms / 10 loop
         Ended := Hostkit.Spawn.Supervision.Has_Ended (Child, Result);
         exit when Ended;
         delay 0.01;
      end loop;

      if not Ended then
         if not Stop_And_Reap then
            raise Program_Error with
              "E2E subprocess exceeded its"
              & Positive'Image (Timeout_Ms)
              & " ms timeout and could not be terminated and reaped";
         end if;
         raise Program_Error with
           "E2E subprocess exceeded its"
           & Positive'Image (Timeout_Ms) & " ms timeout";
      end if;

      Hostkit.Spawn.Release (Child);
      if Result.State /= Hostkit.Spawn.Wait_Exited then
         raise Program_Error with
           "E2E subprocess ended as "
           & Hostkit.Spawn.Wait_State'Image (Result.State);
      end if;
      return Result.Exit_Code;
   exception
      when others =>
         --  intentional terminal exception barrier
         --  Attempt bounded cleanup before propagating a setup or status
         --  failure.  An uncollected child is reported instead of being
         --  hidden behind the original exception.
         if Hostkit.Spawn.Is_Valid (Child) and then not Cleanup_Attempted then
            if not Stop_And_Reap then
               raise Program_Error with
                 "E2E subprocess cleanup could not terminate and reap the child";
            end if;
         end if;
         raise;
   end Run;
end E2E_Processes;
