with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Terminal.Core;
with Terminal.PTY.Backend;

--  One explore session as a user would run it: the explore binary in a
--  pseudo-terminal, and on the other side bracke-terminal's emulator core
--  instead of its window. Whatever explore writes is fed to the core; the
--  core's answers -- to the identity query, the device attributes, size
--  reports -- are written back, so the handshake, resize reports, clipboard,
--  and graphics are the terminal's own. Tests read the screen from the
--  core's cells.
package E2E_Rig is
   type Rig is limited private;

   --  Start explore on Directory with Options before it, in a terminal of
   --  Rows by Columns cells of 10 by 20 pixels, its configuration and state
   --  directories empty fixtures of their own.
   procedure Start
     (Self      : in out Rig;
      Directory : String;
      Rows      : Positive := 24;
      Columns   : Positive := 100;
      Options   : String := "");

   --  Pass what is waiting between explore and the core, for about
   --  Milliseconds.
   procedure Pump (Self : in out Rig; Milliseconds : Natural);

   --  Pump until Text is on the screen, at most Timeout_Ms; whether it came.
   function Wait_For (Self : in out Rig; Text : String; Timeout_Ms : Natural := 5_000) return Boolean;

   --  Pump until row Row of the screen has Text in it.
   function Wait_For_Row
     (Self : in out Rig; Row : Positive; Text : String; Timeout_Ms : Natural := 5_000) return Boolean;

   --  Row N of the screen as text, trailing blanks dropped.
   function Row (Self : Rig; N : Positive) return String;

   --  The whole screen, a line per row, for a failed assertion to show.
   function Screen (Self : Rig) return String;

   --  Assert Condition, showing the screen with What when it fails. The
   --  screen is read here, after Condition was found -- in the arguments of
   --  one call, it might be read before the wait that Condition holds.
   procedure Expect (Self : Rig; Condition : Boolean; What : String);

   --  The cells holding image placeholders.
   function Placeholder_Cells (Self : Rig) return Natural;

   --  Type Keys, as the terminal would send them.
   procedure Send (Self : in out Rig; Keys : String);

   --  Resize the terminal and the pseudo-terminal, as a window resize does.
   --  Program_Error when either refuses, or the screen is not that size
   --  afterwards.
   procedure Resize (Self : in out Rig; Rows, Columns : Positive);

   --  When explore wrote its first byte, its handshake query: the moment it
   --  was running, after the system started it.
   function First_Output (Self : Rig) return Ada.Real_Time.Time;

   function Modes (Self : Rig) return Terminal.Core.Mode_Snapshot;

   --  What explore last put on the clipboard; empty when nothing.
   function Clipboard (Self : Rig) return String;

   --  The Kitty graphics commands explore sent, and the keys of the last.
   function Graphics_Count (Self : Rig) return Natural;
   function Last_Graphics (Self : Rig) return String;

   --  Pump until explore has ended, at most Timeout_Ms; Code is its exit
   --  status.
   procedure Wait_Exit (Self : in out Rig; Ended : out Boolean; Code : out Integer; Timeout_Ms : Natural := 5_000);

   procedure Stop (Self : in out Rig);

   --  A fresh, empty directory for one test's files, below the crate's obj.
   function Fixture (Name : String) return String;

   --  Write Text to the file at Path.
   procedure Write_File (Path, Text : String);

private
   type Rig is limited record
      Core      : Terminal.Core.Terminal;
      Session   : Terminal.PTY.Backend.Session;
      View      : Terminal.Core.Render_Snapshot;
      Running   : Boolean := False;
      Graphics  : Natural := 0;
      Last      : Ada.Strings.Unbounded.Unbounded_String;
      Clipped   : Ada.Strings.Unbounded.Unbounded_String;
      Spoke     : Boolean := False;
      Spoke_At  : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end record;
end E2E_Rig;
