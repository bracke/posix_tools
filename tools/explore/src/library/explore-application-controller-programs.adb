with Explore.Application.Terminals;
with Explore.Files;
with Explore.Launch;
with Explore.Model;
with Explore.Paths;
with Explore.Previews;
with Explore.String_Vectors;
with Explore.Words;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Processes;

package body Explore.Application.Controller.Programs is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;

   use type FS.File_Kind;

   --  Whether the file at Path is text, as its start says.
   function Is_Text (State : Session; Path : String) return Boolean;

   --  Write Targets down for the program explore chooses files for, and quit.
   procedure Write_Choice (State : in out Session; Targets : Explore.String_Vectors.Vector);

   function Is_Text (State : Session; Path : String) return Boolean is
      pragma Unreferenced (State);

      Head : Unbounded.Unbounded_String;
      Read : Boolean;
   begin
      --  Only a plain file is looked into: reading a pipe or a device could
      --  wait for ever, and this is the screen's own thread.
      if FS.Kind (Path) = FS.Special_File then
         return False;
      end if;

      Explore.Files.Read_Head (Path, 4096, Head, Read);
      return Read and then Explore.Previews.Is_Text (Unbounded.To_String (Head));
   end Is_Text;
   procedure Open_Targets (State : in out Session) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
      Targets : constant Explore.String_Vectors.Vector := Model.Targets (State.Browser);
   begin
      if Targets.Is_Empty then
         return;
      elsif Unbounded.Length (State.Config.Chooser_File) > 0 then
         Write_Choice (State, Targets);
         return;
      end if;

      declare
         First  : constant String := Targets.First_Element;
         Opener : constant Explore.Launch.Opener :=
           Explore.Launch.Opener_For (State.Config.Openers, Explore.Paths.Name_Of (First), Is_Text (State, First));
      begin
         Run_Program
           (State,
            Explore.Launch.Shell_Arguments
              (Unbounded.To_String (Current.Path), Unbounded.To_String (Opener.Run), Targets, Opener.Detach),
            Detach => Opener.Detach,
            Pause  => False);
      end;

      Model.Clear_Marks (State.Browser);
   end Open_Targets;

   procedure Run_Program
     (State     : in out Session;
      Arguments : Posix_Tools.Arguments.Vector;
      Detach    : Boolean;
      Pause     : Boolean)
   is
      Status : Integer;
      Ran    : Boolean;
   begin
      if Detach then
         Ran := Posix_Tools.Host_Adapters.Processes.Run (Explore.Launch.Shell, Arguments, Status);
      else
         declare
            Kept : Explore.Application.Terminals.Program_Dispositions;
            Ok   : Boolean;
         begin
            Explore.Application.Terminals.Suspend (State, Kept, Ok);

            if not Ok then
               return;
            end if;

            Ran := Posix_Tools.Host_Adapters.Processes.Run (Explore.Launch.Shell, Arguments, Status);

            if Pause then
               Explore.Application.Terminals.Wait_For_Enter (State);
            end if;

            Explore.Application.Terminals.Resume (State, Kept, Ok);

            if not Ok then
               return;
            end if;
         end;
      end if;

      --  A shell that a signal ended, or that could not be started, has no
      --  status of its own to report.
      if not Ran then
         Warn (State, Unbounded.To_String (State.Config.Words.Cannot_Run));
      elsif Status /= 0 then
         Warn (State, Explore.Words.Exit_Line (State.Config.Words, Natural'Max (0, Status)));
      end if;

      Model.Reload_All (State.Browser);
      State.Dirty := True;
   end Run_Program;

   procedure Write_Choice (State : in out Session; Targets : Explore.String_Vectors.Vector) is
      File : constant String := Unbounded.To_String (State.Config.Chooser_File);
      Text : Unbounded.Unbounded_String;
      Ok   : Boolean;
   begin
      for Path of Targets loop
         Unbounded.Append (Text, Path & Character'Val (10));
      end loop;

      FS.Write_File (File, Unbounded.To_String (Text), False, Ok);

      if Ok then
         State.Quit := True;
      else
         Complain (State, File, Posix_Tools.File_Operations.Cannot_Open);
      end if;
   end Write_Choice;
end Explore.Application.Controller.Programs;
