with Explore.Application.Sessions;
with Explore.Input;

--  What the user's keys and clicks do, as the mode the session is in says:
--  browsing runs the command a key is bound to, a prompt or the filter takes
--  the key as typing, and a question or the jobs panel takes it as an answer.
private package Explore.Application.Controller is
   use Explore.Application.Sessions;

   --  Act on Item: a key, a paste, a click, or news of the terminal's size
   --  or focus.
   procedure Handle (State : in out Session; Item : Explore.Input.Event);
end Explore.Application.Controller;
