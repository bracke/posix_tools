package body Posix_Tools.File_Operations is
   function Cancelled (Self : in out Observer) return Boolean is
      pragma Unreferenced (Self);
   begin
      return False;
   end Cancelled;

   function Confirm_Removal (Self : in out Observer; Path : String; Question : Removal_Question) return Boolean is
      pragma Unreferenced (Self, Path, Question);
   begin
      return True;
   end Confirm_Removal;

   function Default_Message (Error : Operation_Error) return String is
   begin
      case Error is
         when Cannot_Read =>
            return "cannot read file";
         when Cannot_Open =>
            return "cannot open file";
         when Cannot_Remove =>
            return "cannot remove";
         when Cannot_Move =>
            return "cannot move";
         when Is_A_Directory =>
            return "is a directory";
         when Not_A_Directory =>
            return "not a directory";
         when Same_File =>
            return "source and destination are the same file";
         when Cannot_Read_Directory =>
            return "cannot read directory";
         when Unsupported_Type =>
            return "unsupported file type";
         when No_Such_File =>
            return "no such file or directory";
         when Directory_Not_Empty =>
            return "directory not empty";
         when File_Exists =>
            return "file exists";
         when File_System_Loop =>
            return "file system loop detected";
      end case;
   end Default_Message;

   function Message_Key (Error : Operation_Error) return String is
   begin
      case Error is
         when Cannot_Read =>
            return "posix_tools.diagnostic.file.read_failed";
         when Cannot_Open =>
            return "posix_tools.diagnostic.file.open_failed";
         when Cannot_Remove =>
            return "posix_tools.diagnostic.file.remove_failed";
         when Cannot_Move =>
            return "posix_tools.diagnostic.file.move_failed";
         when Is_A_Directory =>
            return "posix_tools.diagnostic.file.is_directory";
         when Not_A_Directory =>
            return "posix_tools.diagnostic.file.not_directory";
         when Same_File =>
            return "posix_tools.diagnostic.file.same_file";
         when Cannot_Read_Directory =>
            return "posix_tools.diagnostic.file.read_directory_failed";
         when Unsupported_Type =>
            return "posix_tools.diagnostic.file.unsupported_type";
         when No_Such_File =>
            return "posix_tools.diagnostic.file.missing";
         when Directory_Not_Empty =>
            return "posix_tools.diagnostic.file.not_empty";
         when File_Exists =>
            return "posix_tools.diagnostic.file.exists";
         when File_System_Loop =>
            return "posix_tools.diagnostic.file.loop";
      end case;
   end Message_Key;

   function Resolve_Conflict (Self : in out Observer; Source, Target : String) return Conflict_Choice is
      pragma Unreferenced (Self, Source, Target);
   begin
      return Overwrite;
   end Resolve_Conflict;
end Posix_Tools.File_Operations;
