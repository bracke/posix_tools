with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Rg.Encodings;
with Posix_Tools.Host_Adapters.Input_Files;
with Posix_Tools.Numbers;
private with Posix_Tools.Host_Adapters.Temporary_Storage;
private with Posix_Tools.Text.UTF_8;

--  Bounded delimiter-selected record input for rg files and standard input.
package Posix_Tools.Commands.Rg.Input is
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Length      : constant Ada.Streams.Stream_Element_Offset := 64 * 1024;
   Maximum_Line_Bytes : constant Natural := 4 * 1024 * 1024;
   Maximum_Standard_Input_Bytes : constant Posix_Tools.Numbers.Count :=
     1_073_741_824;
   No_Nul_Byte        : constant Natural := Natural'Last;

   subtype Encoding_Mode is Posix_Tools.Commands.Rg.Encodings.Encoding_Mode;
   package Encoding renames Posix_Tools.Commands.Rg.Encodings;

   Automatic_Encoding : constant Encoding_Mode := Encoding.Automatic_Encoding;
   No_Encoding        : constant Encoding_Mode := Encoding.No_Encoding;
   UTF_8_Encoding     : constant Encoding_Mode := Encoding.UTF_8_Encoding;
   UTF_16_Encoding    : constant Encoding_Mode := Encoding.UTF_16_Encoding;
   UTF_16LE_Encoding  : constant Encoding_Mode := Encoding.UTF_16LE_Encoding;
   UTF_16BE_Encoding  : constant Encoding_Mode := Encoding.UTF_16BE_Encoding;
   IBM866_Encoding    : constant Encoding_Mode := Encoding.IBM866_Encoding;
   ISO_8859_2_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_2_Encoding;
   ISO_8859_3_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_3_Encoding;
   ISO_8859_4_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_4_Encoding;
   ISO_8859_5_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_5_Encoding;
   ISO_8859_6_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_6_Encoding;
   ISO_8859_7_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_7_Encoding;
   ISO_8859_8_Encoding  : constant Encoding_Mode := Encoding.ISO_8859_8_Encoding;
   ISO_8859_10_Encoding : constant Encoding_Mode := Encoding.ISO_8859_10_Encoding;
   ISO_8859_13_Encoding : constant Encoding_Mode := Encoding.ISO_8859_13_Encoding;
   ISO_8859_14_Encoding : constant Encoding_Mode := Encoding.ISO_8859_14_Encoding;
   ISO_8859_15_Encoding : constant Encoding_Mode := Encoding.ISO_8859_15_Encoding;
   ISO_8859_16_Encoding : constant Encoding_Mode := Encoding.ISO_8859_16_Encoding;
   KOI8_R_Encoding       : constant Encoding_Mode := Encoding.KOI8_R_Encoding;
   KOI8_U_Encoding       : constant Encoding_Mode := Encoding.KOI8_U_Encoding;
   Macintosh_Encoding    : constant Encoding_Mode := Encoding.Macintosh_Encoding;
   Windows_874_Encoding  : constant Encoding_Mode := Encoding.Windows_874_Encoding;
   Windows_1250_Encoding : constant Encoding_Mode := Encoding.Windows_1250_Encoding;
   Windows_1251_Encoding : constant Encoding_Mode := Encoding.Windows_1251_Encoding;
   Windows_1252_Encoding : constant Encoding_Mode := Encoding.Windows_1252_Encoding;
   Windows_1253_Encoding : constant Encoding_Mode := Encoding.Windows_1253_Encoding;
   Windows_1254_Encoding : constant Encoding_Mode := Encoding.Windows_1254_Encoding;
   Windows_1255_Encoding : constant Encoding_Mode := Encoding.Windows_1255_Encoding;
   Windows_1256_Encoding : constant Encoding_Mode := Encoding.Windows_1256_Encoding;
   Windows_1257_Encoding : constant Encoding_Mode := Encoding.Windows_1257_Encoding;
   Windows_1258_Encoding : constant Encoding_Mode := Encoding.Windows_1258_Encoding;
   X_Mac_Cyrillic_Encoding : constant Encoding_Mode := Encoding.X_Mac_Cyrillic_Encoding;
   GBK_Encoding          : constant Encoding_Mode := Encoding.GBK_Encoding;
   GB18030_Encoding      : constant Encoding_Mode := Encoding.GB18030_Encoding;
   Big5_Encoding         : constant Encoding_Mode := Encoding.Big5_Encoding;
   EUC_JP_Encoding       : constant Encoding_Mode := Encoding.EUC_JP_Encoding;
   ISO_2022_JP_Encoding  : constant Encoding_Mode := Encoding.ISO_2022_JP_Encoding;
   Shift_JIS_Encoding    : constant Encoding_Mode := Encoding.Shift_JIS_Encoding;
   EUC_KR_Encoding       : constant Encoding_Mode := Encoding.EUC_KR_Encoding;
   Replacement_Encoding  : constant Encoding_Mode := Encoding.Replacement_Encoding;
   X_User_Defined_Encoding : constant Encoding_Mode := Encoding.X_User_Defined_Encoding;

   type Read_Outcome is
     (Line_Available,
      End_Of_Input,
      Read_Failed,
      Line_Too_Long);

   type Nul_Scan_Outcome is
     (No_Nul_Found,
      Nul_Found,
      Scan_Open_Failed,
      Scan_Read_Failed,
      Scan_Close_Failed);

   type Spool_Outcome is
     (Spool_Ready,
      Spool_Read_Failed,
      Spool_Capacity_Exceeded,
      Spool_Create_Failed,
      Spool_Write_Failed,
      Spool_Prepare_Failed);

   type Reader is limited private;

   procedure Open
     (Self     : in out Reader;
      Name     : String;
      Encoding : Encoding_Mode;
      Ok       : out Boolean);

   procedure Open_Spooled_Standard_Input
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Encoding   : Encoding_Mode;
      Nul_Offset : out Natural;
      Outcome    : out Spool_Outcome);

   procedure Scan_File_For_Nul
     (Name       : String;
      Encoding   : Encoding_Mode;
      Nul_Offset : out Natural;
      Outcome    : out Nul_Scan_Outcome);
   --  Scan a named file in bounded chunks without decoding or retaining its
   --  contents. Nul_Offset is zero-based when Outcome is Nul_Found.

   procedure Next
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : out Ada.Strings.Unbounded.Unbounded_String;
      Terminated : out Boolean;
      Outcome    : out Read_Outcome);

   procedure Next
     (Self       : in out Reader;
      Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : out Ada.Strings.Unbounded.Unbounded_String;
      Terminated : out Boolean;
      Nul_Offset : out Natural;
      Outcome    : out Read_Outcome;
      Delimiter  : Character := ASCII.LF);
   --  Nul_Offset is zero-based within the record and remains available when a
   --  record exceeds Maximum_Line_Bytes. No_Nul_Byte means none was observed.

   procedure Close (Self : in out Reader; Ok : out Boolean);

