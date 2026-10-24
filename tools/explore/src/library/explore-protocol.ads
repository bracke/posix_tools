--  What explore says to the terminal, and what the terminal's answers mean.
--
--  Everything here is pure text: the sequences are built and parsed, never
--  written or read, so that the protocol can be checked without a terminal.
--
--  The identity contract with bracke-terminal is a private OSC: explore sends
--  "OSC 7701 ; q ST" and the terminal answers "OSC 7701 ; v=<n> ; caps=<list>
--  ST", where <list> is comma-separated capability names. Unknown names and
--  unknown keys are ignored, so either side can grow without breaking the
--  other. A terminal that does not answer is not bracke-terminal.
--
--  Inside tmux, sequences that must reach the outer terminal are wrapped in
--  tmux's DCS passthrough, which needs "set -g allow-passthrough on".
package Explore.Protocol is
   pragma Pure;

   Protocol_Version : constant := 1;

   --  The private OSC number that carries the identity exchange.
   Identity_OSC : constant String := "7701";

   type Capability is
     (Kitty_Graphics,
      Kitty_Graphics_Shared_Memory,
      Kitty_Graphics_JPEG,
      Kitty_Graphics_GIF,
      Kitty_Keyboard,
      Resize_Reports,
      Clipboard);

   type Capability_Set is array (Capability) of Boolean;

   No_Capabilities : constant Capability_Set := [others => False];

   type Identity is record
      Version      : Natural := 0;
      Capabilities : Capability_Set := No_Capabilities;
   end record;

   --  The name a capability goes by on the wire.
   function Capability_Name (Item : Capability) return String;

   --  Parse the body of an identity reply: what follows "7701;" up to the
   --  terminator. Valid is False when the body has no usable version.
   procedure Parse_Identity
     (Body_Text : String;
      Result    : out Identity;
      Valid     : out Boolean);

   --  Wrap Sequence so that tmux hands it to the outer terminal unchanged.
   function Passthrough (Sequence : String) return String;

   --  Pass Sequence through tmux when In_Tmux, and unchanged otherwise.
   function To_Outer_Terminal (Sequence : String; In_Tmux : Boolean) return String;

   --  The identity query followed by a primary device attributes request.
   --  Every terminal answers the latter, so its reply arriving first means the
   --  identity query went unanswered.
   function Identity_Query (In_Tmux : Boolean) return String;

   --  Enter the alternate screen and turn on the input reports explore reads:
   --  SGR mouse, focus, bracketed paste, in-band resize and disambiguated keys.
   function Enter_Screen return String;

   --  Undo Enter_Screen, in reverse order.
   function Leave_Screen return String;

   --  Bracket one frame's output so that the terminal shows it at once.
   function Begin_Frame return String;
   function End_Frame return String;

   --  Move the cursor to a one-based row and column.
   function Move_To (Row, Column : Positive) return String;

   function Clear_Screen return String;
   function Reset_Style return String;
   function Reverse_Video return String;
end Explore.Protocol;
