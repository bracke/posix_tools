with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;

package Posix_Tools.Text.Xargs_Parsing is
   type Parse_Status is
     (Valid,
      Unmatched_Single_Quote,
      Unmatched_Double_Quote,
      Unfinished_Escape);

   type Parse_Result is record
      Status : Parse_Status := Valid;
      Items  : Posix_Tools.Arguments.Vector;
   end record;

   type Parser is private;

   procedure Initialize
     (State            : out Parser;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String);
   procedure Feed (State : in out Parser; Data : String; Result : out Parse_Result);
   procedure Finish (State : in out Parser; Result : out Parse_Result);
   function Is_Stopped (State : Parser) return Boolean;

   function Parse_Input
     (Data             : String;
      Null_Delimited   : Boolean;
      Replacement_Mode : Boolean;
      Has_Eof_Marker   : Boolean;
      Eof_Marker       : String) return Parse_Result;

private
   type Parse_Mode is (Blank_Mode, Line_Mode, Null_Mode);
   type Quote_Mode is (Unquoted, Single_Quoted, Double_Quoted, Escaped, Double_Escaped);
   type Parser is record
      Mode           : Parse_Mode := Blank_Mode;
      Quote          : Quote_Mode := Unquoted;
      Current        : Ada.Strings.Unbounded.Unbounded_String;
      Eof_Marker     : Ada.Strings.Unbounded.Unbounded_String;
      Has_Eof_Marker : Boolean := False;
      Item_Started   : Boolean := False;
      Stopped        : Boolean := False;
   end record;
end Posix_Tools.Text.Xargs_Parsing;
