with Posix_Tools.Text.Matching;

package body Posix_Tools.Text.Diagnostic_Fields
  with SPARK_Mode => On
is
   function Quoted_Payload
     (Message : String;
      Prefix  : String;
      Kind    : Usage_Diagnostic_Kind) return Usage_Diagnostic
   is
      First : constant Positive := Message'First + Prefix'Length;
      Last  : constant Natural := Message'Last - 1;
   begin
      return
        (Kind          => Kind,
         Payload_First => First,
         Payload_Last  => Last);
   end Quoted_Payload;

   function Matches_Quoted_Payload (Message : String; Prefix : String) return Boolean is
     (Message'Length > Prefix'Length
      and then Posix_Tools.Text.Matching.Starts_With (Message, Prefix)
      and then Message (Message'Last) = ''');

   function Classify_Usage_Message (Message : String) return Usage_Diagnostic is
      Extra_Operand_Prefix       : constant String := "extra operand '";
      Missing_Option_Prefix     : constant String := "missing option argument '";
      Invalid_Operand_Prefix    : constant String := "invalid operand '";
      Unknown_Option_Prefix     : constant String := "unknown option '";
      Unknown_Command_Prefix    : constant String := "unknown command '";
      Unknown_Subcommand_Prefix : constant String := "unknown subcommand '";
      Invalid_Line_Count_Prefix : constant String := "invalid line count '";
      Invalid_Count_Prefix      : constant String := "invalid count '";
   begin
      if Message = "missing operand" then
         return (Kind => Missing_Operand, Payload_First => 0, Payload_Last => 0);
      elsif Matches_Quoted_Payload (Message, Missing_Option_Prefix) then
         return Quoted_Payload (Message, Missing_Option_Prefix, Missing_Option_Argument);
      elsif Matches_Quoted_Payload (Message, Extra_Operand_Prefix) then
         return Quoted_Payload (Message, Extra_Operand_Prefix, Extra_Operand);
      elsif Matches_Quoted_Payload (Message, Invalid_Operand_Prefix) then
         return Quoted_Payload (Message, Invalid_Operand_Prefix, Invalid_Operand);
      elsif Matches_Quoted_Payload (Message, Unknown_Option_Prefix) then
         return Quoted_Payload (Message, Unknown_Option_Prefix, Unknown_Option);
      elsif Matches_Quoted_Payload (Message, Unknown_Command_Prefix) then
         return Quoted_Payload (Message, Unknown_Command_Prefix, Unknown_Command);
      elsif Matches_Quoted_Payload (Message, Unknown_Subcommand_Prefix) then
         return Quoted_Payload (Message, Unknown_Subcommand_Prefix, Unknown_Subcommand);
      elsif Matches_Quoted_Payload (Message, Invalid_Line_Count_Prefix) then
         return Quoted_Payload (Message, Invalid_Line_Count_Prefix, Invalid_Line_Count);
      elsif Matches_Quoted_Payload (Message, Invalid_Count_Prefix) then
         return Quoted_Payload (Message, Invalid_Count_Prefix, Invalid_Count);
      else
         return (Kind => Plain, Payload_First => 0, Payload_Last => 0);
      end if;
   end Classify_Usage_Message;
end Posix_Tools.Text.Diagnostic_Fields;
