with Ada.Containers.Indefinite_Vectors;

package Posix_Tools.Streams.Lines is
   package Segment_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   subtype Segment_Vector is Segment_Vectors.Vector;

   function Split_LF_Segments (Input : String) return Segment_Vector;
   --  Split byte text into LF-delimited segments. Each newline-terminated
   --  segment includes the LF byte. A final partial segment is returned
   --  without adding a delimiter.

   function Split_LF_Records (Input : String) return Segment_Vector;
   --  Split byte text into LF-delimited records. The LF delimiter is not
   --  included in returned records.
end Posix_Tools.Streams.Lines;
