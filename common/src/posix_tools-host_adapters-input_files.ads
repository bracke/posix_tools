with Ada.Streams;
with Posix_Tools.Numbers;
private with Ada.Finalization;
private with Hostkit.Descriptors;

--  A sequential input file kept open across bounded reads.
package Posix_Tools.Host_Adapters.Input_Files is
   use type Ada.Streams.Stream_Element_Offset;
   type Input_File is limited private;
   type Read_Outcome is (Read_Complete, Read_End, Read_Failed);
   type Recovery_Outcome is
     (Recovery_Advanced,
      Recovery_Not_Seekable,
      Recovery_Failed);

   function Is_Open (File : Input_File) return Boolean;
   procedure Open (File : in out Input_File; Path : String; Ok : out Boolean)
     with Post => Ok = Is_Open (File);
   procedure Read
     (File    : Input_File;
      Buffer  : out Ada.Streams.Stream_Element_Array;
      Last    : out Ada.Streams.Stream_Element_Offset;
      Outcome : out Read_Outcome)
     with Pre => Is_Open (File),
          Post => Last < Buffer'First or else Last in Buffer'Range;
   procedure Advance_After_Error
     (File    : Input_File;
      Count   : Posix_Tools.Numbers.Count;
      Outcome : out Recovery_Outcome)
     with Pre => Is_Open (File);
   procedure Close (File : in out Input_File; Ok : out Boolean)
     with Post => not Is_Open (File);

private
   type Input_File is
     new Ada.Finalization.Limited_Controlled with record
      Descriptor : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
   end record;

   overriding procedure Finalize (File : in out Input_File);
end Posix_Tools.Host_Adapters.Input_Files;
