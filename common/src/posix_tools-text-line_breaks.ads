package Posix_Tools.Text.Line_Breaks
  with SPARK_Mode => On
is
   function Is_LF (Ch : Character) return Boolean
     with
       Post => Is_LF'Result = (Ch = Character'Val (10));

   function Ends_With_LF (Text : String) return Boolean
     with
       Post =>
         Ends_With_LF'Result =
           (Text /= "" and then Text (Text'Last) = Character'Val (10));

   function LF_Count (Text : String) return Long_Long_Integer
     with
       Post =>
         LF_Count'Result >= 0
         and then LF_Count'Result <= Long_Long_Integer (Text'Length);

   function LF_Segment_Count (Text : String) return Long_Long_Integer
     with
       Post =>
         LF_Segment_Count'Result =
           (if Text = "" then 0
            elsif Ends_With_LF (Text) then LF_Count (Text)
            else LF_Count (Text) + 1);

   function LF_Segment_Last_From (Text : String; First : Positive) return Positive
     with
       Pre =>
         Text /= ""
         and then First in Text'Range,
       Post =>
         LF_Segment_Last_From'Result in First .. Text'Last
         and then
           (Is_LF (Text (LF_Segment_Last_From'Result))
            or else LF_Segment_Last_From'Result = Text'Last);

   function Line_Number_Through (Text : String; Last : Positive) return Long_Long_Integer
     with
       Pre =>
         Text /= ""
         and then Last in Text'Range,
       Post =>
         Line_Number_Through'Result >= 1
         and then Line_Number_Through'Result <= Long_Long_Integer (Text'Length) + 1;

   function Without_Trailing_CR (Line : String) return String
     with
       Post => Without_Trailing_CR'Result'Length <= Line'Length;
end Posix_Tools.Text.Line_Breaks;
