with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with GNAT.OS_Lib;
with Terminal.Common;
with Terminal.Common.Bytes;

package body E2E_Rig is
   package Bytes renames Terminal.Common.Bytes;
   package Core renames Terminal.Core;
   package PTY renames Terminal.PTY.Backend;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Core.Cell_Kind;
   use type Core.Initialize_Status;
   use type PTY.Exit_State;
   use type PTY.Read_Status;
   use type PTY.Spawn_Status;

   LF : constant Character := Character'Val (10);

   Cell_Width  : constant := 10;
   Cell_Height : constant := 20;

   --  Where the rig keeps its launcher and the session's configuration and
   --  state directories.
   function Rig_Root return String is (Ada.Directories.Full_Name ("obj/rig"));

   --  The explore this crate tests: the one its parent crate built.
   function Explore_Binary return String is (Ada.Directories.Full_Name ("../bin/explore"));

   --  The UTF-8 encoding of Code.
   function UTF_8 (Code : Terminal.Common.Code_Point) return String;

   --  Hand everything the core has to say back to explore.
   procedure Answer (Self : in out Rig);

   procedure Answer (Self : in out Rig) is
      Buffer : Bytes.Byte_Array (1 .. 4096);
      Last   : Natural;
      Done   : Natural;
      Status : PTY.Write_Status;
   begin
      while Core.Pending_Response_Length (Self.Core) > 0 loop
         Core.Read_Response (Self.Core, Buffer, Last);
         exit when Last < Buffer'First;

         declare
            First : Positive := Buffer'First;
         begin
            while First <= Last loop
               PTY.Write (Self.Session, Buffer (First .. Last), Done, Status);
               exit when Done < First;
               First := Done + 1;
            end loop;
         end;
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

   function Clipboard (Self : Rig) return String is (Unbounded.To_String (Self.Clipped));

   procedure Expect (Self : Rig; Condition : Boolean; What : String) is
   begin
      if not Condition then
         AUnit.Assertions.Assert (False, What & ":" & Screen (Self));
      end if;
   end Expect;

   function Fixture (Name : String) return String is
      Path : constant String := Ada.Directories.Full_Name ("obj/fixtures/" & Name);
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;

      Ada.Directories.Create_Path (Path);
      return Path;
   end Fixture;

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
      Last   : Natural;
      Status : PTY.Read_Status;
      Fed    : Core.Feed_Status;
      Rounds : constant Natural := Natural'Max (1, Milliseconds / 5);
   begin
      for Round in 1 .. Rounds loop
         loop
            PTY.Read (Self.Session, Buffer, Last, Status);
            exit when Status /= PTY.Ok or else Last < Buffer'First;

            if not Self.Spoke then
               Self.Spoke := True;
               Self.Spoke_At := Ada.Real_Time.Clock;
            end if;

            Core.Feed (Self.Core, Buffer (Buffer'First .. Last), Fed);
            Answer (Self);
         end loop;

         Answer (Self);

         if Round < Rounds then
            delay 0.005;
         end if;
      end loop;

      Core.Snapshot (Self.Core, Self.View);
   end Pump;

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
      Data   : Bytes.Byte_Array (1 .. Keys'Length);
      Done   : Natural;
      Status : PTY.Write_Status;
      First  : Positive := 1;
   begin
      for I in Data'Range loop
         Data (I) := Bytes.Byte (Character'Pos (Keys (Keys'First + I - 1)));
      end loop;

      while First <= Data'Last loop
         PTY.Write (Self.Session, Data (First .. Data'Last), Done, Status);
         exit when Done < First;
         First := Done + 1;
      end loop;
   end Send;

   procedure Start
     (Self      : in out Rig;
      Directory : String;
      Rows      : Positive := 24;
      Columns   : Positive := 100;
      Options   : String := "")
   is
      Root     : constant String := Rig_Root;
      Launcher : constant String := Root & "/launch.sh";
      Started  : Core.Initialize_Status;
      Spawned  : PTY.Spawn_Status;

      --  Make Name an empty directory.
      procedure Renew (Name : String);

      procedure Renew (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_Tree (Name);
         end if;

         Ada.Directories.Create_Path (Name);
      end Renew;
   begin
      Renew (Root & "/config");
      Renew (Root & "/state");

      --  The pseudo-terminal runs SHELL; the launcher stands in for it.
      Write_File
        (Launcher,
         "#!/bin/sh" & LF
         & "unset TMUX" & LF
         & "export XDG_CONFIG_HOME='" & Root & "/config' XDG_STATE_HOME='" & Root & "/state'" & LF
         & "exec '" & Explore_Binary & "' " & Options & " '" & Directory & "'" & LF);
      GNAT.OS_Lib.Set_Executable (Launcher);

      --  explore draws on the alternate screen, which has no scrollback; the
      --  main screen's is kept small, as its cells are not.
      Core.Initialize (Self.Core, Rows, Columns, Scrollback_Limit => 100, Status => Started);

      if Started /= Core.Ok then
         raise Program_Error with "the terminal core did not start";
      end if;

      Core.Set_Cell_Pixel_Size (Self.Core, Cell_Width, Cell_Height);
      Core.Set_Window_Pixel_Size (Self.Core, Columns * Cell_Width, Rows * Cell_Height);
      Core.Set_Graphics_Capabilities
        (Self.Core, (Kitty_Direct_PNG => True, Kitty_Direct_RGBA => True, others => False));

      Ada.Environment_Variables.Set ("SHELL", Launcher);
      PTY.Spawn_Default_Shell (Self.Session, Rows, Columns, Spawned);

      if Spawned /= PTY.Ok then
         raise Program_Error with "explore could not be started in a pseudo-terminal";
      end if;

      Self.Running := True;
      Self.Graphics := 0;
      Self.Last := Unbounded.Null_Unbounded_String;
      Self.Clipped := Unbounded.Null_Unbounded_String;
      Self.Spoke := False;
      Pump (Self, 5);
   end Start;

   procedure Stop (Self : in out Rig) is
   begin
      if Self.Running then
         PTY.Close (Self.Session);
         Core.Release (Self.View);
         Core.Finalize (Self.Core);
         Self.Running := False;
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
      Ended := State in PTY.Exited | PTY.Signaled;

      if State = PTY.Exited then
         Code := PTY.Child_Status (Self.Session) / 256 mod 256;
      elsif State = PTY.Signaled then
         Code := 128 + PTY.Child_Status (Self.Session) mod 128;
      end if;
   end Wait_Exit;

   procedure Write_File (Path, Text : String) is
   begin
      declare
         Handle : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
         Count  : Integer;
      begin
         if Text'Length > 0 then
            Count := GNAT.OS_Lib.Write (Handle, Text'Address, Text'Length);

            if Count /= Text'Length then
               raise Program_Error with "could not write " & Path;
            end if;
         end if;

         GNAT.OS_Lib.Close (Handle);
      end;
   end Write_File;
end E2E_Rig;
