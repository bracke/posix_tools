package Posix_Tools.Text.Seq_Formats
  with SPARK_Mode => On
is
   type Parsed_Seq_Format is record
      Valid            : Boolean := False;
      Percent_Index    : Natural := 0;
      Conversion_Index : Natural := 0;
      Conversion       : Character := Character'Val (0);
      Width            : Natural := 0;
      Has_Precision    : Boolean := False;
      Precision        : Natural := 0;
   end record;

   function Parse_Seq_Format (Format : String) return Parsed_Seq_Format
     with
       Post =>
         (if Parse_Seq_Format'Result.Valid then
            Parse_Seq_Format'Result.Percent_Index in Format'Range
            and then Parse_Seq_Format'Result.Conversion_Index in Format'Range
            and then
              Parse_Seq_Format'Result.Percent_Index
                < Parse_Seq_Format'Result.Conversion_Index
            and then Parse_Seq_Format'Result.Conversion in 'f' | 'F' | 'g' | 'G'
          else
            Parse_Seq_Format'Result.Percent_Index = 0
            and then Parse_Seq_Format'Result.Conversion_Index = 0
            and then Parse_Seq_Format'Result.Conversion = Character'Val (0)
            and then Parse_Seq_Format'Result.Width = 0
            and then not Parse_Seq_Format'Result.Has_Precision
            and then Parse_Seq_Format'Result.Precision = 0);

   function Valid_Render_Scale (Scale : Natural) return Boolean
     with
       Post =>
         Valid_Render_Scale'Result =
           (Scale <= 18);

   function Pad_Zero (Text : String; Width : Natural) return String
     with
       Post =>
         Pad_Zero'Result'Length >= Text'Length
         and then Pad_Zero'Result'Length >= Width;

   function Trimmed_Decimal
     (Item          : Long_Long_Integer;
      Decimal_Scale : Natural) return String
     with
       Pre =>
         Item > Long_Long_Integer'First
         and then Valid_Render_Scale (Decimal_Scale);

   function Fixed_Decimal
     (Item          : Long_Long_Integer;
      Decimal_Scale : Natural;
      Precision     : Natural) return String
     with
       Pre =>
         Item > Long_Long_Integer'First
         and then Valid_Render_Scale (Decimal_Scale);
end Posix_Tools.Text.Seq_Formats;
