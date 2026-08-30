with Posix_Tools.Text.UTF_8;

package Posix_Tools.Streams.Counting
  with SPARK_Mode => On
is
   subtype Count_Value is Long_Long_Integer range 0 .. Long_Long_Integer'Last;

   function Saturating_Add (Left, Right : Count_Value) return Count_Value is
     (if Left <= Count_Value'Last - Right then Left + Right else Count_Value'Last)
     with
       Post =>
         Saturating_Add'Result >= Left
         and then Saturating_Add'Result >= Right
         and then
           (if Left <= Count_Value'Last - Right then
              Saturating_Add'Result = Left + Right
            else
              Saturating_Add'Result = Count_Value'Last);

   function Maximum (Left, Right : Count_Value) return Count_Value is
     (if Left >= Right then Left else Right)
     with
       Post =>
         Maximum'Result >= Left
         and then Maximum'Result >= Right
         and then
           (if Left >= Right then
              Maximum'Result = Left
            else
              Maximum'Result = Right);

   type Counts is record
      Lines : Count_Value := 0;
      Words : Count_Value := 0;
      Bytes : Count_Value := 0;
      Characters : Count_Value := 0;
      Max_Line_Length : Count_Value := 0;
   end record;

   type Counter is private;

   function Byte_Count (Self : Counter) return Count_Value;
   function Character_Count (Self : Counter) return Count_Value;
   function Current_Line_Length (Self : Counter) return Count_Value;
   function Line_Count (Self : Counter) return Count_Value;
   function Max_Line_Length (Self : Counter) return Count_Value;
   function Word_Count (Self : Counter) return Count_Value;
   procedure Process (Self : in out Counter; Input : String)
     with Post =>
       Byte_Count (Self) =
         Saturating_Add (Byte_Count (Self'Old), Count_Value (Input'Length))
       and then Character_Count (Self) >= Character_Count (Self'Old)
       and then Line_Count (Self) >= Line_Count (Self'Old)
       and then Max_Line_Length (Self) >= Max_Line_Length (Self'Old)
       and then Word_Count (Self) >= Word_Count (Self'Old)
       and then (if Text_Invalid (Self'Old) then Text_Invalid (Self))
       and then
         (if Input'Length = 0 then
            Character_Count (Self) = Character_Count (Self'Old)
            and then Current_Line_Length (Self) = Current_Line_Length (Self'Old)
            and then Line_Count (Self) = Line_Count (Self'Old)
            and then Max_Line_Length (Self) = Max_Line_Length (Self'Old)
            and then Text_Invalid (Self) = Text_Invalid (Self'Old)
            and then Word_Count (Self) = Word_Count (Self'Old));
   procedure Finish_Text (Self : in out Counter)
     with Post =>
       Byte_Count (Self) = Byte_Count (Self'Old)
       and then Character_Count (Self) = Character_Count (Self'Old)
       and then Line_Count (Self) = Line_Count (Self'Old)
       and then Max_Line_Length (Self) =
         Maximum (Max_Line_Length (Self'Old), Current_Line_Length (Self'Old))
       and then Word_Count (Self) = Word_Count (Self'Old)
       and then (if Text_Invalid (Self'Old) then Text_Invalid (Self));
   function Snapshot (Self : Counter) return Counts
     with Post =>
       Snapshot'Result.Bytes = Byte_Count (Self)
       and then Snapshot'Result.Characters = Character_Count (Self)
       and then Snapshot'Result.Lines = Line_Count (Self)
       and then Snapshot'Result.Max_Line_Length = Max_Line_Length (Self)
       and then Snapshot'Result.Words = Word_Count (Self);
   function Text_Invalid (Self : Counter) return Boolean;
   function Count_Bytes (Input : String) return Counts
     with Post =>
       Count_Bytes'Result.Bytes = Count_Value (Input'Length)
       and then
         (if Input'Length = 0 then
            Count_Bytes'Result.Characters = 0
            and then Count_Bytes'Result.Lines = 0
            and then Count_Bytes'Result.Max_Line_Length = 0
            and then Count_Bytes'Result.Words = 0);

private
   type Counter is record
      Current : Counts;
      Current_Line_Length : Count_Value := 0;
      In_Word : Boolean := False;
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Invalid_Text : Boolean := False;
   end record;

   function Byte_Count (Self : Counter) return Count_Value is (Self.Current.Bytes);
   function Character_Count (Self : Counter) return Count_Value is (Self.Current.Characters);
   function Current_Line_Length (Self : Counter) return Count_Value is (Self.Current_Line_Length);
   function Line_Count (Self : Counter) return Count_Value is (Self.Current.Lines);
   function Max_Line_Length (Self : Counter) return Count_Value is (Self.Current.Max_Line_Length);
   function Text_Invalid (Self : Counter) return Boolean is (Self.Invalid_Text);
   function Word_Count (Self : Counter) return Count_Value is (Self.Current.Words);
end Posix_Tools.Streams.Counting;
