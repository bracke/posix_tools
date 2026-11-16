--  Lexical classification for broad exception handlers. Kept separate from
--  manifest traversal so parser behavior can be tested directly.
package Metadata_Checks.Silent_Handlers is
   type Handler_Info is record
      Is_Silent        : Boolean := False;
      Is_Indeterminate : Boolean := False;
      Intentional      : Boolean := False;
   end record;

   function Inspect
     (Content     : String;
      Line_Number : Positive) return Handler_Info;
private
   procedure Self_Test;
end Metadata_Checks.Silent_Handlers;
