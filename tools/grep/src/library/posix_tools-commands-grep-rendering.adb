with Greplib.Byte_Strings;
with Greplib.Paths;

package body Posix_Tools.Commands.Grep.Rendering is
   use Ada.Strings.Unbounded;
   use type Greplib.Wide_Count;

   --  Rendered text is written once this much of it has gathered.
   Flush_Threshold : constant := 64 * 1024;

   --  Value in decimal, without the sign position.
   function Image (Value : Greplib.Wide_Count) return String;

   --  The name of the file Event belongs to.
   function Source_Name (Sink : Output_Sink; Event : Greplib.Events.Search_Event) return String;

   --  Append a selected (Separator ':') or context (Separator '-') line.
   procedure Render_Record
     (Sink      : in out Output_Sink;
      Event     : Greplib.Events.Search_Event;
      Separator : Character);

   --  Append the "--" that comes before Event's line when it starts a
   --  context group not adjacent to the last one written.
   procedure Separate_Group (Sink : in out Output_Sink; Event : Greplib.Events.Search_Event);

   procedure Begin_Search (Sink : in out Output_Sink; Label : String) is
   begin
      Sink.Label := To_Unbounded_String (Label);
      Sink.Search_Number := Sink.Search_Number + 1;
   end Begin_Search;

   procedure Configure (Sink : in out Output_Sink; Settings : Render_Settings) is
   begin
      Sink.Settings := Settings;
   end Configure;

   procedure Flush (Sink : in out Output_Sink) is
   begin
      if Length (Sink.Pending) > 0 and then not Sink.Failed then
         Sink.Context.Put (To_String (Sink.Pending));
         if Sink.Context.Output_Failed then
            Sink.Failed := True;
         end if;
      end if;
      Sink.Pending := Null_Unbounded_String;
   end Flush;

   function Image (Value : Greplib.Wide_Count) return String is
      Text : constant String := Greplib.Wide_Count'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   overriding procedure On_Event
     (Sink   : in out Output_Sink;
      Event  : Greplib.Events.Search_Event;
      Action : out Greplib.Events.Event_Action)
   is
   begin
      if Sink.Failed then
         Action := Greplib.Events.Stop_All_Search;
         return;
      end if;

      case Greplib.Events.Kind (Event) is
         when Greplib.Events.Selected_Record =>
            Separate_Group (Sink, Event);
            Render_Record (Sink, Event, ':');
         when Greplib.Events.Context_Record =>
            Separate_Group (Sink, Event);
            Render_Record (Sink, Event, '-');
         when Greplib.Events.Count_Result =>
            Append
              (Sink.Pending,
               (if Sink.Settings.Prefix_File then Source_Name (Sink, Event) & ":" else "")
               & Image (Greplib.Events.Count (Event)) & ASCII.LF);
         when Greplib.Events.Source_Name_Result =>
            if Greplib.Events.Had_Match (Event) /= Sink.Settings.List_Without_Matches then
               Append (Sink.Pending, Source_Name (Sink, Event) & ASCII.LF);
            end if;
         when others =>
            null;
      end case;

      if Sink.Settings.Flush_Each_Record or else Length (Sink.Pending) >= Flush_Threshold then
         Flush (Sink);
      end if;

      Action := (if Sink.Failed then Greplib.Events.Stop_All_Search else Greplib.Events.Continue_Search);
   end On_Event;

   function Output_Failed (Sink : Output_Sink) return Boolean is
   begin
      return Sink.Failed;
   end Output_Failed;

   procedure Render_Record
     (Sink      : in out Output_Sink;
      Event     : Greplib.Events.Search_Event;
      Separator : Character)
   is
      Content : constant String := Greplib.Byte_Strings.To_String (Greplib.Events.Content (Event));

      --  The file, line-number, and byte-offset prefix of a line starting
      --  at Offset.
      function Prefix (Offset : Greplib.Byte_Offset) return String;

      function Prefix (Offset : Greplib.Byte_Offset) return String is
         Result : Unbounded_String;
      begin
         if Sink.Settings.Prefix_File then
            Append (Result, Source_Name (Sink, Event) & Separator);
         end if;
         if Sink.Settings.Line_Number then
            Append (Result, Image (Greplib.Events.Record_No (Event)) & Separator);
         end if;
         if Sink.Settings.Byte_Offset then
            Append (Result, Image (Offset) & Separator);
         end if;

         return To_String (Result);
      end Prefix;
   begin
      if Sink.Settings.Only_Matching and then Separator = ':' then
         for Span of Greplib.Events.Spans (Event) loop
            if Span.Last_Byte_Exclusive > Span.First_Byte then
               Append
                 (Sink.Pending,
                  Prefix (Greplib.Events.Record_Byte_Offset (Event) + Span.First_Byte)
                  & Content (Content'First + Natural (Span.First_Byte)
                             .. Content'First + Natural (Span.Last_Byte_Exclusive) - 1)
                  & ASCII.LF);
            end if;
         end loop;
      else
         Append (Sink.Pending, Prefix (Greplib.Events.Record_Byte_Offset (Event)) & Content & ASCII.LF);
      end if;
   end Render_Record;

   procedure Separate_Group (Sink : in out Output_Sink; Event : Greplib.Events.Search_Event) is
      Group  : constant Greplib.Wide_Count := Greplib.Events.Group_Number (Event);
      Source : constant Greplib.Wide_Count := Greplib.Events.Source_No (Event);
   begin
      if Group = 0 then
         return;
      end if;

      if Sink.Group_Written
        and then (Sink.Last_Search /= Sink.Search_Number
                  or else Sink.Last_Source /= Source
                  or else Sink.Last_Group /= Group)
      then
         Append (Sink.Pending, "--" & ASCII.LF);
      end if;

      Sink.Group_Written := True;
      Sink.Last_Search := Sink.Search_Number;
      Sink.Last_Source := Source;
      Sink.Last_Group := Group;
   end Separate_Group;

   function Source_Name (Sink : Output_Sink; Event : Greplib.Events.Search_Event) return String is
   begin
      if Length (Sink.Label) > 0 then
         return To_String (Sink.Label);
      else
         return Greplib.Paths.Image (Greplib.Events.Source_Path (Event));
      end if;
   end Source_Name;
end Posix_Tools.Commands.Grep.Rendering;
