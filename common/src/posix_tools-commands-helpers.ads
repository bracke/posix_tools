with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Usage_Messages;

package Posix_Tools.Commands.Helpers is
   function Escape_Untrusted (Text : String) return String;

   function Intercept_Extension
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Conventional : Boolean := True) return Boolean;

   --  Set the status a command ends with: success when Ok and all its
   --  output was written, operational failure otherwise.
   procedure Finish
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Ok      : Boolean := True);

   --  Report Message, in the messages locale, as a usage error: the command
   --  ends with the invalid-usage status.
   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message)
     with Pre => not Posix_Tools.Commands.Usage_Messages.Has_Subject (Message);

   --  Report Message as a usage error, with Subject, escaped, filling its
   --  placeholder; a message without one leaves Subject out.
   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message;
      Subject : String);

   --  Parse Text as a natural number into Value, or report Message with Text
   --  as its subject as a usage error and return False.
   function Parse_Natural_Operand
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Text    : String;
      Message : Posix_Tools.Commands.Usage_Messages.Usage_Message;
      Value   : out Natural) return Boolean;

   function Read_Affirmative_Response
     (Context           : in out Posix_Tools.Commands.Contexts.Context'Class;
      Wait_For_Line_End : Boolean := False) return Boolean;

   function Resolve_Group_Id (Text : String; Value : out Natural) return Boolean;

   function Resolve_User_Id (Text : String; Value : out Natural) return Boolean;

   function Group_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String;

   function User_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String;

   function Decorated_Group_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String;

   function Decorated_User_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String;

   function Current_User_Name
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return String;

   generic
      with procedure Action (Path : String);
   procedure For_Each_Directory_Child
     (Path   : String;
      Listed : out Boolean);

   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Default     : String);

   procedure Subject_Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Subject     : String;
      Message_Key : String;
      Default     : String);

   --  Report Message_Key's message, its placeholder Name filled in by
   --  Value, escaped. Default is the English text with "{Name}" where Value
   --  goes.
   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Name        : String;
      Value       : String;
      Default     : String);

   --  What a diagnostic calls standard input, in the messages locale.
   function Standard_Input_Name
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return String;

   --  What a diagnostic calls the file operand File_Name: standard input
   --  for "-", else File_Name itself.
   function File_Subject
     (Context   : Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String) return String;

   --  The subject of an unknown-option diagnostic for Argument, an option
   --  argument the command does not take: "-" and its first option
   --  character Accepted does not list, or Argument itself when it is a
   --  long option or lists none.
   function Unknown_Option_Subject (Argument : String; Accepted : String) return String;

   --  Parse the options in front of Context's operands as the POSIX utility
   --  syntax guidelines have them: flags may be grouped behind one "-", an
   --  option's argument may be attached or the next argument, and "--" ends
   --  the options. Accepted lists the option characters, Requires_Argument
   --  those of them that take an argument. Handle is called with each
   --  option in turn and its argument, "" for a flag; it reports a usage
   --  error itself, into Result, and sets Valid to False to stop. An
   --  unknown option or a missing option argument is reported here. First
   --  is the index of the first operand. Valid is False when a usage error
   --  has been reported. A command that also takes long flags, such as
   --  "--follow", lists them in Long_Options, separated by spaces; each is
   --  handled as the flag Long_Name.
   generic
      with procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);
      Long_Options : String := "";
      Long_Name    : Character := Character'Val (0);
   procedure Parse_Options
     (Context           : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result            : in out Posix_Tools.Commands.Results.Result;
      Accepted          : String;
      Requires_Argument : String;
      First             : out Positive;
      Valid             : out Boolean);
end Posix_Tools.Commands.Helpers;
