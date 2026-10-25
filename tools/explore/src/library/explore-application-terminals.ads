with Explore.Application.Sessions;
with Posix_Tools.Host_Adapters.Signals;

--  The session's hold on the terminal: the signals it takes over, the
--  handshake that tells bracke-terminal from any other, reading what the
--  terminal sends, and taking the screen over and giving it back -- for good
--  at the end, or for a while to another program.
private package Explore.Application.Terminals is
   use Explore.Application.Sessions;

   package Signals renames Posix_Tools.Host_Adapters.Signals;

   type Signal_List is array (Positive range <>) of Signals.Signal;
   type Disposition_List is array (Positive range <>) of Signals.Disposition;

   --  The signals a session takes over: the two that end it, and the resize
   --  notice for terminals that do not report sizes in band.
   Session_Signals : constant Signal_List := [Signals.Terminate_Signal, Signals.Hangup, Signals.Window_Change];

   subtype Session_Dispositions is Disposition_List (Session_Signals'Range);

   --  The keyboard's interrupt and quit, which a program run in the terminal
   --  gets in its turn.
   Program_Signals : constant Signal_List := [Signals.Interrupt, Signals.Quit];

   subtype Program_Dispositions is Disposition_List (Program_Signals'Range);

   --  Record the session's signals instead of having them act, saving how
   --  they were for Give_Back_Signals.
   procedure Take_Signals (Saved : out Session_Dispositions);

   --  Put the session's signals back as Take_Signals found them.
   procedure Give_Back_Signals (Saved : Session_Dispositions);

   --  Ask the terminal who it is. True when it answered the private identity
   --  query before its device attributes, which every terminal answers.
   function Identify (State : in out Session) return Boolean;

   --  Wait up to Timeout_Ms for what the terminal sends, and hand it to the
   --  decoder; on a timeout, what the decoder holds is taken as complete.
   --  Ended when the terminal will send no more.
   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean);

   --  Whether a signal that ends the session arrived, noting which; a
   --  resize notice meanwhile has the screen measured again.
   procedure Watch_Signals (State : in out Session; Ended : out Boolean);

   --  Take the screen over, or give it back with any images freed. False
   --  when the terminal took no output.
   function Enter_Screen return Boolean;
   function Leave_Screen (State : Session) return Boolean;

   --  Hand the terminal back for good: its screen when it was taken over,
   --  its settings, and the session's signals.
   procedure Hand_Back (State : Session; Entered : Boolean; Saved : Session_Dispositions);

   --  Lend the terminal to another program: give the screen and the settings
   --  back, and let the keyboard's signals reach the program. Ok is False,
   --  and the session ends, when the terminal took no output.
   procedure Suspend (State : in out Session; Kept : out Program_Dispositions; Ok : out Boolean);

   --  Wait for Enter, after saying that it is waited for.
   procedure Wait_For_Enter (State : Session);

   --  Take the terminal back from the program, with the screen and its
   --  images made again from nothing. Ok is False, and the session ends,
   --  when the terminal cannot be had again.
   procedure Resume (State : in out Session; Kept : Program_Dispositions; Ok : out Boolean);
end Explore.Application.Terminals;
