separate (Posix_Tools.Host_Adapters.File_System)
procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean) is
   Search      : Ada.Directories.Search_Type;
   Search_Open : Boolean := False;
   Dir_Entry   : Ada.Directories.Directory_Entry_Type;
   Stop        : Boolean := False;
   Callback_Active : aliased Boolean := False;

   procedure Close_Search (Cleanup_Ok : in out Boolean);

   procedure Close_Search (Cleanup_Ok : in out Boolean) is
   begin
      if Search_Open then
         Ada.Directories.End_Search (Search);
         Search_Open := False;
      end if;
   exception
      when others =>
         --  intentional terminal exception barrier
         Cleanup_Ok := False;
         Search_Open := False;
   end Close_Search;

   procedure Invoke_Action is new Invoke_Directory_Callback
     (Callback => Action);
begin
   Ok := True;
   Ada.Directories.Start_Search (Search, Path, "*");
   Search_Open := True;
   while not Stop and then Ada.Directories.More_Entries (Search) loop
      Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
      declare
         Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
      begin
         if Name /= "." and then Name /= ".." then
            Invoke_Action
              (Name, Ada.Directories.Full_Name (Dir_Entry), Stop,
               Callback_Active'Access);
         end if;
      end;
   end loop;
   Close_Search (Ok);
exception
   when others =>
      declare
         Cleanup_Ok : Boolean := False;
      begin
         Close_Search (Cleanup_Ok);
      end;
      if Callback_Active then
         raise;
      end if;
      Ok := False;
end For_Each_Directory_Entry;
