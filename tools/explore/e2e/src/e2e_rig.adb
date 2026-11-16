with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with E2E_Bootstrap;
with E2E_Files;
with GNAT.OS_Lib;
with Terminal.Common;
with Terminal.Common.Bytes;

package body E2E_Rig is
   package Bytes renames Terminal.Common.Bytes;
   package Core renames Terminal.Core;
   package PTY renames Terminal.PTY.Backend;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Core.Cell_Kind;
   use type Core.Feed_Status;
   use type Core.Initialize_Status;
   use type PTY.Exit_State;
   use type PTY.Read_Status;
   use type PTY.Spawn_Status;
   use type PTY.Write_Status;

   LF : constant Character := Character'Val (10);

   Cell_Width  : constant := 10;
   Cell_Height : constant := 20;
   Launcher_Unavailable_Message : constant String :=
     "the E2E launcher is unavailable after an uncertain failure";

   --  Path with every symbolic link in it resolved, as explore shows paths.
   function Resolved (Path : String) return String is
     (GNAT.OS_Lib.Normalize_Pathname (Path, Resolve_Links => True));

   --  The PTY backend captures SHELL during elaboration, so every session
   --  enters through this immutable dispatcher.  Start serializes only the
   --  handoff of a private command file; the sessions themselves are
   --  independent afterwards.
   protected Session_Coordinator is
      procedure Complete_Launch (Safe_To_Continue : Boolean);
      procedure Next_Session (Number : out Positive);
      entry Reserve_Launch;
   private
      Launch_Reserved : Boolean := False;
      Launch_Poisoned : Boolean := False;
      Next_Number     : Natural := 0;
   end Session_Coordinator;

   protected body Session_Coordinator is
      procedure Complete_Launch (Safe_To_Continue : Boolean) is
      begin
         if not Safe_To_Continue then
            Launch_Poisoned := True;
         end if;
         Launch_Reserved := False;
      end Complete_Launch;

      procedure Next_Session (Number : out Positive) is
      begin
         if Launch_Poisoned then
            raise Program_Error with Launcher_Unavailable_Message;
         end if;
         if Next_Number = Natural (Positive'Last) then
            raise Program_Error with "too many E2E sessions";
         end if;
         Next_Number := Next_Number + 1;
         Number := Positive (Next_Number);
      end Next_Session;

      entry Reserve_Launch when not Launch_Reserved is
      begin
         if Launch_Poisoned then
            raise Program_Error with Launcher_Unavailable_Message;
         end if;
         Launch_Reserved := True;
      end Reserve_Launch;

   end Session_Coordinator;

   --  The explore this crate tests: the one its parent crate built.
   function Ends_With (Text, Suffix : String) return Boolean is
     (Text'Length >= Suffix'Length and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix);

   --  The UTF-8 encoding of Code.
   function UTF_8 (Code : Terminal.Common.Code_Point) return String;

   --  Hand everything the core has to say back to explore.
   procedure Answer (Self : in out Rig);

   --  The PTY backend reports a byte count, not the last index in Data.
   --  Keep the retry and error policy in one place for terminal answers and
   --  simulated user input alike.
   procedure Write_All
     (Self : in out Rig;
      Data : Bytes.Byte_Array);

   function Convention_For
     (State  : PTY.Exit_State;
      Status : Integer) return Exit_Status_Convention;

   procedure Answer (Self : in out Rig) is
      Buffer : Bytes.Byte_Array (1 .. 4096);
      Last   : Natural;
   begin
      while Core.Pending_Response_Length (Self.Core) > 0 loop
         Core.Read_Response (Self.Core, Buffer, Last);
         exit when Last < Buffer'First;
         Write_All (Self, Buffer (Buffer'First .. Last));
      end loop;

      while Core.Pending_Graphics_Event_Count (Self.Core) > 0 loop
         declare
            Event : Core.Graphics_Event;
         begin
            Core.Peek_Graphics_Event (Self.Core, Event);
            Self.Graphics := Self.Graphics + 1;
            Self.Last := Unbounded.To_Unbounded_String (Event.Preview (1 .. Event.Preview_Length));
            Core.Discard_Graphics_Event (Self.Core);
         end;
      end loop;

      declare
         Request : constant Core.Clipboard_Request := Core.Clipboard (Self.Core);
      begin
         if Request.Pending then
            Self.Clipped := Unbounded.To_Unbounded_String (Request.Text (1 .. Request.Length));
            Core.Clear_Clipboard (Self.Core);
         end if;
      end;
   end Answer;

   function Convention_For
     (State  : PTY.Exit_State;
      Status : Integer) return Exit_Status_Convention
   is
      Capabilities : constant PTY.Backend_Capabilities :=
        PTY.Capabilities;
   begin
      --  ConPTY always reports a decoded 32-bit process status.  On POSIX the
      --  two supported backend generations are distinguishable without
      --  guessing: decoded normal statuses fit in one byte, raw normal wait
      --  statuses do not; decoded signals are negative, raw signals are not.
      if Capabilities.Windows_ConPTY
        or else not Capabilities.POSIX_PTY
      then
         return Decoded_Status;
      elsif (State = PTY.Exited and then Status > 255)
        or else (State = PTY.Signaled and then Status >= 0)
      then
         return Raw_POSIX_Wait_Status;
      else
         return Decoded_Status;
      end if;
   end Convention_For;

   function Clipboard (Self : Rig) return String is (Unbounded.To_String (Self.Clipped));

   function Exit_Code
     (State  : PTY.Exit_State;
      Status : Integer;
      Convention : Exit_Status_Convention) return Integer
   is
   begin
      case State is
         when PTY.Exited =>
            return
              (if Convention = Raw_POSIX_Wait_Status
               then Status / 256 mod 256
               else Status);
         when PTY.Signaled =>
            return
              (if Convention = Raw_POSIX_Wait_Status
               then 128 + Status mod 128
               else 128 - Status);
         when others =>
            return -1;
      end case;
   end Exit_Code;

   procedure Expect (Self : Rig; Condition : Boolean; What : String) is
   begin
      if not Condition then
         AUnit.Assertions.Assert (False, What & ":" & Screen (Self));
      end if;
   end Expect;

   function Fixture (Name : String) return String is
      Path : constant String := E2E_Bootstrap.Run_Root & "/fixtures/" & Name;
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;

      Ada.Directories.Create_Path (Path);
      return Resolved (Path);
   end Fixture;

   function Header_Shows (Self : Rig; Path : String) return Boolean is
      Header   : constant String := Row (Self, 1);
      Ellipsis : constant String := Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#A6#);
      Lead     : constant String := " " & Ellipsis;
   begin
      if Header = " " & Path then
         return True;
      end if;

      --  Too long for the screen, the path keeps its end.
      return Header'Length > Lead'Length
        and then Header (Header'First .. Header'First + Lead'Length - 1) = Lead
        and then Ends_With (Path, Header (Header'First + Lead'Length .. Header'Last));
   end Header_Shows;

   function Kept_Fixture (Name : String) return String is
      Path : constant String :=
        E2E_Bootstrap.Crate_Root & "/obj/fixtures-kept/" & Name;
   begin
      Ada.Directories.Create_Path (Path);
      return Resolved (Path);
   end Kept_Fixture;

   function First_Output (Self : Rig) return Ada.Real_Time.Time is (Self.Spoke_At);

   function Graphics_Count (Self : Rig) return Natural is (Self.Graphics);

   function Last_Graphics (Self : Rig) return String is (Unbounded.To_String (Self.Last));

   function Modes (Self : Rig) return Core.Mode_Snapshot is (Core.Modes (Self.Core));

   function Placeholder_Cells (Self : Rig) return Natural is
      Count : Natural := 0;
   begin
      for R in 1 .. Self.View.Rows loop
         for C in 1 .. Self.View.Cols loop
            if Core.Cell_At (Self.View, R, C).Image.Is_Placeholder then
               Count := Count + 1;
            end if;
         end loop;
      end loop;

      return Count;
   end Placeholder_Cells;

   procedure Pump (Self : in out Rig; Milliseconds : Natural) is
      Buffer : Bytes.Byte_Array (1 .. 65_536);
      Count  : Natural;
      Status : PTY.Read_Status;
      Fed    : Core.Feed_Status;
      Rounds : constant Natural :=
        Natural'Max (1, (Milliseconds + 4) / 5);
   begin
      for Round in 1 .. Rounds loop
         loop
            PTY.Read (Self.Session, Buffer, Count, Status);
            case Status is
               when PTY.Would_Block | PTY.End_Of_File =>
                  exit;

               when PTY.Interrupted =>
                  --  Yield to the bounded outer loop.  Retrying here would
                  --  let a signal storm bypass Pump's requested duration.
                  exit;

               when PTY.Failed | PTY.Session_Closed =>
                  raise Program_Error with "pseudo-terminal read failed";

               when PTY.Ok =>
                  if Count = 0 then
                     exit;
                  elsif Count > Buffer'Length then
                     raise Program_Error with
                       "pseudo-terminal returned an invalid read count";
                  end if;

                  if not Self.Spoke then
                     Self.Spoke := True;
                     Self.Spoke_At := Ada.Real_Time.Clock;
                  end if;

                  Core.Feed
                    (Self.Core,
                     Buffer
                       (Buffer'First
                        .. Buffer'First + Count - 1),
                     Fed);
                  if Fed /= Core.Ok then
                     raise Program_Error with
                       "terminal parser failed: " & Core.Feed_Status'Image (Fed);
                  end if;
                  Answer (Self);
            end case;
         end loop;

         Answer (Self);

         if Milliseconds > 0 then
            delay 0.005;
         end if;
      end loop;

      Core.Snapshot (Self.Core, Self.View);
   end Pump;

   function Quoted (Text : String) return String is
     (E2E_Bootstrap.Quoted (Text));

   procedure Resize (Self : in out Rig; Rows, Columns : Positive) is
      use type Core.Resize_Status;
      use type PTY.Resize_Status;

      Sized    : Core.Resize_Status;
      Resized  : PTY.Resize_Status;
   begin
      Core.Resize (Self.Core, Rows, Columns, Sized);

      if Sized /= Core.Ok then
         raise Program_Error with "the terminal core refused the resize: " & Core.Resize_Status'Image (Sized);
      end if;

      Core.Set_Window_Pixel_Size (Self.Core, Columns * Cell_Width, Rows * Cell_Height);
      PTY.Resize (Self.Session, Rows, Columns, Resized);

      if Resized /= PTY.Ok then
         raise Program_Error with "the pseudo-terminal refused the resize: " & PTY.Resize_Status'Image (Resized);
      end if;

      Answer (Self);
      Core.Snapshot (Self.Core, Self.View);

      if Self.View.Rows /= Rows or else Self.View.Cols /= Columns then
         raise Program_Error with
           "the screen is" & Natural'Image (Self.View.Rows) & " by" & Natural'Image (Self.View.Cols)
           & " after resizing to" & Positive'Image (Rows) & " by" & Positive'Image (Columns);
      end if;
   end Resize;

   function Row (Self : Rig; N : Positive) return String is
      Result : Unbounded.Unbounded_String;
   begin
      if N > Self.View.Rows then
         return "";
      end if;

      for C in 1 .. Self.View.Cols loop
         declare
            Item : constant Core.Cell := Core.Cell_At (Self.View, N, C);
         begin
            case Item.Kind is
               when Core.Empty =>
                  Unbounded.Append (Result, ' ');
               when Core.Character =>
                  Unbounded.Append (Result, UTF_8 (Item.Text.Code_Point));
               when Core.Wide_Continuation =>
                  null;
            end case;
         end;
      end loop;

      return Ada.Strings.Fixed.Trim (Unbounded.To_String (Result), Ada.Strings.Right);
   end Row;

   function Screen (Self : Rig) return String is
      Result : Unbounded.Unbounded_String :=
        Unbounded.To_Unbounded_String
          (" (" & Natural'Image (Self.View.Rows) & " by" & Natural'Image (Self.View.Cols) & " cells)" & LF);
   begin
      for R in 1 .. Self.View.Rows loop
         Unbounded.Append (Result, "|" & Row (Self, R) & LF);
      end loop;

      return Unbounded.To_String (Result);
   end Screen;

   procedure Send (Self : in out Rig; Keys : String) is
      Data : Bytes.Byte_Array (1 .. Keys'Length);
   begin
      for I in Data'Range loop
         Data (I) := Bytes.Byte (Character'Pos (Keys (Keys'First + I - 1)));
      end loop;
      Write_All (Self, Data);
   end Send;

   procedure Start
     (Self                : in out Rig;
      Directory           : String;
      Rows                : Positive := 24;
      Columns             : Positive := 100;
      Options             : String := "";
      Temporary_Directory : String := "") is
   begin
      Start_With_Hook
        (Self, Directory, Rows, Columns, Options, Temporary_Directory);
   end Start;

   procedure Start_With_Hook
     (Self                : in out Rig;
      Directory           : String;
      Rows                : Positive := 24;
      Columns             : Positive := 100;
      Options             : String := "";
      Temporary_Directory : String := "";
      Claim_Attempts      : Positive := 500;
      On_Ready_To_Launch  : access procedure := null)
   is
      Launcher        : constant String := E2E_Bootstrap.Launcher_Path;
      Request         : constant String := E2E_Bootstrap.Request_Path;
      Number          : Positive := 1;
      Launch_Reserved : Boolean := False;
      Launcher_Started : Boolean := False;
      Core_Started    : Boolean := False;
      Started         : Core.Initialize_Status;
      Spawned         : PTY.Spawn_Status;

      procedure Cancel_Reservation (Safe_To_Continue : Boolean);
      procedure Finalize_Started_State_Safely (Succeeded : out Boolean);
      procedure Release_Reservation (Safe_To_Continue : Boolean := True);
      --  Make Name an empty directory.
      procedure Renew (Name : String);

      procedure Cancel_Reservation (Safe_To_Continue : Boolean) is
         Request_Deleted : Boolean := True;
      begin
         if Launch_Reserved then
            begin
               if Ada.Directories.Exists (Request) then
                  Ada.Directories.Delete_File (Request);
               end if;
            exception
               when others =>
                  --  intentional terminal exception barrier
                  Request_Deleted := False;
            end;
            Release_Reservation
              (Safe_To_Continue and then Request_Deleted);
         end if;
      end Cancel_Reservation;

      procedure Finalize_Started_State_Safely (Succeeded : out Boolean) is
      begin
         Succeeded := True;
         if Self.Running then
            Stop (Self);
         elsif Core_Started then
            Core.Finalize (Self.Core);
         end if;
      exception
         when others =>
            --  intentional terminal exception barrier
            --  Cleanup must not replace the startup failure being propagated.
            Succeeded := False;
      end Finalize_Started_State_Safely;

      procedure Release_Reservation (Safe_To_Continue : Boolean := True) is
      begin
         if Launch_Reserved then
            Session_Coordinator.Complete_Launch (Safe_To_Continue);
            Launch_Reserved := False;
         end if;
      end Release_Reservation;

      procedure Renew (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_Tree (Name);
         end if;

         Ada.Directories.Create_Path (Name);
      end Renew;
   begin
      if Self.Running then
         raise Program_Error with "the E2E rig is already running";
      end if;

      Session_Coordinator.Next_Session (Number);

      declare
         Root : constant String :=
           E2E_Bootstrap.Run_Root & "/sessions/"
           & Ada.Strings.Fixed.Trim
               (Positive'Image (Number), Ada.Strings.Both);
      begin
         Renew (Root & "/config");
         Renew (Root & "/state");

         --  explore draws on the alternate screen, which has no scrollback;
         --  the main screen's is kept small, as its cells are not.
         Core.Initialize
           (Self.Core, Rows, Columns,
            Scrollback_Limit => 100, Status => Started);

         if Started /= Core.Ok then
            raise Program_Error with "the terminal core did not start";
         end if;
         Core_Started := True;

         Core.Set_Cell_Pixel_Size (Self.Core, Cell_Width, Cell_Height);
         Core.Set_Window_Pixel_Size
           (Self.Core, Columns * Cell_Width, Rows * Cell_Height);
         Core.Set_Graphics_Capabilities
           (Self.Core,
            (Kitty_Direct_PNG => True,
             Kitty_Direct_RGBA => True,
             others => False));

         if On_Ready_To_Launch /= null then
            On_Ready_To_Launch.all;
         end if;

         Session_Coordinator.Reserve_Launch;
         Launch_Reserved := True;

         if not Ada.Directories.Exists (Launcher) then
            raise Program_Error with "the E2E launcher is missing";
         end if;

         E2E_Files.Write
           (Request,
            "#!/bin/sh" & LF
            & "unset TMUX" & LF
            & "export XDG_CONFIG_HOME=" & Quoted (Root & "/config")
            & " XDG_STATE_HOME=" & Quoted (Root & "/state") & LF
            & (if Temporary_Directory = ""
               then ""
               else "export TMPDIR=" & Quoted (Temporary_Directory) & LF)
            & "exec " & Quoted (E2E_Bootstrap.Explore_Binary) & " "
            & Options & " "
            & Quoted (Directory) & LF);

         PTY.Spawn_Default_Shell (Self.Session, Rows, Columns, Spawned);

         if Spawned /= PTY.Ok then
            raise Program_Error with
              "explore could not be started in a pseudo-terminal";
         end if;
         Self.Running := True;
         Launcher_Started := True;

         --  Spawn reports once the dispatcher has been executed.  Wait until
         --  it has claimed this request before another Start may publish one.
         for Attempt in 1 .. Claim_Attempts loop
            exit when not Ada.Directories.Exists (Request);
            delay 0.01;
         end loop;
         if Ada.Directories.Exists (Request) then
            raise Program_Error with
              "the E2E launcher did not claim its session command";
         end if;
      end;

      Release_Reservation;

      Self.Graphics := 0;
      Self.Last := Unbounded.Null_Unbounded_String;
      Self.Clipped := Unbounded.Null_Unbounded_String;
      Self.Spoke := False;
      Pump (Self, 5);
   exception
      when others =>
         declare
            Cleanup_Succeeded : Boolean;
         begin
            --  Keep the shared handoff reserved until a failed dispatcher has
            --  been quiesced.  Any post-spawn uncertainty poisons this process's
            --  coordinator so it cannot publish a request to a stale launcher.
            Finalize_Started_State_Safely (Cleanup_Succeeded);
            Cancel_Reservation
              (Cleanup_Succeeded and then not Launcher_Started);
            raise;
         end;
   end Start_With_Hook;

   procedure Stop (Self : in out Rig) is
      First_Failure : Ada.Exceptions.Exception_Occurrence;
      Failed        : Boolean := False;

      procedure Remember (Failure : Ada.Exceptions.Exception_Occurrence);

      procedure Remember (Failure : Ada.Exceptions.Exception_Occurrence) is
      begin
         if not Failed then
            Ada.Exceptions.Save_Occurrence (First_Failure, Failure);
            Failed := True;
         end if;
      end Remember;
   begin
      if Self.Running then
         begin
            PTY.Close (Self.Session);
         exception
            when Failure : others =>
               --  intentional terminal exception barrier
               Remember (Failure);
         end;

         begin
            Core.Release (Self.View);
         exception
            when Failure : others =>
               --  intentional terminal exception barrier
               Remember (Failure);
         end;

         begin
            Core.Finalize (Self.Core);
         exception
            when Failure : others =>
               --  intentional terminal exception barrier
               Remember (Failure);
         end;

         --  Every owned component has now had its cleanup attempt.  Do not
         --  repeat successfully completed stages if the caller catches the
         --  first failure and calls Stop again.
         Self.Running := False;

         if Failed then
            Ada.Exceptions.Reraise_Occurrence (First_Failure);
         end if;
      end if;
   end Stop;

   function UTF_8 (Code : Terminal.Common.Code_Point) return String is
      Value : constant Natural := Natural (Code);
   begin
      if Value < 16#80# then
         return [Character'Val (Value)];
      elsif Value < 16#800# then
         return [Character'Val (16#C0# + Value / 64), Character'Val (16#80# + Value mod 64)];
      elsif Value < 16#1_0000# then
         return
           [Character'Val (16#E0# + Value / 4096), Character'Val (16#80# + Value / 64 mod 64),
            Character'Val (16#80# + Value mod 64)];
      else
         return
           [Character'Val (16#F0# + Value / 262_144), Character'Val (16#80# + Value / 4096 mod 64),
            Character'Val (16#80# + Value / 64 mod 64), Character'Val (16#80# + Value mod 64)];
      end if;
   end UTF_8;

   procedure Wait_Exit (Self : in out Rig; Ended : out Boolean; Code : out Integer; Timeout_Ms : Natural := 5_000) is
      State : PTY.Exit_State := PTY.Still_Running;
   begin
      Code := -1;

      for Step in 0 .. Timeout_Ms / 10 loop
         Pump (Self, 10);
         State := PTY.Child_State (Self.Session);
         exit when State in PTY.Exited | PTY.Signaled;
      end loop;

      --  Whatever explore wrote last, as it left, reaches the core too.
      Pump (Self, 20);
      State := PTY.Child_State (Self.Session);
      Ended := State in PTY.Exited | PTY.Signaled;

      if State in PTY.Exited | PTY.Signaled then
         declare
            Status : constant Integer := PTY.Child_Status (Self.Session);
         begin
            Code := Exit_Code (State, Status, Convention_For (State, Status));
         end;
      end if;
   end Wait_Exit;

   function Wait_For (Self : in out Rig; Text : String; Timeout_Ms : Natural := 5_000) return Boolean is
   begin
      for Step in 0 .. Timeout_Ms / 10 loop
         if Ada.Strings.Fixed.Index (Screen (Self), Text) > 0 then
            return True;
         end if;

         Pump (Self, 10);
      end loop;

      return Ada.Strings.Fixed.Index (Screen (Self), Text) > 0;
   end Wait_For;

   function Wait_For_Header (Self : in out Rig; Suffix : String; Timeout_Ms : Natural := 5_000) return Boolean is
   begin
      for Step in 0 .. Timeout_Ms / 10 loop
         if Ends_With (Row (Self, 1), Suffix) then
            return True;
         end if;

         Pump (Self, 10);
      end loop;

      return Ends_With (Row (Self, 1), Suffix);
   end Wait_For_Header;

   function Wait_For_Row
     (Self : in out Rig; Row : Positive; Text : String; Timeout_Ms : Natural := 5_000) return Boolean is
   begin
      for Step in 0 .. Timeout_Ms / 10 loop
         if Ada.Strings.Fixed.Index (E2E_Rig.Row (Self, Row), Text) > 0 then
            return True;
         end if;

         Pump (Self, 10);
      end loop;

      return Ada.Strings.Fixed.Index (E2E_Rig.Row (Self, Row), Text) > 0;
   end Wait_For_Row;

   procedure Write_All
     (Self : in out Rig;
      Data : Bytes.Byte_Array)
   is
      First       : Positive := Data'First;
      Count       : Natural;
      Status      : PTY.Write_Status;
      Empty_Tries : Natural := 0;

      procedure Wait_To_Retry;

      procedure Wait_To_Retry is
      begin
         Empty_Tries := Empty_Tries + 1;
         if Empty_Tries > 5_000 then
            raise Program_Error with "pseudo-terminal write made no progress";
         end if;
         delay 0.001;
      end Wait_To_Retry;
   begin
      while First <= Data'Last loop
         PTY.Write (Self.Session, Data (First .. Data'Last), Count, Status);
         case Status is
            when PTY.Ok | PTY.Partial =>
               if Count > Data'Last - First + 1 then
                  raise Program_Error with "pseudo-terminal returned an invalid write count";
               elsif Count = 0 then
                  Wait_To_Retry;
               else
                  First := First + Count;
                  Empty_Tries := 0;
               end if;

            when PTY.Interrupted =>
               Wait_To_Retry;

            when PTY.Failed | PTY.Session_Closed =>
               raise Program_Error with "pseudo-terminal write failed";
         end case;
      end loop;
   end Write_All;

end E2E_Rig;
