package Posix_Tools.Text.Diagnostic_Fields
  with SPARK_Mode => On
is
   type Usage_Diagnostic_Kind is
     (Plain,
      Missing_Operand,
      Missing_Option_Argument,
      Extra_Operand,
      Invalid_Operand,
      Unknown_Option,
      Unknown_Command,
      Unknown_Subcommand,
      Invalid_Line_Count,
      Invalid_Count);

   type Usage_Diagnostic is record
      Kind          : Usage_Diagnostic_Kind := Plain;
      Payload_First : Natural := 0;
      Payload_Last  : Natural := 0;
   end record;

   function Has_Payload (Item : Usage_Diagnostic) return Boolean is
     (Item.Payload_First /= 0 and then Item.Payload_Last /= 0);

   function Classify_Usage_Message (Message : String) return Usage_Diagnostic
     with Post =>
       (if Classify_Usage_Message'Result.Kind in Plain | Missing_Operand then
          not Has_Payload (Classify_Usage_Message'Result)
        else
          Has_Payload (Classify_Usage_Message'Result)
          and then Classify_Usage_Message'Result.Payload_First in Message'Range
          and then Classify_Usage_Message'Result.Payload_Last in Message'Range
          and then
            Classify_Usage_Message'Result.Payload_First - 1
            <= Classify_Usage_Message'Result.Payload_Last);
end Posix_Tools.Text.Diagnostic_Fields;
