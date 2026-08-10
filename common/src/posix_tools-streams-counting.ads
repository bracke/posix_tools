with Posix_Tools.Text.UTF_8;

package Posix_Tools.Streams.Counting is
   type Counts is record
      Lines : Long_Long_Integer := 0;
      Words : Long_Long_Integer := 0;
      Bytes : Long_Long_Integer := 0;
      Characters : Long_Long_Integer := 0;
   end record;

   type Counter is private;

   procedure Process (Self : in out Counter; Input : String);
   procedure Finish_Text (Self : in out Counter);
   function Snapshot (Self : Counter) return Counts;
   function Text_Invalid (Self : Counter) return Boolean;
   function Count_Bytes (Input : String) return Counts;

private
   type Counter is record
      Current : Counts;
      In_Word : Boolean := False;
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Invalid_Text : Boolean := False;
   end record;
end Posix_Tools.Streams.Counting;