private
   type Source_Kind is (Named_File, Standard_Input, Spooled_Standard_Input);
   type Active_Encoding is
     (Encoding_Undetermined,
      Encoding_Raw,
      Encoding_UTF_8,
      Encoding_UTF_16LE,
      Encoding_UTF_16BE,
      Encoding_IBM866,
      Encoding_ISO_8859_2,
      Encoding_ISO_8859_3,
      Encoding_ISO_8859_4,
      Encoding_ISO_8859_5,
      Encoding_ISO_8859_6,
      Encoding_ISO_8859_7,
      Encoding_ISO_8859_8,
      Encoding_ISO_8859_10,
      Encoding_ISO_8859_13,
      Encoding_ISO_8859_14,
      Encoding_ISO_8859_15,
      Encoding_ISO_8859_16,
      Encoding_KOI8_R,
      Encoding_KOI8_U,
      Encoding_Macintosh,
      Encoding_Windows_874,
      Encoding_Windows_1250,
      Encoding_Windows_1251,
      Encoding_Windows_1252,
      Encoding_Windows_1253,
      Encoding_Windows_1254,
      Encoding_Windows_1255,
      Encoding_Windows_1256,
      Encoding_Windows_1257,
      Encoding_Windows_1258,
      Encoding_X_Mac_Cyrillic,
      Encoding_GBK,
      Encoding_GB18030,
      Encoding_Big5,
      Encoding_EUC_JP,
      Encoding_ISO_2022_JP,
      Encoding_Shift_JIS,
      Encoding_EUC_KR,
      Encoding_Replacement,
      Encoding_X_User_Defined);
   type Prefix_Array is array (Positive range 1 .. 3) of Ada.Streams.Stream_Element;
   type Pushback_Array is array (Positive range 1 .. 3) of Ada.Streams.Stream_Element;
   type ISO_2022_State is (ISO_ASCII, ISO_Roman, ISO_Katakana, ISO_JIS0208);

   type Reader is limited record
      File   : Posix_Tools.Host_Adapters.Input_Files.Input_File;
      Spool  : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
      Source : Source_Kind := Named_File;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Buffer_Length);
      Next   : Ada.Streams.Stream_Element_Offset := 1;
      Last   : Ada.Streams.Stream_Element_Offset := 0;
      At_End : Boolean := False;
      Requested_Encoding : Encoding_Mode := Automatic_Encoding;
      Active             : Active_Encoding := Encoding_Undetermined;
      Prefix             : Prefix_Array := [others => 0];
      Prefix_Count       : Natural range 0 .. 3 := 0;
      Prefix_Next        : Natural range 1 .. 4 := 1;
      Decoded            : String (1 .. 8) := [others => Character'Val (0)];
      Decoded_Next       : Natural range 1 .. 9 := 1;
      Decoded_Last       : Natural range 0 .. 8 := 0;
      UTF_8_Decoder      : Posix_Tools.Text.UTF_8.Decoder;
      UTF_8_Sequence     : String (1 .. 4) := [others => Character'Val (0)];
      UTF_8_Length       : Natural range 0 .. 4 := 0;
      Retry_Byte         : Ada.Streams.Stream_Element := 0;
      Has_Retry_Byte     : Boolean := False;
      Pending_High       : Natural range 0 .. 16#DBFF# := 0;
      Retry_Unit         : Natural range 0 .. 16#FFFF# := 0;
      Has_Retry_Unit     : Boolean := False;
      Pushback           : Pushback_Array := [others => 0];
      Pushback_Count     : Natural range 0 .. 3 := 0;
      ISO_State          : ISO_2022_State := ISO_ASCII;
      ISO_Output_Flag    : Boolean := False;
      Replacement_Emitted : Boolean := False;
   end record;
end Posix_Tools.Commands.Rg.Input;
