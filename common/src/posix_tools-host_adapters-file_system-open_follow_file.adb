separate (Posix_Tools.Host_Adapters.File_System)
procedure Open_Follow_File
  (Path             : String;
   File             : in out Follow_File;
   Status           : out Follow_Open_Status;
   Require_Identity : Boolean := False)
is
   use type Hostkit.Metadata.Entry_Identity;

   Maximum_Attempts : constant Positive := 3;
   Before           : Hostkit.Metadata.Entry_Identity;
   After            : Hostkit.Metadata.Entry_Identity;
   Before_Status    : Follow_Open_Status;
   After_Status     : Follow_Open_Status;
   Opened_Identity  : Hostkit.Metadata.Entry_Identity;

   function Same_Object
     (Opened : Hostkit.Metadata.Entry_Identity;
      Named  : Hostkit.Metadata.Entry_Identity) return Boolean
   is (Opened.Available and then Named.Available and then Opened = Named);
begin
   Close_Follow_File (File);
   for Attempt in 1 .. Maximum_Attempts loop
      Before_Status := Path_Identity (Path, Before);
      if Before_Status = Follow_Missing then
         Status := Follow_Missing;
         return;
      end if;

      --  The follow-safe mode guarantees the open itself cannot wait for a
      --  FIFO peer.  Classify the object through the resulting descriptor,
      --  so pathname replacement cannot attach the wrong follow strategy.
      if not Hostkit.Descriptors.Open_File
        (Path, Hostkit.Descriptors.Open_Read_For_Following, File.Handle)
      then
         Close_Follow_File (File);
         Status := Follow_Error;
         return;
      end if;

      case Hostkit.Descriptors.Positioning_Of (File.Handle) is
         when Hostkit.Descriptors.Positioning_Seekable =>
            File.Handle_Kind := Follow_Seekable;
         when Hostkit.Descriptors.Positioning_Sequential =>
            File.Handle_Kind := Follow_Sequential;
            File.Sequential_Non_Blocking :=
              Hostkit.Descriptors.Set_Non_Blocking (File.Handle, True);
         when Hostkit.Descriptors.Positioning_Unknown =>
            Close_Follow_File (File);
            Status := Follow_Error;
            return;
      end case;
      Opened_Identity := Hostkit.Descriptors.Identity_Of (File.Handle);
      After_Status := Path_Identity (Path, After);
      if After_Status = Follow_Missing then
         Close_Follow_File (File);
         Status := Follow_Missing;
         return;
      end if;

      if Before_Status = Follow_Ready
        and then After_Status = Follow_Ready
        and then Before.Available
        and then After.Available
      then
         if Before = After and then Same_Object (Opened_Identity, After) then
            File.Identity := After;
            Status := Follow_Ready;
            return;
         end if;

         --  Either the pathname changed, or the opened descriptor does not
         --  hold the object named by the final observation.  Its identity is
         --  stable even if the pathname was replaced and restored (ABA).
         Close_Follow_File (File);
         if Attempt = Maximum_Attempts then
            Status := Follow_Error;
            return;
         end if;
      elsif Before.Available /= After.Available
        or else Before_Status /= After_Status
      then
         --  Identity became available or unavailable during the open.
         --  Treat that transition like a pathname race and try again.
         Close_Follow_File (File);
         if Attempt = Maximum_Attempts then
            Status := Follow_Error;
            return;
         end if;
      elsif Require_Identity then
         Close_Follow_File (File);
         Status := Follow_Error;
         return;
      else
         --  Descriptor following remains useful on hosts without stable
         --  identities. Name following will reopen once an identity later
         --  becomes available, instead of attaching it to this unverified
         --  descriptor.
         File.Identity := (others => <>);
         Status := Follow_Ready;
         return;
      end if;
   end loop;

   Status := Follow_Error;
exception
   when Ada.IO_Exceptions.Name_Error =>
      Close_Follow_File (File);
      Status := Follow_Missing;
   when others =>
      Close_Follow_File (File);
      Status := Follow_Error;
end Open_Follow_File;
