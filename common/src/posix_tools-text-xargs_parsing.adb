with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Xargs_Parsing is
   use Ada.Strings.Unbounded;

   LF  : constant Character := Character'Val (10);
   NUL : constant Character := Character'Val (0);

   procedure Complete_Item
     (State : in out Parser;
      Items : in out Posix_Tools.Arguments.Vector;
      Keep_Empty : Boolean := False);

   procedure Complete_Item
     (State : in out Parser;
      Items : in out Posix_Tools.Arguments.Vector;
      Keep_Empty : Boolean := False)
   is
      Text : constant String := To_String (State.Current);
   begin
      if not State.Item_Started and then not Keep_Empty then
         return;
      end if;
      if State.Has_Eof_Marker and then Text = To_String (State.Eof_Marker) then
         State.Stopped := True;
      else
         Items.Append (Text);
      end if;
      State.Current := Null_Unbounded_String;
      State.Item_Started := False;
   end Complete_Item;

   procedure Initialize
     (State            : out Parser;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String) is
   begin
      State :=
        (Mode =>
           (if Null_Delimited then Null_Mode
            elsif Replacement_Mode then Line_Mode
            else Blank_Mode),
         Eof_Marker => To_Unbounded_String (Eof_Marker),
         Has_Eof_Marker => Has_Eof_Marker,
         others => <>);
   end Initialize;

   procedure Feed (State : in out Parser; Data : String; Result : out Parse_Result) is
   begin
      Result := (others => <>);
      if State.Stopped then
         return;
      end if;

      for Ch of Data loop
         exit when State.Stopped;
         case State.Mode is
            when Null_Mode =>
               if Ch = NUL then
                  Complete_Item (State, Result.Items, Keep_Empty => True);
               else
                  Append (State.Current, Ch);
                  State.Item_Started := True;
               end if;

            when Line_Mode =>
               if Ch = LF then
                  Complete_Item (State, Result.Items);
               else
                  Append (State.Current, Ch);
                  State.Item_Started := True;
               end if;

            when Blank_Mode =>
               case State.Quote is
                  when Unquoted =>
                     if Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Ch) then
                        Complete_Item (State, Result.Items);
                     elsif Ch = Character'Val (39) then
                        State.Quote := Single_Quoted;
                        State.Item_Started := True;
                     elsif Ch = Character'Val (34) then
                        State.Quote := Double_Quoted;
                        State.Item_Started := True;
                     elsif Ch = '\' then
                        State.Quote := Escaped;
                        State.Item_Started := True;
                     else
                        Append (State.Current, Ch);
                        State.Item_Started := True;
                     end if;
                  when Single_Quoted =>
                     if Ch = Character'Val (39) then
                        State.Quote := Unquoted;
                     else
                        Append (State.Current, Ch);
                     end if;
                  when Double_Quoted =>
                     if Ch = Character'Val (34) then
                        State.Quote := Unquoted;
                     elsif Ch = '\' then
                        State.Quote := Double_Escaped;
                     else
                        Append (State.Current, Ch);
                     end if;
                  when Escaped =>
                     Append (State.Current, Ch);
                     State.Quote := Unquoted;
                  when Double_Escaped =>
                     Append (State.Current, Ch);
                     State.Quote := Double_Quoted;
               end case;
         end case;
      end loop;
   end Feed;

   procedure Finish (State : in out Parser; Result : out Parse_Result) is
   begin
      Result := (others => <>);
      if State.Stopped then
         return;
      end if;
      case State.Quote is
         when Single_Quoted =>
            Result.Status := Unmatched_Single_Quote;
         when Double_Quoted | Double_Escaped =>
            Result.Status := Unmatched_Double_Quote;
         when Escaped =>
            Result.Status := Unfinished_Escape;
         when Unquoted =>
            Complete_Item (State, Result.Items);
      end case;
   end Finish;

   function Is_Stopped (State : Parser) return Boolean is (State.Stopped);

   function Parse_Input
     (Data             : String;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String) return Parse_Result
   is
      State : Parser;
      Fed   : Parse_Result;
      Final : Parse_Result;
   begin
      Initialize
        (State, Null_Delimited, Replacement_Mode, Has_Eof_Marker, Eof_Marker);
      Feed (State, Data, Fed);
      Finish (State, Final);
      Fed.Status := Final.Status;
      Fed.Items.Append (Final.Items);
      return Fed;
   end Parse_Input;
end Posix_Tools.Text.Xargs_Parsing;
