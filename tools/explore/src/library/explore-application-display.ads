with Explore.Application.Sessions;
with Explore.Jobs;

--  What the session shows: the frame, drawn from the browser and the frame
--  context, the jobs panel's lines, and the preview's image.
private package Explore.Application.Display is
   use Explore.Application.Sessions;

   --  Draw the frame and write what changed since the last one. Ok is False
   --  when the terminal took no output.
   procedure Draw (State : in out Session; Ok : out Boolean);

   --  Fill the jobs panel's lines from Now, keeping its cursor in them.
   procedure Fill_Panel (State : in out Session; Now : Explore.Jobs.Snapshot);

   --  Draw for a screen of Rows by Columns, every cell afresh.
   procedure Resize (State : in out Session; Rows, Columns : Natural);

   --  Send the preview's image to the terminal, placed to fit the pane, in
   --  place of any image shown before.
   procedure Show_Image (State : in out Session);

   --  Stop showing the preview's image; the terminal keeps it for later.
   procedure Hide_Image (State : in out Session);
end Explore.Application.Display;
