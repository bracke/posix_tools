with Ada.Streams;
with Ada.Strings.Unbounded;
with Explore.Input;
with Explore.Protocol;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Host_Adapters.Terminal_IO;
with Posix_Tools.Localization;

package body Explore.Application is

   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Signals renames Posix_Tools.Host_Adapters.Signals;
   package Terminal_IO renames Posix_Tools.Host_Adapters.Terminal_IO;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;
   use type FS.File_Kind;
   use type Signals.Disposition;
   use type Explore.Input.Event_Kind;
   use type Explore.Input.Reply_Kind;
   use type Terminal_IO.Read_Outcome;

   --  How long one read waits before the loop looks at signals again, and how
   --  long a lone ESC waits for the rest of a sequence.
   Poll_Interval_Ms : constant := 100;

   --  How long the terminal has to answer the identity query.
   Handshake_Reads   : constant := 10;
   Handshake_Read_Ms : constant := 50;

   --  The signals a session takes over: the two that end it, and the resize
   --  notice for terminals that do not report sizes in band.
   type Watched_Signal is (Watch_Terminate, Watch_Hangup, Watch_Window_Change);

   Signal_Of : constant array (Watched_Signal) of Signals.Signal :=
     [Watch_Terminate     => Signals.Terminate_Signal,
      Watch_Hangup        => Signals.Hangup,
      Watch_Window_Change => Signals.Window_Change];

   Ending_Signals : constant array (Positive range <>) of Signals.Signal :=
     [Signals.Terminate_Signal, Signals.Hangup];

   type Saved_Dispositions is array (Watched_Signal) of Signals.Disposition;

   --  Interface text, looked up once: a catalog lookup reads the catalog.
   type Labels is record
      Quit_Hint : Unbounded.Unbounded_String;
   end record;

   type Session is record
      Directory : Unbounded.Unbounded_String;
      In_Tmux   : Boolean := False;
      Size      : Terminal_IO.Window_Size;
      Text      : Labels;
      Decoder   : Explore.Input.Decoder;
      Identity  : Explore.Protocol.Identity;
      Quit      : Boolean := False;
      --  The signal that ended the session, when one did.
      Ended_By  : Signals.Signal := Signals.Terminate_Signal;
      Signalled : Boolean := False;
      Dirty     : Boolean := True;
   end record;

   function Load_Labels (Locale : String) return Labels is
     ((Quit_Hint =>
         Unbounded.To_Unbounded_String
           (Posix_Tools.Localization.Text (Locale, "posix_tools.explore.ui.quit_hint", "q quit"))));

   function Write (Text : String) return Boolean renames Terminal_IO.Write;

   --  Take the terminal over, run the session, and give it back. Outcome says
   --  what went wrong, if anything, for the caller to report once the screen
   --  is the user's again.
   type Session_Outcome is (Session_Ended, Session_Signalled, Raw_Mode_Refused, Terminal_Unsupported, Output_Failed);

   procedure Draw (State : in out Session; Ok : out Boolean);

   function Fit (Text : String; Columns : Natural) return String;

   procedure Give_Back_Signals (Saved : Saved_Dispositions);

   procedure Handle (State : in out Session; Item : Explore.Input.Event);

   function Identify (State : in out Session) return Boolean;

   procedure Main_Loop (State : in out Session);

   function Padded (Text : String; Columns : Natural) return String;

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean);

   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome);

   procedure Take_Signals (Saved : out Saved_Dispositions);

   procedure Draw (State : in out Session; Ok : out Boolean) is
      Columns : constant Natural := State.Size.Columns;
      Frame   : Unbounded.Unbounded_String;
   begin
      Unbounded.Append (Frame, Explore.Protocol.Begin_Frame);
      Unbounded.Append (Frame, Explore.Protocol.Reset_Style & Explore.Protocol.Clear_Screen);
      Unbounded.Append (Frame, Explore.Protocol.Move_To (1, 1));
      Unbounded.Append
        (Frame,
         Explore.Protocol.Reverse_Video
         & Padded (" explore  " & Unbounded.To_String (State.Directory), Columns)
         & Explore.Protocol.Reset_Style);

      if State.Size.Rows >= 2 then
         Unbounded.Append (Frame, Explore.Protocol.Move_To (State.Size.Rows, 1));
         Unbounded.Append (Frame, Padded (" " & Unbounded.To_String (State.Text.Quit_Hint), Columns));
      end if;

      Unbounded.Append (Frame, Explore.Protocol.End_Frame);
      Ok := Write (Unbounded.To_String (Frame));
      State.Dirty := False;
   end Draw;

   --  The longest prefix of Text that fits in Columns cells, counting each
   --  character as one cell and never cutting a UTF-8 sequence.
   function Fit (Text : String; Columns : Natural) return String is
      Count : Natural := 0;
   begin
      for I in Text'Range loop
         if Character'Pos (Text (I)) not in 16#80# .. 16#BF# then
            if Count = Columns then
               return Text (Text'First .. I - 1);
            end if;

            Count := Count + 1;
         end if;
      end loop;

      return Text;
   end Fit;

   procedure Give_Back_Signals (Saved : Saved_Dispositions) is
   begin
      for Item in Watched_Signal loop
         if Saved (Item) /= Signals.Unknown_Disposition then
            declare
               --  A disposition that cannot be put back leaves the recording
               --  one, which is harmless once the session is over.
               Restored : constant Boolean := Signals.Set_Disposition (Signal_Of (Item), Saved (Item));
               pragma Unreferenced (Restored);
            begin
               null;
            end;
         end if;
      end loop;
   end Give_Back_Signals;

   procedure Handle (State : in out Session; Item : Explore.Input.Event) is
   begin
      case Item.Kind is
         when Explore.Input.Key_Event =>
            if Explore.Input.Is_Character (Item, 'q') then
               State.Quit := True;
            end if;
         when Explore.Input.Resize_Event =>
            if Item.Rows > 0 and then Item.Columns > 0 then
               State.Size := (Rows => Item.Rows, Columns => Item.Columns);
               State.Dirty := True;
            end if;
         when Explore.Input.Focus_Event =>
            State.Dirty := State.Dirty or else Item.Focused;
         when Explore.Input.Mouse_Event | Explore.Input.Paste_Event | Explore.Input.Reply_Event =>
            null;
      end case;
   end Handle;

   --  Ask the terminal who it is. True when it answered the private identity
   --  query before its device attributes, which every terminal answers.
   function Identify (State : in out Session) return Boolean is
      Item       : Explore.Input.Event;
      Found      : Boolean;
      Ended      : Boolean;
      Identified : Boolean := False;
   begin
      if not Write (Explore.Protocol.Identity_Query (State.In_Tmux)) then
         return False;
      end if;

      for Attempt in 1 .. Handshake_Reads loop
         Read_Into_Decoder (State, Handshake_Read_Ms, Ended);

         if Ended then
            return False;
         end if;

         loop
            Explore.Input.Next (State.Decoder, Item, Found);
            exit when not Found;

            if Item.Kind = Explore.Input.Reply_Event then
               case Item.Reply is
                  when Explore.Input.Identity_Reply =>
                     Explore.Protocol.Parse_Identity
                       (Unbounded.To_String (Item.Payload), State.Identity, Identified);
                  when Explore.Input.Device_Attributes_Reply =>
                     return Identified;
                  when Explore.Input.Version_Reply =>
                     null;
               end case;
            end if;
         end loop;
      end loop;

      return Identified;
   end Identify;

   procedure Main_Loop (State : in out Session) is
      Item  : Explore.Input.Event;
      Found : Boolean;
      Ended : Boolean;
      Ok    : Boolean;
   begin
      while not State.Quit loop
         for Ending of Ending_Signals loop
            if Signals.Take (Ending) then
               State.Ended_By := Ending;
               State.Signalled := True;
               return;
            end if;
         end loop;

         if Signals.Take (Signals.Window_Change) and then Terminal_IO.Size (State.Size) then
            State.Dirty := True;
         end if;

         if State.Dirty then
            Draw (State, Ok);

            if not Ok then
               return;
            end if;
         end if;

         Read_Into_Decoder (State, Poll_Interval_Ms, Ended);
         exit when Ended;

         loop
            Explore.Input.Next (State.Decoder, Item, Found);
            exit when not Found;
            Handle (State, Item);
         end loop;
      end loop;
   end Main_Loop;

   function Padded (Text : String; Columns : Natural) return String is
      Fitted : constant String := Fit (Text, Columns);
      Count  : Natural := 0;
   begin
      for C of Fitted loop
         if Character'Pos (C) not in 16#80# .. 16#BF# then
            Count := Count + 1;
         end if;
      end loop;

      return Fitted & [1 .. Columns - Count => ' '];
   end Padded;

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean) is
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Terminal_IO.Read_Outcome;
   begin
      Terminal_IO.Read (Buffer, Last, Timeout_Ms, Outcome);
      Ended := Outcome = Terminal_IO.Read_End_Of_File or else Outcome = Terminal_IO.Read_Failed;

      if Outcome = Terminal_IO.Read_Data then
         declare
            Text : String (1 .. Natural (Last));
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (Buffer (Ada.Streams.Stream_Element_Offset (I)));
            end loop;

            Explore.Input.Feed (State.Decoder, Text);
         end;
      elsif Outcome = Terminal_IO.Read_Timeout then
         Explore.Input.Flush (State.Decoder);
      end if;
   end Read_Into_Decoder;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      State     : Session;
      Directory : Unbounded.Unbounded_String;
      Outcome   : Session_Outcome;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Result.Status := Posix_Tools.Exit_Status.Success;

      for I in 1 .. Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (I);
         begin
            if Argument'Length > 1 and then Argument (Argument'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Argument & "'");
               return;
            elsif Unbounded.Length (Directory) > 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Argument & "'");
               return;
            end if;

            Directory := Unbounded.To_Unbounded_String (Argument);
         end;
      end loop;

      if Unbounded.Length (Directory) = 0 then
         Directory := Unbounded.To_Unbounded_String (Context.Physical_Current_Directory);
      end if;

      declare
         Path : constant String := Unbounded.To_String (Directory);
      begin
         if FS.Kind (Path) /= FS.Directory then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.explore.diagnostic.not_a_directory", "not a directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         State.Directory := Unbounded.To_Unbounded_String (FS.Real_Path (Path));
      end;

      if not Context.Standard_Input_Is_Terminal or else not Context.Standard_Output_Is_Terminal then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context,
            "posix_tools.explore.diagnostic.not_a_terminal",
            "standard input and standard output must be a terminal");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      State.In_Tmux := Context.Environment_Defined ("TMUX");
      State.Text := Load_Labels (Context.Effective_Locale);

      if not Terminal_IO.Size (State.Size) then
         State.Size := (Rows => 24, Columns => 80);
      end if;

      Run_Session (State, Outcome);

      case Outcome is
         when Session_Ended =>
            null;
         when Session_Signalled =>
            --  Reported the way a shell reports a program the signal ended.
            Result.Status := Posix_Tools.Exit_Status.Code (128 + Signals.Number (State.Ended_By));
         when Raw_Mode_Refused =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.explore.diagnostic.raw_mode_refused", "cannot put the terminal into raw mode");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         when Terminal_Unsupported =>
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context,
               "posix_tools.explore.diagnostic.unsupported_terminal",
               "this terminal did not identify itself as bracke-terminal, the only one explore runs in");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         when Output_Failed =>
            Context.Mark_Output_Failure;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end case;
   end Run;

   procedure Run_Session (State : in out Session; Outcome : out Session_Outcome) is
      Saved_Mode    : Terminal_IO.Saved_Mode;
      Saved_Signals : Saved_Dispositions;
      Entered       : Boolean := False;

      procedure Hand_Back;

      procedure Hand_Back is
      begin
         if Entered then
            declare
               --  A terminal that no longer takes output can still have its
               --  settings restored.
               Written : constant Boolean := Write (Explore.Protocol.Leave_Screen);
               pragma Unreferenced (Written);
            begin
               null;
            end;
         end if;

         Terminal_IO.Restore (Saved_Mode);
         Give_Back_Signals (Saved_Signals);
      end Hand_Back;
   begin
      Take_Signals (Saved_Signals);

      if not Terminal_IO.Enter_Raw (Saved_Mode) then
         Give_Back_Signals (Saved_Signals);
         Outcome := Raw_Mode_Refused;
         return;
      end if;

      if not Identify (State) then
         Hand_Back;
         Outcome := Terminal_Unsupported;
         return;
      end if;

      Entered := True;

      if not Write (Explore.Protocol.Enter_Screen) then
         Hand_Back;
         Outcome := Output_Failed;
         return;
      end if;

      Main_Loop (State);
      Hand_Back;
      Outcome := (if State.Signalled then Session_Signalled else Session_Ended);
   exception
      when others =>
         Hand_Back;
         raise;
   end Run_Session;

   procedure Take_Signals (Saved : out Saved_Dispositions) is
   begin
      for Item in Watched_Signal loop
         if not Signals.Current_Disposition (Signal_Of (Item), Saved (Item)) then
            Saved (Item) := Signals.Unknown_Disposition;
         end if;

         --  A terminate or hangup the session was started ignoring stays
         --  ignored, as nohup intends.
         if Saved (Item) /= Signals.Ignore_Disposition
           and then Signals.Can_Record (Signal_Of (Item))
           and then Signals.Set_Disposition (Signal_Of (Item), Signals.Record_Disposition)
         then
            declare
               --  An arrival recorded by an earlier session is not this one's.
               Stale : constant Boolean := Signals.Take (Signal_Of (Item));
               pragma Unreferenced (Stale);
            begin
               null;
            end;
         end if;
      end loop;
   end Take_Signals;

end Explore.Application;
