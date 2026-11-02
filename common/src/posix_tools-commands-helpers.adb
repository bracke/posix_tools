with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Posix_Tools.Arguments;
with Posix_Tools.Arguments.Parsing;
with Posix_Tools.Exit_Status;
with Posix_Tools.Extension_Options;
with Posix_Tools.Help;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Localization;
with Posix_Tools.Numbers;
with Posix_Tools.Presentation;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Escaping;
with Posix_Tools.Text.File_Operands;
with Posix_Tools.Text.Matching;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Helpers is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;

   LF : constant Character := Character'Val (10);

   function Escape_Untrusted (Text : String) return String is
   begin
      return Posix_Tools.Text.Escaping.Escape_Untrusted (Text);
   end Escape_Untrusted;

   function Diagnostic_Line
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Message : String) return String
   is
   begin
      return Posix_Tools.Presentation.Diagnostic (Message, Context.Standard_Error_Is_Terminal);
   end Diagnostic_Line;

   function Intercept_Extension
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Conventional : Boolean := True) return Boolean
   is
      Count : constant Natural := Context.Argument_Count;
      Action : constant Posix_Tools.Extension_Options.Extension_Action :=
        Posix_Tools.Extension_Options.Intercept_Action
          (Argument_Count => Count,
           First_Argument => (if Count = 0 then "" else Context.Argument (1)),
           Conventional   => Conventional);
   begin
      case Action is
         when Posix_Tools.Extension_Options.Render_Help =>
            Posix_Tools.Help.Render_Command_Help (Context, Context.Command_Name);
         when Posix_Tools.Extension_Options.Render_Version =>
            Posix_Tools.Help.Render_Version (Context, Context.Command_Name);
         when Posix_Tools.Extension_Options.Render_Identity =>
            Posix_Tools.Help.Render_Identity (Context, Context.Command_Name);
         when Posix_Tools.Extension_Options.No_Extension =>
            return False;
      end case;

      Result.Status := Posix_Tools.Exit_Status.Success;
      return True;
   end Intercept_Extension;

   procedure Finish
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Ok      : Boolean := True) is
   begin
      Result.Status :=
        (if Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Finish;

   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message)
   is
   begin
      Usage_Error (Context, Result, Message, "");
   end Usage_Error;

   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message;
      Subject : String)
   is
      package Messages renames Posix_Tools.Commands.Usage_Messages;

      Name    : constant String := Messages.Placeholder (Message);
      Shown   : constant String := Escape_Untrusted (Subject);
      Default : constant String := Messages.Default (Message);

      function Filled_Default return String;

      --  Default with its placeholder filled in by Shown.
      function Filled_Default return String is
         Marker : constant String := "{" & Name & "}";
      begin
         for I in Default'First .. Default'Last - Marker'Length + 1 loop
            if Default (I .. I + Marker'Length - 1) = Marker then
               return Default (Default'First .. I - 1) & Shown & Default (I + Marker'Length .. Default'Last);
            end if;
         end loop;
         return Default;
      end Filled_Default;

      Text : constant String :=
        (if Name = "" then
            Posix_Tools.Localization.Text (Context.Effective_Locale, Messages.Key (Message), Default)
         else
            Posix_Tools.Localization.Text_1
              (Context.Effective_Locale, Messages.Key (Message), Name, Shown, Filled_Default));
   begin
      Context.Put_Error_Line (Diagnostic_Line (Context, Context.Command_Name & ": " & Text));
      Result.Status := Posix_Tools.Exit_Status.Invalid_Usage;
   end Usage_Error;

   function Parse_Natural_Operand
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Text    : String;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message;
      Value   : out Natural) return Boolean
   is
      Parsed : constant Posix_Tools.Numbers.Parse_Result :=
        Posix_Tools.Numbers.Parse_Nonnegative (Text);
   begin
      if Parsed.Status /= Posix_Tools.Numbers.Valid
        or else Parsed.Value > Posix_Tools.Numbers.Count (Natural'Last)
      then
         Usage_Error (Context, Result, Message, Text);
         Value := 0;
         return False;
      end if;

      Value := Natural (Parsed.Value);
      return True;
   end Parse_Natural_Operand;

   function Read_Affirmative_Response
     (Context           : in out Posix_Tools.Commands.Contexts.Context'Class;
      Wait_For_Line_End : Boolean := False) return Boolean
   is
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 1);
      Last   : Ada.Streams.Stream_Element_Offset;
      First  : Character := Character'Val (0);
   begin
      loop
         if not Context.Try_Read_Standard_Input (Buffer, Last)
           or else Last < Buffer'First
         then
            return False;
         end if;

         declare
            Ch : constant Character := Character'Val (Buffer (Buffer'First));
         begin
            if not Wait_For_Line_End then
               return Ch in 'y' | 'Y';
            elsif Ch = LF then
               return First in 'y' | 'Y';
            elsif First = Character'Val (0) then
               First := Ch;
            end if;
         end;
      end loop;
   end Read_Affirmative_Response;

   function Resolve_Group_Id (Text : String; Value : out Natural) return Boolean is
      Found  : Boolean;
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_Value (Text);
   begin
      if Parsed.Valid then
         Value := Parsed.Value;
         return True;
      end if;

      Value := Posix_Tools.Host_Adapters.File_System.Group_Id_For_Name (Text, Found);
      return Found;
   end Resolve_Group_Id;

   function Resolve_User_Id (Text : String; Value : out Natural) return Boolean is
      Found  : Boolean;
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_Value (Text);
   begin
      if Parsed.Valid then
         Value := Parsed.Value;
         return True;
      end if;

      Value := Posix_Tools.Host_Adapters.File_System.User_Id_For_Name (Text, Found);
      return Found;
   end Resolve_User_Id;

   function Id_Text (Id : Natural; Name : String; Prefer_Name : Boolean) return String is
   begin
      if Prefer_Name and then Name /= "" then
         return Name;
      else
         return Posix_Tools.Text.Numeric_Images.Integer_Image (Id);
      end if;
   end Id_Text;

   function Decorated_Id_Text (Id : Natural; Name : String) return String is
      Text : constant String := Posix_Tools.Text.Numeric_Images.Integer_Image (Id);
   begin
      if Name = "" then
         return Text;
      else
         return Text & "(" & Name & ")";
      end if;
   end Decorated_Id_Text;

   function Group_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String
   is
   begin
      return Id_Text (Id, Context.Group_Name_For_Id (Id), Prefer_Name);
   end Group_Id_Text;

   function User_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String
   is
   begin
      return Id_Text (Id, Context.User_Name_For_Id (Id), Prefer_Name);
   end User_Id_Text;

   function Decorated_Group_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String
   is
   begin
      return Decorated_Id_Text (Id, Context.Group_Name_For_Id (Id));
   end Decorated_Group_Id_Text;

   function Decorated_User_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String
   is
   begin
      return Decorated_Id_Text (Id, Context.User_Name_For_Id (Id));
   end Decorated_User_Id_Text;

   function Current_User_Name
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return String
   is
      User_Id : Natural;
   begin
      if Context.Current_User_Id (User_Id) then
         return Context.User_Name_For_Id (User_Id);
      else
         return "";
      end if;
   end Current_User_Name;

   procedure For_Each_Directory_Child
     (Path   : String;
      Listed : out Boolean)
   is
      package FS renames Posix_Tools.Host_Adapters.File_System;

      use type Posix_Tools.Host_Adapters.File_System.File_Kind;

      procedure Visit (Name : String; Full_Name : String; Stop : in out Boolean);

      procedure Visit (Name : String; Full_Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Name, Stop);
      begin
         Action (Full_Name);
      end Visit;

      procedure Each is new FS.For_Each_Directory_Entry (Visit);
   begin
      if FS.Kind (Path) = FS.Directory then
         Each (Path, Listed);
      else
         Listed := True;
      end if;
   end For_Each_Directory_Child;

   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Default     : String)
   is
   begin
      Context.Put_Error_Line
        (Diagnostic_Line
           (Context,
            Context.Command_Name & ": "
            & Posix_Tools.Localization.Text (Context.Effective_Locale, Message_Key, Default)));
   end Operational_Error;

   procedure Subject_Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Subject     : String;
      Message_Key : String;
      Default     : String)
   is
   begin
      Context.Put_Error_Line
        (Diagnostic_Line
           (Context,
            Context.Command_Name & ": '" & Escape_Untrusted (Subject) & "': "
            & Posix_Tools.Localization.Text (Context.Effective_Locale, Message_Key, Default)));
   end Subject_Operational_Error;

   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Name        : String;
      Value       : String;
      Default     : String)
   is
      Shown  : constant String := Escape_Untrusted (Value);
      Marker : constant String := "{" & Name & "}";

      --  Default with its placeholder filled in by Shown.
      function Filled_Default return String;

      function Filled_Default return String is
      begin
         for I in Default'First .. Default'Last - Marker'Length + 1 loop
            if Default (I .. I + Marker'Length - 1) = Marker then
               return Default (Default'First .. I - 1) & Shown & Default (I + Marker'Length .. Default'Last);
            end if;
         end loop;
         return Default;
      end Filled_Default;
   begin
      Context.Put_Error_Line
        (Diagnostic_Line
           (Context,
            Context.Command_Name & ": "
            & Posix_Tools.Localization.Text_1
                (Context.Effective_Locale, Message_Key, Name, Shown, Filled_Default)));
   end Operational_Error;

   function Standard_Input_Name
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return String
   is
   begin
      return Posix_Tools.Localization.Text
        (Context.Effective_Locale, "posix_tools.diagnostic.standard_input", "standard input");
   end Standard_Input_Name;

   function File_Subject
     (Context   : Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String) return String
   is
   begin
      return Posix_Tools.Text.File_Operands.Subject_Name (File_Name, Standard_Input_Name (Context));
   end File_Subject;

   function Unknown_Option_Subject (Argument : String; Accepted : String) return String is
   begin
      if Argument'Length < 2
        or else Argument (Argument'First) /= '-'
        or else Argument (Argument'First + 1) = '-'
      then
         return Argument;
      end if;

      for Ch of Argument (Argument'First + 1 .. Argument'Last) loop
         if not Posix_Tools.Text.Matching.Contains (Accepted, Ch) then
            return "-" & Ch;
         end if;
      end loop;
      return Argument;
   end Unknown_Option_Subject;

   procedure Parse_Options
     (Context           : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result            : in out Posix_Tools.Commands.Results.Result;
      Accepted          : String;
      Requires_Argument : String;
      First             : out Positive;
      Valid             : out Boolean)
   is
      package Parsing renames Posix_Tools.Arguments.Parsing;
      use all type Parsing.Parse_Status;
      use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;

      Arguments : constant Posix_Tools.Arguments.Vector := Context.Argument_Vector;
      Position  : Parsing.Cursor := (Index => 1, Offset => 2);
      Parsed    : Parsing.Result;
   begin
      Valid := True;
      loop
         while Long_Options /= ""
           and then Position.Offset = 2
           and then Position.Index <= Natural (Arguments.Length)
           and then Arguments.Element (Position.Index)'Length > 2
           and then Ada.Strings.Fixed.Index
             (" " & Long_Options & " ", " " & Arguments.Element (Position.Index) & " ") > 0
         loop
            Handle (Long_Name, "", Result, Valid);
            if not Valid then
               First := Position.Index;
               return;
            end if;
            Position := (Index => Position.Index + 1, Offset => 2);
         end loop;
         Parsed := Parsing.Parse_Short (Arguments, Position, Accepted, Requires_Argument);
         case Parsed.Status is
            when Option =>
               Handle (Parsed.Name, Ada.Strings.Unbounded.To_String (Parsed.Text), Result, Valid);
               if not Valid then
                  First := Position.Index;
                  return;
               end if;
               Position := Parsed.Next;
            when Unknown_Option =>
               Usage_Error (Context, Result, Unknown_Option, "-" & Parsed.Name);
               Valid := False;
               First := Position.Index;
               return;
            when Missing_Argument =>
               Usage_Error (Context, Result, Missing_Option_Argument, "-" & Parsed.Name);
               Valid := False;
               First := Position.Index;
               return;
            when End_Of_Options | Done =>
               --  Past "--", or past the last argument.
               First := Parsed.Next.Index;
               return;
            when Operand =>
               --  The operand Parsed has stepped over is the first one.
               First := Parsed.Next.Index - 1;
               return;
         end case;
      end loop;
   end Parse_Options;
end Posix_Tools.Commands.Helpers;
