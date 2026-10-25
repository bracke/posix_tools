with Ada.Streams;
with Explore.Application.Display;
with Explore.Image_Cache;
with Explore.Images;
with Explore.Input;
with Explore.Protocol;

package body Explore.Application.Terminals is
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Explore.Input.Event_Kind;
   use type Signals.Disposition;
   use type Terminal_IO.Read_Outcome;

   Ending_Signals : constant Signal_List := [Signals.Terminate_Signal, Signals.Hangup];

   --  How long the terminal has to answer the identity query.
   Handshake_Reads   : constant := 10;
   Handshake_Read_Ms : constant := 50;

   --  Measure the screen and draw for its size; when it cannot be measured,
   --  for the size last known, if Anyway.
   procedure Fit_To_Window (State : in out Session; Anyway : Boolean);

   --  Have Which recorded instead of acting, saving how each was in Saved and
   --  forgetting any arrival recorded before. With Spare_Ignored, one that
   --  is ignored stays ignored.
   procedure Record_Signals (Which : Signal_List; Saved : out Disposition_List; Spare_Ignored : Boolean)
     with Pre => Saved'Length = Which'Length and then Saved'First = Which'First;

   --  Put Which back as Saved says they were, forgetting what arrived
   --  meanwhile. One whose disposition could not be read, or cannot be put
   --  back, is left recording, which is harmless once nobody looks.
   procedure Restore_Signals (Which : Signal_List; Saved : Disposition_List)
     with Pre => Saved'Length = Which'Length and then Saved'First = Which'First;

   function Enter_Screen return Boolean is (Write (Explore.Protocol.Enter_Screen));

   procedure Fit_To_Window (State : in out Session; Anyway : Boolean) is
      Measured : Terminal_IO.Window_Size;
   begin
      if Terminal_IO.Size (Measured) then
         Explore.Application.Display.Resize (State, Measured.Rows, Measured.Columns);
      elsif Anyway then
         Explore.Application.Display.Resize (State, State.Terminal.Size.Rows, State.Terminal.Size.Columns);
      end if;
   end Fit_To_Window;

   procedure Give_Back_Signals (Saved : Session_Dispositions) is
   begin
      Restore_Signals (Session_Signals, Saved);
   end Give_Back_Signals;

   procedure Hand_Back (State : Session; Entered : Boolean; Saved : Session_Dispositions) is
   begin
      if Entered then
         declare
            --  A terminal that no longer takes output can still have its
            --  settings restored.
            Written : constant Boolean := Leave_Screen (State);
            pragma Unreferenced (Written);
         begin
            null;
         end;
      end if;

      Terminal_IO.Restore (State.Terminal.Saved_Mode);
      Give_Back_Signals (Saved);
   end Hand_Back;

   function Identify (State : in out Session) return Boolean is
      Item       : Explore.Input.Event;
      Found      : Boolean;
      Ended      : Boolean;
      Identified : Boolean := False;
   begin
      if not Write (Explore.Protocol.Identity_Query (State.Terminal.In_Tmux)) then
         return False;
      end if;

      for Attempt in 1 .. Handshake_Reads loop
         Read_Into_Decoder (State, Handshake_Read_Ms, Ended);

         if Ended then
            return False;
         end if;

         loop
            Explore.Input.Next (State.Terminal.Decoder, Item, Found);
            exit when not Found;

            if Item.Kind = Explore.Input.Reply_Event then
               case Item.Reply is
                  when Explore.Input.Identity_Reply =>
                     Explore.Protocol.Parse_Identity
                       (Unbounded.To_String (Item.Payload), State.Terminal.Identity, Identified);
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

   function Leave_Screen (State : Session) return Boolean is
     (Write
        ((if State.Terminal.Identity.Capabilities (Explore.Protocol.Kitty_Graphics)
          then Explore.Images.Delete_All (State.Terminal.In_Tmux) else "")
         & Explore.Protocol.Leave_Screen));

   procedure Read_Into_Decoder (State : in out Session; Timeout_Ms : Integer; Ended : out Boolean) is
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Terminal_IO.Read_Outcome;
   begin
      Terminal_IO.Read (Buffer, Last, Timeout_Ms, Outcome);
      Ended := Outcome = Terminal_IO.Read_End_Of_File or else Outcome = Terminal_IO.Read_Failed;

      if Outcome = Terminal_IO.Read_Failed then
         State.Terminal_Lost := True;
      end if;

      if Outcome = Terminal_IO.Read_Data then
         declare
            Text : String (1 .. Natural (Last));
         begin
            for I in Text'Range loop
               Text (I) := Character'Val (Buffer (Ada.Streams.Stream_Element_Offset (I)));
            end loop;

            Explore.Input.Feed (State.Terminal.Decoder, Text);
         end;
      elsif Outcome = Terminal_IO.Read_Timeout then
         Explore.Input.Flush (State.Terminal.Decoder);
      end if;
   end Read_Into_Decoder;

   procedure Record_Signals (Which : Signal_List; Saved : out Disposition_List; Spare_Ignored : Boolean) is
   begin
      for I in Which'Range loop
         if not Signals.Current_Disposition (Which (I), Saved (I)) then
            Saved (I) := Signals.Unknown_Disposition;
         end if;

         if not (Spare_Ignored and then Saved (I) = Signals.Ignore_Disposition)
           and then Signals.Can_Record (Which (I))
           and then Signals.Set_Disposition (Which (I), Signals.Record_Disposition)
         then
            declare
               --  An arrival recorded earlier is not this recording's.
               Stale : constant Boolean := Signals.Take (Which (I));
               pragma Unreferenced (Stale);
            begin
               null;
            end;
         end if;
      end loop;
   end Record_Signals;

   procedure Restore_Signals (Which : Signal_List; Saved : Disposition_List) is
      Ignored : Boolean;
   begin
      for I in Which'Range loop
         Ignored := Signals.Take (Which (I));

         if Saved (I) /= Signals.Unknown_Disposition then
            Ignored := Signals.Set_Disposition (Which (I), Saved (I));
         end if;
      end loop;
   end Restore_Signals;

   procedure Resume (State : in out Session; Kept : Program_Dispositions; Ok : out Boolean) is
      Scratch : Terminal_IO.Saved_Mode;
   begin
      Restore_Signals (Program_Signals, Kept);
      Ok := Terminal_IO.Enter_Raw (Scratch) and then Enter_Screen;

      if not Ok then
         Lose_Terminal (State);
         return;
      end if;

      --  The program may have used the screen and its images; both are made
      --  again from nothing.
      Explore.Image_Cache.Clear (State.Terminal.Images);
      Explore.Input.Flush (State.Terminal.Decoder);
      Fit_To_Window (State, Anyway => True);
   end Resume;

   procedure Suspend (State : in out Session; Kept : out Program_Dispositions; Ok : out Boolean) is
   begin
      Kept := [others => Signals.Unknown_Disposition];
      Ok := Leave_Screen (State);

      if not Ok then
         Lose_Terminal (State);
         return;
      end if;

      Terminal_IO.Restore (State.Terminal.Saved_Mode);

      --  The keyboard's interrupt and quit are the program's: explore notes
      --  them and carries on, and the program, whose recorded signals start
      --  out at their defaults, gets them as usual.
      Record_Signals (Program_Signals, Kept, Spare_Ignored => False);
   end Suspend;

   procedure Take_Signals (Saved : out Session_Dispositions) is
   begin
      --  A terminate or hangup the session was started ignoring stays
      --  ignored, as nohup intends.
      Record_Signals (Session_Signals, Saved, Spare_Ignored => True);
   end Take_Signals;

   procedure Wait_For_Enter (State : Session) is
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last    : Ada.Streams.Stream_Element_Offset;
      Outcome : Terminal_IO.Read_Outcome;
   begin
      if Write
          (Character'Val (10) & "[" & Unbounded.To_String (State.Config.Words.Press_Enter) & "]" & Character'Val (10))
      then
         loop
            Terminal_IO.Read (Buffer, Last, -1, Outcome);
            exit when Outcome /= Terminal_IO.Read_Data
              or else (for some I in Buffer'First .. Last => Buffer (I) = 10);
         end loop;
      end if;
   end Wait_For_Enter;

   procedure Watch_Signals (State : in out Session; Ended : out Boolean) is
   begin
      Ended := False;

      for Item of Ending_Signals loop
         if Signals.Take (Item) then
            State.Ended_By := Item;
            State.Signalled := True;
            Ended := True;
            return;
         end if;
      end loop;

      if Signals.Take (Signals.Window_Change) then
         Fit_To_Window (State, Anyway => False);
      end if;
   end Watch_Signals;
end Explore.Application.Terminals;
