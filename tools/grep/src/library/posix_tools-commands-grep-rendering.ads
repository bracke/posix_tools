private with Ada.Strings.Unbounded;
with Greplib.Events;
with Posix_Tools.Commands.Contexts;

--  Writes greplib's search events to standard output as each one arrives:
--  selected and context lines with their prefixes, the "--" between
--  context groups, counts, and file names.
package Posix_Tools.Commands.Grep.Rendering is
   --  The name standard input is written as in output lines.
   Standard_Input_Label : constant String := "(standard input)";

   type Render_Settings is record
      --  Prefix each line or count with the name of its file.
      Prefix_File          : Boolean := False;
      Line_Number          : Boolean := False;
      Byte_Offset          : Boolean := False;
      Only_Matching        : Boolean := False;
      --  -L: name the files without a selected line rather than those with.
      List_Without_Matches : Boolean := False;
      --  Write each line as it is rendered rather than gathering a block:
      --  for a terminal, which shows the lines as they are found.
      Flush_Each_Record    : Boolean := False;
   end record;

   type Output_Sink (Context : not null access Posix_Tools.Commands.Contexts.Context'Class) is
     limited new Greplib.Events.Event_Sink with private;

   procedure Configure (Sink : in out Output_Sink; Settings : Render_Settings);

   --  Start the next search: its events name their file Label, or the path
   --  greplib reports when Label is empty. Context groups of different
   --  searches are never adjacent.
   procedure Begin_Search (Sink : in out Output_Sink; Label : String);

   --  Write whatever has been rendered but not yet written.
   procedure Flush (Sink : in out Output_Sink);

   --  Whether writing standard output failed; the sink then asks greplib
   --  to stop.
   function Output_Failed (Sink : Output_Sink) return Boolean;

   overriding procedure On_Event
     (Sink   : in out Output_Sink;
      Event  : Greplib.Events.Search_Event;
      Action : out Greplib.Events.Event_Action);

private
   type Output_Sink (Context : not null access Posix_Tools.Commands.Contexts.Context'Class) is
     limited new Greplib.Events.Event_Sink with record
      Settings      : Render_Settings;
      Label         : Ada.Strings.Unbounded.Unbounded_String;
      Pending       : Ada.Strings.Unbounded.Unbounded_String;
      Search_Number : Natural := 0;
      --  The context group last written: its search, source, and group.
      Group_Written : Boolean := False;
      Last_Search   : Natural := 0;
      Last_Source   : Greplib.Wide_Count := 0;
      Last_Group    : Greplib.Wide_Count := 0;
      Failed        : Boolean := False;
   end record;
end Posix_Tools.Commands.Grep.Rendering;
