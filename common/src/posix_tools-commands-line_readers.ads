with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Host_Adapters.Input_Files;

--  Bounded, pull-based LF record input for commands that must interleave
--  several sources (comm and paste).
package Posix_Tools.Commands.Line_Readers is
   use type Ada.Streams.Stream_Element_Offset;
   subtype Buffer_Length_Type is Ada.Streams.Stream_Element_Offset range
     1 .. Ada.Streams.Stream_Element_Offset'Last;
   Default_Buffer_Length : constant Buffer_Length_Type := 16 * 1024;
   Bulk_Buffer_Length    : constant Buffer_Length_Type := 64 * 1024;

   type Reader
     (Buffer_Length : Buffer_Length_Type := Default_Buffer_Length) is
     limited private;

   procedure Open (Self : in out Reader; Name : String; Ok : out Boolean);
   procedure Next
     (Self      : in out Reader;
      Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line      : out Ada.Strings.Unbounded.Unbounded_String;
      Available : out Boolean;
      Ok        : out Boolean);
   procedure Close (Self : in out Reader; Ok : out Boolean);

private
   type Reader
     (Buffer_Length : Buffer_Length_Type := Default_Buffer_Length) is
     limited record
      File     : Posix_Tools.Host_Adapters.Input_Files.Input_File;
      Is_Stdin : Boolean := False;
      Buffer   : Ada.Streams.Stream_Element_Array
        (1 .. Buffer_Length);
      Next     : Ada.Streams.Stream_Element_Offset := 1;
      Last     : Ada.Streams.Stream_Element_Offset := 0;
      At_End   : Boolean := False;
   end record;
end Posix_Tools.Commands.Line_Readers;
