unit kn_NoteFileMng;

(****** LICENSE INFORMATION **************************************************
 
 - This Source Code Form is subject to the terms of the Mozilla Public
 - License, v. 2.0. If a copy of the MPL was not distributed with this
 - file, You can obtain one at http://mozilla.org/MPL/2.0/.           
 
------------------------------------------------------------------------------
 (c) 2000-2005 Marek Jedlinski <marek@tranglos.com> (Poland)
 (c) 2007-2015 Daniel Prado Velasco <dprado.keynote@gmail.com> (Spain) [^]

 [^]: Changes since v. 1.7.0. Fore more information, please see 'README.md'
     and 'doc/README_SourceCode.txt' in https://github.com/dpradov/keynote-nf      
   
 *****************************************************************************) 


interface
uses
   Classes, wideStrings, kn_const, kn_Info;

    function NoteFileNew( FN : string ) : integer; // create new KNT file with 1 blank note
    function NoteFileOpen( FN : wideString ) : integer; // open KNT file on disk
    function NoteFileSave( FN : wideString ) : integer; // save current KNT file
    function NoteFileClose : boolean; // close current KNT file

    procedure NewFileRequest( FN : string );
    procedure NoteFileCopy;
    procedure MergeFromKNTFile( MergeFN : string );

    function CheckFolder( const name, folder : string; const AttemptCreate, Prompt : boolean ) : boolean;
    procedure FolderChanged;
    procedure SomeoneChangedOurFile;

    function CheckModified( const Warn : boolean; const closing: boolean ) : boolean;

    procedure ImportFiles;
    procedure ImportAsNotes( ImportFileList : TWideStringList );

    procedure FileDropped( Sender : TObject; FileList : TWideStringList );
    function ConsistentFileType( const aList : TWideStringList ) : boolean;
    function PromptForFileAction( const FileCnt : integer; const aExt : string ) : TDropFileAction;

    procedure NoteFileProperties;
    procedure UpdateNoteFileState( AState : TFileStateChangeSet );

    procedure AutoCloseFile;
    procedure RunFileManager;

    function CanRegisterFileType : boolean;
    procedure AssociateKeyNoteFile;

implementation

uses
  { Borland units }
  Windows, Messages, SysUtils, StrUtils,
  Graphics, Controls, Forms, Dialogs, DateUtils,
  { 3rd-party units }
  BrowseDr, TreeNT, TntSysUtils, ZLibEx,
  { Own units - covered by KeyNote's MPL}
  gf_misc, gf_files,
  gf_strings, gf_miscvcl, gf_FileAssoc, gf_streams,
  kn_INI, kn_Cmd, kn_Msgs,
  kn_NoteObj, kn_FileObj, kn_NewNote,
  kn_FileInfo,kn_FileDropAction,
  kn_NodeList,
  kn_Macro, kn_MacroEdit, kn_MacroCmd,
  kn_filemgr,
  kn_ExpandObj,
  kn_VirtualNodeMng,
  kn_ConfigMng,
  kn_MacroMng,
  kn_LocationObj,
  Kn_Global, kn_Chest,
  kn_NoteMng, kn_EditorUtils,
  kn_BookmarksMng,
  kn_TabSelect,
  kn_Main, kn_LinksMng, kn_PluginsMng, kn_TreeNoteMng, kn_VCLControlsMng,
  kn_ExportImport;

type
   TMergeNotes = record
       oldID: integer;
       newID: integer;
       newNote: boolean;
   end;



resourcestring
  STR_01 = 'Cannot create a new file: ';
  STR_02 = ' New Note file created.';
  STR_03 = '(none)';
  STR_04 = 'A new Note file has been created. Would you like to save the new file now?' +#13#13+ '(The Auto Save function will not work until the file is named and saved first.)';
  STR_05 = 'Open Keynote file';
  STR_06 = ' Opening ';
  STR_07 = 'One or more errors occurred while loading the file. The file may not have loaded completely. To minimize the risk of data loss, ' +
                          'the file was opened in Read-Only mode. Use the "Save As..." command to save the file.';
  STR_08 = ' <unknown> ';
  STR_09 = ' diskette ';
  STR_10 = ' network ';
  STR_11 = ' CD-ROM ';
  STR_12 = ' RAM ';
  STR_13 = 'File "%s" was opened in Read-Only mode, because it resides on a %s drive "%s".';
  STR_14 = ' File opened.';
  STR_15 = ' Error.';
  STR_16 = 'Folder monitor error: ';
  STR_17 = ' ERROR %d opening file';
  STR_18 = 'This file will be saved as a %s file. This format does not support some features which are unique to %s.' + #13#13 +
                                     'OK to save the file in Dart Notes format? If you answer NO, the file will be saved as a %s file.';
  STR_19 = ' Saving ';
  STR_20 = 'Specified backup directory "%s" does not exist. Backup files will be created in the original file''s directory.';
  STR_21 = 'Cannot create backup file (error %d: %s). Current file will not be backed up. Proceed anyway?';
  STR_22 = ' File saved.';
  STR_23 = ' Error %d while saving file.';
  STR_24 = 'Error %d occurred while saving file "%s". The file is probably damaged. ';
  STR_25 = 'You should be able to restore data from the backup file "%s". ';
  STR_26 = 'The Auto-Save option was turned OFF, to prevent KeyNote from automatically saving the damaged file.';
  STR_27 = ' ERROR saving file';
  STR_28 = 'Saving "';
  STR_29 = 'Folder monitoring has been disabled due to the following error: ';
  STR_30 = ' File closed.';
  STR_31 = 'Revert to last saved version of' + #13 + '%s?';
  STR_32 = 'Select backup folder';
  STR_33 = 'Cannot copy file to its own directory.';
  STR_34 = 'The file %s already exists. OK to overwrite existing file?';
  STR_35 = ' Copying file...';
  STR_36 = ' File copied.';
  STR_37 = 'Successfully copied Notes file to';
  STR_38 = 'Copying failed (';
  STR_39 = 'Select file to merge notes from';
  STR_40 = 'There was an error while loading merge file.';
  STR_41 = 'The file you selected does not contain any notes.';
  STR_42 = 'Error while loading merge file: ';
  STR_43 = 'Notes in %s';
  STR_44 = 'You did not select any notes: nothing to merge.';
  STR_45 = ' Merging notes...';
  STR_46 = 'Error while adding notes: ';
  STR_47 = 'Merged %d notes from "%s"';
  STR_48 = 'No notes were merged';
  STR_49 = 'Another application has modified the note file %s. Reload the file from disk?';
  STR_50 = '%s folder "%s" does not exist';
  STR_51 = '. Create the folder now?';
  STR_52 = 'Could not create folder: %s';
  STR_53 = ' File modified by external application.';
  STR_54 = 'Notes were modified. Save file before continuing?' +#13+ 'If you answer No, you will lose all changes made since last save.';
  STR_55 = 'Current file has not been saved. If you continue, changes will be lost.'+ #13 + 'Proceed anyway?';
  STR_56 = 'Warning!';
  STR_57 = 'Select files for importing';
  STR_58 = 'The file "%s" does not appear to be a text file. The result of importing it may be unpredictable.' + #13#13 +
                'Import as a plain text file, anyway?';
  STR_59 = ' Importing ';
  STR_60 = 'Failed to convert HTML file "%s" to RTF';
  STR_61 = 'Error importing ';
  STR_62 = ' Finished importing.';
  STR_63 = 'Cannot select methods for handling files.';
  STR_64 = 'Files you are trying to import are of more than one type. Please select only files of one type for importing.';
  STR_65 = 'Cannot import a directory "%s"';
  STR_67 = 'Unknown or unexpected file action (%d)';
  STR_68 = 'Error while importing files: ';
  STR_69 = 'Untitled';
  STR_70 = ' No file ';
  STR_71 = ' (no file)';
  STR_72 = ' Auto';
  STR_73 = ' MOD';
  STR_74 = ' Saved';
  STR_75 = 'Successfully created %s registry entries';
  STR_76 = 'There was an error while creating file type associations: ';
  STR_77 = 'This file is Read-Only. Use "Save As" command to save it with a new name.';
  IntervalBAKDay = '_BAK_Day.knt';
  IntervalPrefixBAK = '_BAK@';
  STR_78 = 'Backup at %s before any modification in "%s"';
  STR_79 = 'File is not modified. Nothing to save';


//=================================================================
// NoteFileNew
//=================================================================
function NoteFileNew( FN : string ) : integer;
begin
  MovingTreeNode:= nil;
  AlarmManager.Clear;
  MirrorNodes.Clear;

  with Form_Main do begin
        result := -1;
        _REOPEN_AUTOCLOSED_FILE := false;
        if FileIsBusy then exit;
        Virtual_UnEncrypt_Warning_Done := false;
        try
          try
            if assigned( NoteFile ) then
              if ( not NoteFileClose ) then exit;
            result := 0;
            FolderMon.Active := false;
            FileIsBusy := true;
            Pages.MarkedPage := nil;

            if ( DEF_FN <> OrigDEF_FN ) then
            begin
              DEF_FN := OrigDEF_FN;
            end;

            LoadDefaults;
            LoadTabImages( false );

            NoteFile := TNoteFile.Create;
            NoteFile.PageCtrl := Pages;
            NoteFile.PassphraseFunc := GetFilePassphrase;
            NoteFile.FileFormat := KeyOptions.SaveDefaultFormat;

            if ( KeyOptions.RunAutoMacros and fileexists( _MACRO_AUTORUN_NEW_FILE )) then
            begin
              Application.ProcessMessages;
              ExecuteMacro( _MACRO_AUTORUN_NEW_FILE, '' );
            end
            else
            begin
              NewNote( true, false, KeyOptions.StartNoteType );
            end;

          except
            on E : Exception do
            begin
              {$IFDEF MJ_DEBUG}
              Log.Add( 'Exception in NoteFileNew: ' + E.Message );
              {$ENDIF}
              Popupmessage( STR_01 + E.Message, mtError, [mbOK], 0 );
              result := 1;
              exit;
            end;
          end;
        finally
          LastEditCmd := ecNone;
          MMEditRepeat.Enabled := false;
          RTFMRepeatCmd.Enabled := false;
          TB_Repeat.ENabled := false;

          StatusBar.Panels[PANEL_HINT].Text := STR_02;

          UpdateNoteFileState( [fscNew,fscModified] );
          {$IFDEF MJ_DEBUG}
          Log.Add( 'NoteFileNew result: ' + inttostr( result ));
          {$ENDIF}
          FileIsBusy := false;
          if ( Pages.PageCount > 0 ) then
          begin
            ActiveNote := TTabNote( Pages.ActivePage.PrimaryObject );
            TAM_ActiveName.Caption := ActiveNote.Name;
            FocusActiveNote;
          end
          else
          begin
            ActiveNote := nil;
            TAM_ActiveName.Caption := STR_03;
          end;
          UpdateNoteDisplay;

          if ( assigned( ActiveNote ) and KeyOptions.RunAutoMacros ) then
          begin

            case ActiveNote.Kind of
              ntRTF : if fileexists( Macro_Folder + _MACRO_AUTORUN_NEW_NOTE ) then
              begin
                Application.ProcessMessages;
                ExecuteMacro( _MACRO_AUTORUN_NEW_NOTE, '' );
              end;
              ntTree : if fileexists( Macro_Folder + _MACRO_AUTORUN_NEW_TREE ) then
              begin
                Application.ProcessMessages;
                ExecuteMacro( _MACRO_AUTORUN_NEW_TREE, '' );
              end;
            end;
          end;

        end;

        if ( KeyOptions.AutoSave and ( not KeyOptions.SkipNewFilePrompt )) then
        begin
          if ( PopupMessage( STR_04, mtConfirmation, [mbYes,mbNo], 0 ) = mrYes ) then
            NoteFileSave( NoteFile.FileName );
        end;
  end;

end; // NoteFileNew



//=================================================================
// NoteFileOpen
//=================================================================

function NoteFileOpen( FN : wideString ) : integer;
var
  i : integer;
  OpenReadOnly : boolean;
  OpenBegin {$IFDEF MJ_DEBUG}, OpenEnd{$ENDIF} : integer;
  opensuccess : boolean;
  FPath, NastyDriveType : wideString;
begin
  with Form_Main do begin
        _REOPEN_AUTOCLOSED_FILE := false;
        MovingTreeNode:= nil;
        AlarmManager.Clear;
        MirrorNodes.Clear;
        OpenBegin := GetTickCount;
        OpenReadOnly := false;
        opensuccess := false;
        result := -1;
        Virtual_UnEncrypt_Warning_Done := false;
        if FileIsBusy then exit;
        try
          try
            FolderMon.Active := false;
            if ( FN = '' ) then
            begin
              with OpenDlg do
              begin
                Title := STR_05;
                Filter := FILTER_NOTEFILES + '|' + FILTER_DARTFILES + '|' + FILTER_ALLFILES;
                Options := Options - [ofHideReadOnly];
                Options := Options - [ofAllowMultiSelect];
                if ( KeyOptions.LastFile <> '' ) then
                  InitialDir := WideExtractfilepath( KeyOptions.LastFile )
                else
                  InitialDir := GetFolderPath( fpPersonal );
              end;
              try
                if OpenDlg.Execute then
                begin
                  FN := OpenDlg.FileName;
                  OpenReadOnly := ( ofReadOnly in OpenDlg.Options );
                end
                else
                begin
                  exit;
                end;
              finally
                OpenDlg.Options := OpenDlg.Options + [ofHideReadOnly];
              end;
            end;
            FN := normalFN( FN );
            if ( wideExtractfileext( FN ) = '' ) then
              FN := FN + ext_KeyNote;

            if assigned( NoteFile ) then
              if ( not NoteFileClose ) then exit;
            StatusBar.Panels[PANEL_HINT].Text := STR_06 + FN;

            Timer.Enabled := false;
            screen.Cursor := crHourGlass;
            FileIsBusy := true;
            result := 0;
            NoteFile := TNoteFile.Create;
            NoteFile.PassphraseFunc := GetFilePassphrase;
            NoteFile.PageCtrl := Pages;

            // NoteFile.OnNoteLoad := OnNoteLoaded;
            result := NoteFile.Load( FN );

            for i := 0 to NoteFile.Notes.Count -1 do
            begin
              NoteFile.Notes[i].AddProcessedAlarms();
            end;

            if ( result <> 0 ) then
            begin
              NoteFile.ReadOnly := true;
              result := 0;
              messagedlg( STR_07, mtWarning, [mbOK] , 0 );
            end;

            if wideFileexists( NoteFile.FileName + ext_DEFAULTS ) then
              DEF_FN := NoteFile.FileName + ext_DEFAULTS
            else
              DEF_FN := OrigDEF_FN;
            LoadDefaults;

            NastyDriveType := '';
            case GetDriveType( PChar( ExtractFileDrive( NoteFile.FileName ) + '\' )) of
              0, 1 : begin
                NastyDriveType := STR_08;
              end;
              DRIVE_REMOVABLE : begin
                if KeyOptions.OpenFloppyReadOnly then
                  NastyDriveType := STR_09;
              end;
              DRIVE_REMOTE : begin
                if KeyOptions.OpenNetworkReadOnly then
                  NastyDriveType := STR_10;
              end;
              DRIVE_CDROM : begin
                NastyDriveType := STR_11;
              end;
              DRIVE_RAMDISK : begin
                NastyDriveType := STR_12;
              end;
            end;
            if ( NastyDriveType <> '' ) then
            begin
              NoteFile.ReadOnly := true;
              if KeyOptions.OpenReadOnlyWarn then
                popupmessage( WideFormat(
                  STR_13,
                  [WideExtractFilename( NoteFile.FileName ), NastyDriveType, ExtractFileDrive( NoteFile.FileName )] ),
                  mtInformation, [mbOK], 0 );
            end;

            LastEditCmd := ecNone;
            MMEditRepeat.Enabled := false;
            RTFMRepeatCmd.Enabled := false;
            TB_Repeat.Enabled := false;

            // LoadDefaults;
            LoadTabImages( false );

            CreateVCLControls;
            NoteFile.SetupMirrorNodes(nil);
            SetupAndShowVCLControls;

            opensuccess := true;

            StatusBar.Panels[PANEL_HINT].Text := STR_14;

            try
              if EditorOptions.SaveCaretPos then
              begin
                for i := 1 to NoteFile.Notes.Count do
                begin
                  with NoteFile.Notes[pred( i )] do
                  begin
                    case Kind of
                      ntRTF : begin
                        Editor.OnSelectionChange := nil;
                        try
                          Editor.Selstart := CaretPos.X;
                        finally
                          Editor.OnSelectionChange := RxRTFSelectionChange;
                        end;
                      end;
                    end;
                  end;
                end;
              end;

              if ClipOptions.Recall then
              begin
                if assigned( NoteFile.ClipCapNote ) then
                  ToggleClipCap( true, NoteFile.ClipCapNote );
              end
              else
              begin
                NoteFile.ClipCapNote := nil;
              end;

              LoadTrayIcon( assigned( NoteFile.ClipCapNote ) and ClipOptions.SwitchIcon );

            except
            end;

          except
            on E : Exception do
            begin
              opensuccess := false;
              StatusBar.Panels[PANEL_HINT].Text := STR_15;
              {$IFDEF MJ_DEBUG}
              Log.Add( 'Error while opening file: ' + E.Message );
              {$ENDIF}
              if E.Message <> '' then
                 PopupMessage( E.Message, mtError, [mbOK,mbHelp], _HLP_KNTFILES );
              if assigned( NoteFile ) then
              begin
                NoteFile.Free;
                NoteFile := nil;
              end;
              result := 1;
            end;
          end;

          try
            if opensuccess then
            begin
              GetFileState( NoteFile.FileName, FileState );
              FPath := extractfilepath( NoteFile.FileName );
              FolderMon.FolderName := copy( FPath, 1, pred( length( FPath )));
              // prevent folder monitor if file resides on a read-only medium
              // diskette or network
              FolderMon.Active := (( not KeyOptions.DisableFileMon ) and ( NastyDriveType = '' ));
            end;
          except
            on E : Exception do
            begin
              {$IFDEF MJ_DEBUG}
              Log.Add( 'Folder monitor error: ' + E.Message );
              {$ENDIF}
              PopupMessage( STR_16 + E.Message, mtError, [mbOK], 0 );
            end;
          end;

        finally
          {$IFDEF MJ_DEBUG}
          Log.Add( 'NoteFileOpen result: ' + inttostr( result ));
          {$ENDIF}
          if opensuccess then
          begin
            if ( Pages.PageCount > 0 ) then
            begin
              ActiveNote := TTabNote( Pages.ActivePage.PrimaryObject );
              TAM_ActiveName.Caption := ActiveNote.Name;
              FocusActiveNote;
            end
            else
            begin
              TAM_ActiveName.Caption := STR_03;
              ActiveNote := nil;
            end;
            if assigned( NoteFile ) then
            begin
              NoteFile.ReadOnly := ( OpenReadOnly or NoteFile.ReadOnly );
              NoteFile.Modified := false;
            end;
            UpdateNoteDisplay;
            UpdateNoteFileState( [fscOpen,fscModified] );
          end;
          screen.Cursor := crDefault;
          FileIsBusy := false;
          Timer.Enabled := true;
        end;


        if ( result = 0 ) then
        begin
          KeyOptions.LastFile := FN;
          if KeyOptions.MRUUse then
            MRU.AddItem( FN );
          AddToFileManager( FN, NoteFile );
        end
        else
        begin
          StatusBar.Panels[PANEL_HINT].Text := Format( STR_17, [result] );
        end;

        {$IFDEF MJ_DEBUG}
        OpenEnd := GetTickCount;
        Log.Add( 'File load time in seconds: ' + inttostr(( OpenEnd - OpenBegin ) DIV 1000 ));
        {$ENDIF}
  end;
end; // NoteFileOpen



//=================================================================
// NoteFileSave
//=================================================================

function ExistingBackup(const Folder, FileName: WideString;
                        FileModificationDate: TDateTime;
                        ConsiderAlsoModifiedLater: Boolean) : WideString;
var
   DirInfo : TSearchRecW;
   FindResult : Integer;
   Mask : WideString;
   Consider: Boolean;
   FileDateTime: TDateTime;
begin
   Result := '';
   Mask := WideChangeFileExt(Folder + FileName, IntervalPrefixBAK + '*' + ext_KeyNote);

   FindResult := WideFindFirst(Mask, faAnyFile, DirInfo);
   Consider:= False;
   while FindResult = 0 do begin
     FileDateTime:= FileDateToDateTime(DirInfo.Time);
     if ConsiderAlsoModifiedLater then begin
        if FileDateTime >= FileModificationDate then Consider := True;
     end
     else begin
        if FileDateTime = FileModificationDate then Consider := True;
     end;

     if Consider then begin
        Result := DirInfo.Name;
        break;
        end
     else
        FindResult := WideFindNext(DirInfo);
   end;
   WideFindClose(DirInfo);
end;


//------ DoBackup ------------------------------------------------

{ Backup BEFORE save operation }

function DoBackup(const FN: WideString; var BakFN: WideString; var BakFolder: WideString;
                  var SUCCESS: LongBool; var LastError: Integer): Boolean;
var
  ext, bakFNfrom, bakFNto, FileName: WideString;
  DayBakFN, DayBakFN_Txt: WideString;
  myBackupLevel, bakindex : Integer;
  FirstSaveInDay: Boolean;

begin
   // if file has tree notes with virtual nodes, they should be backed up as well.
   // We use ugly global vars to pass backup options:

   _VNDoBackup     := KeyOptions.Backup and KeyOptions.BackupVNodes;
   _VNBackupExt    := KeyOptions.BackupExt;
   _VNBackupAddExt := KeyOptions.BackupAppendExt;
   _VNBackupDir    := KeyOptions.BackupDir;


   // Check if backup must be done
   //--------------------

   { If Backup = True (classic, cyclic way), or
     If BackupRegularIntervals = True and it is the first time we save this day
         (there is no Interval BAK day or it corresponds to other day)

     In both cases, it won't be necessary to create a new backup if there is
     one already available. This can occur if last save did match with a
     montly or weekly backup. (A copy of the saved file was taken)
   }

   Result := True;

   case GetDriveType(PChar(ExtractFileDrive(NoteFile.FileName) + '\')) of
     DRIVE_REMOVABLE: Result := (not KeyOptions.OpenFloppyReadOnly);
     DRIVE_REMOTE:    Result := (not KeyOptions.OpenNetworkReadOnly);
     0, 1,
     DRIVE_CDROM,
     DRIVE_RAMDISK:   Result := false;
   end;


   if Result then begin
      FileName:= WideExtractFilename(FN);

      // Check if alternate backup directory exists
      if KeyOptions.BackupDir <> '' then begin
        if not WideDirectoryExists(KeyOptions.BackupDir) then begin
          DoMessageBox(
            Format(STR_20, [KeyOptions.BackupDir]),
            mtWarning, [mbOK], 0);
          KeyOptions.BackupDir := '';
        end;
      end;
      if KeyOptions.BackupDir <> '' then
         bakFolder:= ProperFolderName(KeyOptions.BackupDir)
      else
         bakFolder:= WideExtractFilePath(FN);


      if KeyOptions.BackupRegularIntervals then begin
         // Is it the first time we save this day? (there is no Interval BAK day or it corresponds to other day)
         FirstSaveInDay:= False;
         DayBakFN := WideChangeFileExt(bakFolder + FileName, IntervalBAKDay);
         DayBakFN_Txt:= DayBakFN + '.TXT';
         if not WideFileExists(DayBakFN_Txt) or
            (RecodeTime(GetFileDateStamp(DayBakFN_Txt), 0,0,0,0) <> Date) then
             FirstSaveInDay:= True;
      end;

      if not (KeyOptions.Backup or
             (KeyOptions.BackupRegularIntervals and FirstSaveInDay))
         or not WideFileExists(FN) then
         Result := false;
   end;

   if not Result then begin      // Backup needs not be done
      BakFN:= '';
      Exit;                      // EXIT
   end;


   // Backup must be done (if not already available)
   //---------------------------

   // Backup already available?
   BakFN:= ExistingBackup(bakFolder, fileName, GetFileDateStamp(FN), False);

   if BakFN <> '' then begin
      SUCCESS:= True;
      if KeyOptions.BackupRegularIntervals and FirstSaveInDay then begin
         DeleteFileW(PWideChar(DayBakFN));
         SaveToFile(DayBakFN_Txt, Format(STR_78, [DateToStr(Date), BakFN]));
      end;
      Exit;                      // EXIT
   end;


   if KeyOptions.BackupRegularIntervals and FirstSaveInDay then
      BakFN:= DayBakFN

   else begin
       // Necessarily KeyOptions.Backup must be True at this point

       // Adjust how backup extension is added
       bakFN := bakFolder + FileName;
       if KeyOptions.BackupAppendExt then
          bakFN := bakFN + KeyOptions.BackupExt
       else
          bakFN := WideChangeFileExt(bakFN, KeyOptions.BackupExt);


       myBackupLevel := KeyOptions.BackupLevel;
       if NoteFile.NoMultiBackup then
          myBackupLevel := 1;

       if myBackupLevel > 1 then begin
         // recycle bak..bakN files, discarding the file
         // with the highest number (up to .bak9)
         for bakIndex := Pred(myBackupLevel) downto 1 do begin
            bakFNfrom:= bakFN;
            if bakIndex > 1 then
               bakFNfrom := bakFN + IntToStr(bakIndex);
            bakFNto := bakFN + IntToStr(Succ(bakIndex));
            if WideFileExists(bakFNfrom) then
                 MoveFileExW_n(bakFNfrom, bakFNto, 3);
         end; // for
       end;
   end;

   SUCCESS := MoveFileExW_n(FN, BakFN, 3);


   if KeyOptions.BackupRegularIntervals and FirstSaveInDay then
      SaveToFile(DayBakFN_Txt, Format(STR_78, [DateToStr(Date), BakFN]));

   if not SUCCESS then begin
      bakFN:= '';
      LastError := GetLastError;
      {$IFDEF MJ_DEBUG}
      Log.Add('Backup failed; code ' + IntToStr(LastError));
      {$ENDIF}
   end;

end;


//------ DoIntervalBackup ------------------------------------------------

{ Backup AFTER save operation }

procedure DoIntervalBackup(FN : WideString; BakFolder: WideString);
var
   Year, Month, Day: Word;
   dayOfW, bakIndex: Integer;
   BeginOfWeek: TDateTime;
   FileName, BakFN: WideString;
   bakFNfrom, bakFNTo: WideString;
begin
   if not KeyOptions.BackupRegularIntervals then Exit;

   DecodeDate(Date, Year, Month, Day);
   FileName:= WideExtractFilename(FN);

   BakFN := WideFormat(
               WideChangeFileExt(BakFolder + '\' + FileName,
                  IntervalPrefixBAK + '%d_%.2d' + ext_KeyNote), [Year, Month]);

   if not WideFileExists(BakFN) then
      CopyFileW(PWideChar(FN), PWideChar(BakFN), False)   // Monthly backup

   else begin
      dayOfW:= DayOfTheWeek(Date);
      BeginOfWeek:= IncDay(Date, -dayOfW + 1);

      BakFN:= ExistingBackup(bakFolder, FileName, BeginOfWeek, True);
      if BakFN = '' then begin
         // There is no backup (weekly of monthly) for this week. We'll create
         // a weekly one, cycling the others (up to 4)
         BakFN := WideChangeFileExt(BakFolder + '\' + FileName, IntervalPrefixBAK + 'W');

         for bakIndex := Pred(4) downto 1 do begin
            bakFNfrom := BakFN + IntToStr(bakIndex)       + ext_KeyNote;
            bakFNto   := BakFN + IntToStr(Succ(bakIndex)) + ext_KeyNote;
            if WideFileExists(bakFNfrom) then
               MoveFileExW(
                  PWideChar(bakFNfrom), PWideChar(bakFNto),
                  MOVEFILE_REPLACE_EXISTING or MOVEFILE_COPY_ALLOWED);
         end; // for
         CopyFileW(PWideChar(FN), PWideChar(BakFN + '1' + ext_KeyNote), False);   // Weekly backup
      end;

   end;

end;

//------ NoteFileSave --------------------------------------------

function NoteFileSave(FN : WideString) : integer;
var
  ErrStr, ext, BakFN, BakFolder, FPath: WideString;
  SUCCESS: LongBool;
  i, LastError: Integer;
  myNote: TTabNote;

begin
  with Form_Main do begin
     result := -1;
     if not HaveNotes(true, false) then Exit;
     if FileIsBusy then Exit;

     if (FN <> '') and NoteFile.ReadOnly then begin
         DoMessageBox(STR_77, mtWarning, [mbOK], 0);
         Exit;
     end;

     if (FN <> '') and not NoteFile.Modified then begin
         DoMessageBox(STR_79, mtInformation, [mbOK], 0);
         Exit;
     end;

     ErrStr := '';

     SUCCESS := LongBool(0);
     try
       try
         FileIsBusy := true;
         FolderMon.Active := false;
         if not HaveNotes(true, false) then exit;

         if FN <> '' then begin
            FN := NormalFN(FN);
            case NoteFile.FileFormat of
               nffKeyNote: FN := WideChangeFileExt(FN, ext_KeyNote);
               nffEncrypted:
                  if KeyOptions.EncFileAltExt then
                     FN := WideChangeFileExt(FN, ext_Encrypted)
                  else
                     FN := WideChangefileext(FN, ext_KeyNote);
               nffDartNotes: FN := WideChangeFileExt(FN, ext_DART);
            end;
         end;

         if FN = '' then begin
           with SaveDlg do begin
              case NoteFile.FileFormat of
                nffDartNotes : Filter := FILTER_DARTFILES + '|' + FILTER_ALLFILES;
                nffKeyNote   : Filter := FILTER_NOTEFILES + '|' + FILTER_ALLFILES;
                else
                  Filter := FILTER_NOTEFILES + '|' + FILTER_DARTFILES + '|' + FILTER_ALLFILES;
              end;
              FilterIndex := 1;
              if NoteFile.FileName <> '' then
                 FileName := NoteFile.FileName
              else
                 InitialDir := GetFolderPath(fpPersonal);
           end;

           if SaveDlg.Execute then begin
              FN := NormalFN(SaveDlg.FileName);
              ext := ExtractFileExt(FN);
              if ext = '' then begin
                 case NoteFile.FileFormat of
                   nffKeyNote:
                     FN := FN + ext_KeyNote;
                   nffEncrypted:
                     if KeyOptions.EncFileAltExt then
                        FN := FN + ext_Encrypted
                     else
                        FN := FN + ext_KeyNote;
                   nffDartNotes:
                     FN := FN + ext_DART;
                 end;
              end;
              NoteFile.FileName := FN;

              if (NoteFile.FileFormat = nffDartNotes) and KeyOptions.SaveDARTWarn then begin
                 case PopupMessage(format(STR_18, [FILE_FORMAT_NAMES[nffDartNotes], Program_Name, FILE_FORMAT_NAMES[nffKeyNote]]),
                                   mtWarning, [mbYes,mbNo,mbCancel], 0 ) of
                    mrNo: NoteFile.FileFormat := nffKeyNote;
                    mrCancel: Exit;
                 end;
              end;
           end
           else
              Exit;
         end;

         Screen.Cursor := crHourGlass;
         StatusBar.Panels[PANEL_HINT].text := STR_19 + FN;


         // BACKUP (before saving) of the file
         if DoBackup(FN, BakFN, BakFolder, SUCCESS, LastError) then begin
            Result := -2;
            if not SUCCESS then begin
               if MessageDlg( Format(STR_21,
                   [LastError, SysErrorMessage(LastError)] ),
                   mtWarning, [mbYes,mbNo], 0) <> mrYes then
                 Exit;
            end;
         end;


         // Get (and reflect) the expanded state of all the tree nodes
         try
           for i := 1 to NoteFile.NoteCount do begin
              myNote := NoteFile.Notes[pred(i)];
              if myNote.Kind = ntTree then
                 GetOrSetNodeExpandState(TTreeNote(myNote).TV, false, false);
           end;
         except
           // nothing
         end;


         // SAVE the file (and backup virtual nodes if it applies)
         NoteFile.FileName := FN;
         Result := NoteFile.Save(FN);

         if Result = 0 then begin
            StatusBar.Panels[PANEL_HINT].Text := STR_22;
            NoteFile.ReadOnly := False;    // We can do SaveAs from a Read-Only file (*)
                 { (*) In Windows XP is possible to select (with SaveDlg) the same file
                    as destination. In W10 it isn't }

            // Backup after saving
            DoIntervalBackup(FN, BakFolder);
         end
         else begin
            // ERROR on save
            StatusBar.Panels[PANEL_HINT].Text := Format(STR_23, [Result] );
            ErrStr := WideFormat(STR_24, [Result, WideExtractFilename(FN)] );

            if bakFN <> '' then
               ErrStr := ErrStr + WideFormat(STR_25, [WideExtractFilename(bakFN)] );

            if KeyOptions.AutoSave then begin
               KeyOptions.AutoSave := False;
               ErrStr := ErrStr + STR_26;
            end;

            DoMessageBox(ErrStr, mtError, [mbOK], 0);
         end;

       except
         on E: Exception do
         begin
           {$IFDEF MJ_DEBUG}
           Log.Add('Exception in NoteFileSave: ' + E.Message);
           {$ENDIF}
           StatusBar.Panels[PANEL_HINT].Text := STR_27;
           DoMessageBox(STR_28 + WideExtractFileName(FN) + '": ' + #13#13 + E.Message, mtError, [mbOK], 0 );
           Result := 1;
         end;
       end;

       try // folder monitor
         if not KeyOptions.DisableFileMon then begin
            GetFileState(NoteFile.FileName, FileState);
            FPath := WideExtractFilePath( NoteFile.FileName );
            if (Length(FPath) > 1) and (FPath[Length(FPath)] = '\') then
               Delete(FPath, Length(FPath), 1);
            FolderMon.FolderName := FPath;
            FolderMon.Active := (not KeyOptions.DisableFileMon);
         end;
       except
         on E: Exception do
         begin
           FolderMon.Active := False;
           PopupMessage(STR_29 + E.Message, mtError, [mbOK], 0);
         end;
       end;

     finally
       Screen.Cursor := crDefault;
       FileIsBusy := False;
       UpdateNoteFileState([fscSave,fscModified]);
       {$IFDEF MJ_DEBUG}
       Log.Add( 'NoteFileSave result: ' + IntToStr(Result));
       {$ENDIF}
     end;

     if Result = 0 then begin
        KeyOptions.LastFile := FN;
        if KeyOptions.MRUUse then
           MRU.AddItem(FN);
        AddToFileManager(FN, NoteFile);
     end;
  end;

end; // NoteFileSave


//=================================================================
// NoteFileClose
//=================================================================
function NoteFileClose : boolean;
begin
  MovingTreeNode:= nil;

  with Form_Main do begin

      result := true;
      DEF_FN := OrigDEF_FN;

      try
        // close all non-modal forms that might be open
        CloseNonModalDialogs;
        List_ResFind.Items.Clear;
        ClearLocationList( Location_List );
      except
      end;

      if IsRunningMacro then
      begin
        MacroAbortRequest := true;
      end
      else
      if IsRecordingMacro then
      begin
        TB_MacroRecordClick( TB_MacroRecord );
      end;

      screen.Cursor := crHourGlass;

      try
        if ( not HaveNotes( false, false )) then exit;
        if ( not CheckModified( not KeyOptions.AutoSave, false )) then
        begin
          result := false;
          exit;
        end;
        FileIsBusy := true;
        FolderMon.Active := false;

        ClipCapActive := false;
        Pages.MarkedPage := nil;
        if ( NoteFile.ClipCapNote <> nil ) then
        begin
          TB_ClipCap.Down := false;
          ToggleClipCap( false, NoteFile.ClipCapNote ); // turn it OFF
        end;

        LastEditCmd := ecNone;
        UpdateLastCommand( ecNone );
        BookmarkClearAll;

        if assigned( NoteFile ) then
        begin
          try
            DestroyVCLControls;
          except
            // showmessage( 'BUG: error in DestroyVCLControls' );
          end;
          try
            try
              NoteFile.Free;
            except
              // showmessage( 'BUG: error in NoteFile.Free' );
            end;
          finally
            NoteFile := nil;
          end;
        end;

        ActiveNote := nil;

        TAM_ActiveName.Caption := '';
        UpdateNoteFileState( [fscClose,fscModified] );
        StatusBar.Panels[PANEL_HINT].Text := STR_30;
      finally
        AlarmManager.Clear;
        MirrorNodes.Clear;

        FileIsBusy := false;
        PagesChange( Form_Main );
        screen.Cursor := crDefault;
        {$IFDEF MJ_DEBUG}
        Log.Add( 'NoteFileClose result: ' + BOOLARRAY[result] );
        {$ENDIF}
        LoadTrayIcon( false );
      end;
  end;
end; // NoteFileClose


procedure NewFileRequest( FN : string );
var
  p : integer;
  tmps : string;
begin
  FN := ansilowercase( FN );

  tmps := '';
  p := pos( '.exe', FN );
  if ( p = 0 ) then exit;
  delete( FN, 1, p+3 );
  while (( FN <> '' ) and ( FN[1] = '"' )) do
    delete( FN, 1, 1 );
  while (( FN <> '' ) and ( FN[1] = #32 )) do
    delete( FN, 1, 1 );

  while ( FN <> '' ) do
  begin
    if ( FN[1] = '"' ) then
    begin
      delete( FN, 1, 1 );
      p := pos( '"', FN );
      if ( p = 0 ) then
      begin
        tmps := FN;
        FN := '';
      end
      else
      begin
        tmps := copy( FN, 1, p-1 );
        delete( FN, 1, p );
      end;
    end
    else
    begin
      p := pos( #32, FN );
      if ( p = 0 ) then
      begin
        tmps := FN;
        FN := '';
      end
      else
      begin
        tmps := copy( FN, 1, p-1 );
        delete( FN, 1, p );
      end;
    end;
    if (( tmps = '' ) or ( tmps[1] in ['-','/'] )) then
    begin
      tmps := '';
      continue;
    end;
    break;
  end;

  if ( tmps = '' ) then exit;
  if Form_Main.HaveNotes( false, false ) then
  begin
    if ( tmps = NoteFile.FileName ) then
    begin
      if ( PopupMessage( Wideformat(STR_31, [NoteFile.Filename]), mtConfirmation, [mbYes,mbNo], 0 ) <> mrYes ) then exit;
      NoteFile.Modified := false; // to prevent automatic save if modified
    end;
  end;

  NoteFileOpen( tmps );

end; // NewFileRequest


procedure NoteFileCopy;
var
  currentFN, newFN : wideString;
  cr : integer;
  oldModified : boolean;
  DirDlg : TdfsBrowseDirectoryDlg;
begin
  with Form_Main do begin

        if ( not HaveNotes( true, false )) then exit;

        DirDlg := TdfsBrowseDirectoryDlg.Create( Form_Main );

        try

          DirDlg.Root := idDesktop;
          DirDlg.ShowSelectionInStatus := true;
          DirDlg.Title := STR_32;
          DirDlg.Center := true;

          currentFN := NoteFile.FileName;
          if ( KeyOptions.LastCopyPath <> '' ) then
            DirDlg.Selection := KeyOptions.LastCopyPath
          else
            DirDlg.Selection := GetFolderPath( fpPersonal );

            if ( not DirDlg.Execute ) then exit;
            if ( properfoldername( extractfilepath( currentFN )) = properfoldername( DirDlg.Selection )) then
            begin
              PopupMessage( STR_33, mtError, [mbOK], 0 );
              exit;
            end;

            KeyOptions.LastCopyPath := properfoldername( DirDlg.Selection );

            newFN := KeyOptions.LastCopyPath + WideExtractFilename( currentFN );
            if WideFileexists( newFN ) then

              if ( Popupmessage( WideFormat(STR_34, [newFN]), mtConfirmation, [mbYes,mbNo], 0 ) <> mrYes ) then exit;

            StatusBar.Panels[PANEL_HINT].Text := STR_35;


          oldModified := NoteFile.Modified;
          screen.Cursor := crHourGlass;
          try
            try
            cr := NoteFile.Save( newFN );
            if ( cr = 0 ) then
            begin
              StatusBar.Panels[PANEL_HINT].Text := STR_36;
              PopUpMessage( STR_37 +#13 + NewFN, mtInformation, [mbOK], 0 );
            end
            else
            begin
              Popupmessage( STR_38 + inttostr( cr ) + ')', mtError, [mbOK], 0 );
              {$IFDEF MJ_DEBUG}
              Log.Add( 'Copying failed (' + inttostr( cr ) + ')' );
              {$ENDIF}
            end;
            except
              on E : Exception do
              begin
                StatusBar.Panels[PANEL_HINT].Text := STR_15;
                {$IFDEF MJ_DEBUG}
                Log.Add( 'Exception in NoteFileSave: ' + E.Message );
                {$ENDIF}
                PopupMessage( E.Message, mtError, [mbOK], 0 );
              end;
            end;
          finally
            NoteFile.FileName := currentFN;
            NoteFile.Modified := oldModified;
            screen.Cursor := crDefault;
          end;

        finally
          DirDlg.Free;
        end;
  end;

end; // NoteFileCopy


//=================================================================
// MergeFromKNTFile
//=================================================================
procedure MergeFromKNTFile( MergeFN : string );
var
  MergeFile : TNoteFile;
  LoadResult : integer;
  TabSelector : TForm_SelectTab;
  mergecnt, i, n, p : integer;
  newNote : TTabNote;
  newTNote, mergeTNote : TTreeNote;
  newNode, mergeNode : TNoteNode;
  IDs: array of TMergeNotes;
  mirrorID: string;
  noteID: integer;

  function getNewID(noteID: integer): integer;
  var
    i: integer;
  begin
    Result:= 0;
    for i := 0 to High(IDs) do
        if IDs[i].oldID = noteID then begin
           Result:= IDs[i].newID;
           exit;
           end;
  end;

begin
  with Form_Main do begin

        if ( not HaveNotes( true, false )) then exit;
        if FileIsBusy then exit;

        if ( MergeFN = '' ) then
        begin

          if ( KeyOptions.LastExportPath <> '' ) then
            OpenDlg.InitialDir := KeyOptions.LastExportPath;
          OpenDlg.Title := STR_39;

          if ( not OpenDlg.Execute ) then exit;
          MergeFN := OpenDlg.FileName;
          KeyOptions.LastExportPath := extractfilepath( MergeFN );

        end;

        MergeFN := normalFN( MergeFN );

        { this can be safely removed. User can want to copy a whole note,
          and this is a neat way to do that.
        if ( MergeFN = NoteFile.FileName ) then
        begin
          showmessage( WideFormat( 'Cannot merge a file with itself (%s)', [WideExtractFilename( MergeFN )] ));
          exit;
        end;
        }

        MergeFile := TNoteFile.Create;
        MergeFile.PassphraseFunc := GetFilePassphrase;
        mergecnt := 0;

        try
          try
            LoadResult := MergeFile.Load( MergeFN );
            if ( LoadResult <> 0 ) then
            begin
              messagedlg( STR_40, mtError, [mbOK], 0 );
              exit;
            end;

            if ( MergeFile.NoteCount = 0 ) then
            begin
              messagedlg( STR_41, mtInformation, [mbOK], 0 );
              exit;
            end;

            for i := 0 to pred( MergeFile.NoteCount ) do
            begin
              // initially, UNMARK ALL notes (i.e. no merging)
              MergeFile.Notes[i].Info := 0;
            end;

          except
            on E : Exception do
            begin
              messagedlg( STR_42 + E.Message, mtError, [mbOK], 0 );
              exit;
            end;
          end;

          TabSelector := TForm_SelectTab.Create( Form_Main );
          try
            TabSelector.myNotes := MergeFile;
            TabSelector.Caption := WideFormat( STR_43, [WideExtractFilename( MergeFile.FileName )] );
            if ( not ( TabSelector.ShowModal = mrOK )) then exit;
          finally
            TabSelector.Free;
          end;

          SetLength(IDs, MergeFile.NoteCount);
          for i := 0 to pred( MergeFile.NoteCount ) do
          begin
            // see if user selected ANY notes for merge
            if ( MergeFile.Notes[i].Info > 0 ) then
              inc( mergecnt );
          end;

          if ( mergecnt = 0 ) then
          begin
            messagedlg( STR_44, mtInformation, [mbOK], 0 );
            exit;
          end;
          mergecnt := 0;

          StatusBar.Panels[PANEL_HINT].Text := STR_45;

          screen.Cursor := crHourGlass;

          try
            for i := 0 to pred( MergeFile.NoteCount ) do
            begin

              IDs[i].oldID:= MergeFile.Notes[i].ID;
              if ( MergeFile.Notes[i].Info = 0 ) then begin
                 IDs[i].newNote:= false;
                 if MergeFN <> NoteFile.FileName then
                    IDs[i].newID:= 0
                 else
                    IDs[i].newID:= IDs[i].oldID;
                  continue;
              end;


              case MergeFile.Notes[i].Kind of
                ntRTF : newNote := TTabNote.Create;
                else
                  newNote := TTreeNote.Create;
              end;

              NewNote.Visible := true;
              NewNote.Modified := false;

              with MergeFile.Notes[i] do
              begin
                NewNote.EditorChrome := EditorCHrome;
                NewNote.Name := Name;
                NewNote.ImageIndex := ImageIndex;
                NewNote.ReadOnly := ReadOnly;
                NewNote.DateCreated := DateCreated;
                NewNote.WordWrap := WordWrap;
                NewNote.URLDetect := URLDetect;
                NewNote.TabSize := TabSize;
                NewNote.UseTabChar := UseTabChar;
              end;

              if ( newNote.Kind = ntTree ) then
              begin
                newTNote := TTreeNote( newNote );
                with TTreeNote( MergeFile.Notes[i] ) do
                begin
                  newTNote.IconKind := IconKind;
                  newTNote.TreeWidth := TreeWidth;
                  newTNote.Checkboxes := CheckBoxes;
                  newTNote.TreeChrome := TreeChrome;
                  newTNote.DefaultNodeName := DefaultNodeName;
                  newTNote.AutoNumberNodes := AutoNumberNodes;
                  newTNote.VerticalLayout := VerticalLayout;
                  newTNote.HideCheckedNodes := HideCheckedNodes;
                end;
              end;

              MergeFile.Notes[i].AddProcessedAlarmsOfNote(newNote);

              case newNote.Kind of
                ntRTF : begin
                  MergeFile.Notes[i].DataStream.Position := 0;
                  newNote.DataStream.LoadFromStream( MergeFile.Notes[i].DataStream );
                end;
                ntTree : begin
                  mergeTNote:= TTreeNote( MergeFile.Notes[i] );
                  if ( mergeTNote.NodeCount > 0 ) then
                  begin
                    for n := 0 to pred( mergeTNote.NodeCount ) do
                    begin
                      mergeNode:= mergeTNote.Nodes[n];
                      newNode := TNoteNode.Create;
                      newNode.Assign( mergeNode );
                      TTreeNote( newNote ).AddNode( newNode );
                      newNode.ForceID( mergeNode.ID);
                      mergeTNote.AddProcessedAlarmsOfNode(mergeNode, newNote, newNode);
                    end;
                  end;
                end;
              end;

              NoteFile.AddNote( newNote );
              inc( mergecnt );

              IDs[i].newID:= newNote.ID;
              IDs[i].newNote:= true;

              try
                CreateVCLControlsForNote( newNote );
                newNote.DataStreamToEditor;
                SetUpVCLControls( newNote );
              finally
                newNote.TabSheet.TabVisible := true; // was created hidden
              end;

            end;

            //Mirror nodes (if exists) references old Note IDs. We must use new IDs
            for i := 0 to pred( MergeFile.NoteCount ) do
              if IDs[i].newNote then begin
                 newNote:= NoteFile.GetNoteByID(IDs[i].newID);
                 for n := 0 to TTreeNote(newNote).NodeCount - 1 do begin
                    newNode:= TTreeNote(newNote).Nodes[n];
                    if newNode.VirtualMode = vmKNTNode then begin
                       mirrorID:= newNode.MirrorNodeID;
                       p := pos( KNTLINK_SEPARATOR, mirrorID );
                       noteID:= StrToInt(AnsiLeftStr(mirrorID, p-1));
                       noteID:= GetNewID(noteID);
                       newNode.MirrorNodeID:= IntToStr(noteID) + KNTLINK_SEPARATOR + AnsiMidStr (mirrorID, p+1,255);
                    end;
                 end;
              end;

            for i := 0 to pred( MergeFile.NoteCount ) do
                if IDs[i].newNote then begin
                   newNote:= NoteFile.GetNoteByID(IDs[i].newID);
                   NoteFile.SetupMirrorNodes(newNote);
                   end;


          except
            On E : Exception do
            begin
              messagedlg( STR_46 + E.Message, mtError, [mbOK], 0 );
              exit;
            end;
          end;

        finally
          PagesChange( Form_Main );
          screen.Cursor := crDefault;
          NoteFile.Modified := true;
          UpdateNoteFileState( [fscModified] );
          if ( mergecnt > 0 ) then
            StatusBar.Panels[PANEL_HINT].Text := WideFormat( STR_47, [mergecnt, WideExtractFilename( MergeFN )] )
          else
            StatusBar.Panels[PANEL_HINT].Text := STR_48;
        end;
  end;

end; // MergeFromKNTFile


//=================================================================
// SomeoneChangedOurFile
//=================================================================
procedure SomeoneChangedOurFile;
begin
  Application.BringToFront;
  Form_Main.FolderMon.Active := false;
  try
    case DoMessageBox( WideFormat(STR_49, [FileState.Name]), mtWarning, [mbYes,mbNo], 0 ) of
      mrYes : begin
        NoteFile.Modified := false;
        NoteFileOpen( NoteFile.FileName );
      end;
      mrNo : begin
        NoteFile.Modified := true;
      end;
    end;
  finally
    Form_Main.FolderMon.Active := ( not KeyOptions.DisableFileMon );
  end;
end; // SomeoneChangedOurFile;



//=================================================================
// CheckFolder
//=================================================================
function CheckFolder( const name, folder : string; const AttemptCreate, Prompt : boolean ) : boolean;
begin
  result := false;
  if directoryexists( folder ) then
  begin
    result := true;
    exit;
  end;
  if ( not AttemptCreate ) then
  begin
    if Prompt then
      DoMessageBox( WideFormat(
        STR_50,
        [name,folder]
      ), mtError, [mbOK], 0 );
    exit;
  end;

  if Prompt then
  begin
    if ( DoMessageBox( WideFormat(STR_50 + STR_51,
          [name,folder]
      ), mtConfirmation, [mbYes,mbNo], 0 ) <> mrYes ) then
      exit;
  end;

  try
    mkdir( folder );
    result := true;
  except
    on e : exception do
    begin
      result := false;
      if Prompt then
        messagedlg( Format(
            STR_52,
            [E.Message]
          ), mtError, [mbOK], 0 );
    end;
  end;

end; // CheckFolder

//=================================================================
// FolderChanged
//=================================================================
procedure FolderChanged;
var
  NewState : TFileState;
  s : string;
  Changed : boolean;
begin
  with Form_Main do begin
        if FileIsBusy then exit;
        if ( not HaveNotes( false, false )) then exit;
        if ( FileState.Name = '' ) then exit;
        Changed := false;
        s := '';
        GetFileState( FileState.Name, NewState );
        if ( NewState.Size < 0 ) then
        begin
          // means file does not exist (deleted or renamed)
          NoteFile.Modified := true; // so that we save it
          exit;
        end;
        if ( FileState.Time <> NewState.Time ) then
        begin
          Changed := true;
          s := 'time stamp';
        end
        else
        begin
          if ( FileState.Size <> NewState.Size ) then
          begin
            Changed := true;
            s := 'file size';
          end;
        end;

        if Changed then
        begin
          FileChangedOnDisk := true;
          StatusBar.Panels[PANEL_HINT].Text := STR_53;
          {$IFDEF MJ_DEBUG}
          Log.Add( 'FileChangedOnDisk: ' + s );
          {$ENDIF}
          GetFileState( FileState.Name, FileState );
        end;
  end;

end; // FolderChanged


//=================================================================
// CheckModified
//=================================================================
function CheckModified( const Warn : boolean; const closing: boolean ) : boolean;
var
   wasMinimized: boolean;
begin
  wasMinimized:= False;
  with Form_Main do begin

      result := true;
      try
        if ( not HaveNotes( false, true )) then exit;
        {$IFDEF MJ_DEBUG}
        Log.Add( 'CheckModified: NoteFile modified? ' + BOOLARRAY[NoteFile.Modified] );
        {$ENDIF}
        if ( not NoteFile.Modified ) then exit;
        if Warn then
        begin
          case messagedlg( STR_54, mtConfirmation, [mbYes,mbNo,mbCancel], 0 ) of
            mrYes : begin
              // fall through and save file
            end;
            mrNo : begin
              result := true;
              exit;
            end;
            mrCancel : begin
              result := false;
              exit;
            end;
          end;
        end;
        if closing then begin
           wasMinimized:= (WindowState = wsMinimized);
           Application.Minimize;  // Liberate the screen to let the user do other things while keyNote is closing
        end;

        {$IFDEF MJ_DEBUG}
        Log.Add( '-- Saving on CHECKMODIFIED' );
        {$ENDIF}
        if ( NoteFileSave( NoteFile.FileName ) = 0 ) then
          result := true
        else
          result := ( Application.MessageBox( PChar(STR_55), PChar(STR_56), MB_YESNO+MB_ICONEXCLAMATION+MB_DEFBUTTON2+MB_APPLMODAL) = ID_YES );

        if closing and not wasMinimized then begin
           Application.Restore;
        end;

      finally
        {$IFDEF MJ_DEBUG}
        Log.Add( 'CheckModified result: ' + BOOLARRAY[result] );
        {$ENDIF}
      end;
  end;

end; // CheckModified


//=================================================================
// ImportFiles
//=================================================================
procedure ImportFiles;
var
  oldFilter : string;
  FilesToImport : TWideStringList;
begin
  with Form_Main do begin
      if ( not HaveNotes( true, true )) then exit;

      FilesToImport := TWideStringList.Create;

      try

        with OpenDlg do
        begin
          oldFilter := Filter;
          Filter := FILTER_IMPORT;
          FilterIndex := LastImportFilter;
          Title := STR_57;
          Options := Options + [ofAllowMultiSelect];
          OpenDlg.FileName := '';
          if ( KeyOptions.LastImportPath <> '' ) then
            InitialDir := KeyOptions.LastImportPath
          else
            InitialDir := GetFolderPath( fpPersonal );
        end;

        try
          if ( not OpenDlg.Execute ) then exit;
          KeyOptions.LastImportPath := properfoldername( extractfilepath( OpenDlg.FileName ));
        finally
          OpenDlg.Filter := oldFilter;
          OpenDlg.FilterIndex := 1;
          OpenDlg.Options := OpenDlg.Options - [ofAllowMultiSelect];
          LastImportFilter := OpenDlg.FilterIndex;
        end;

        FilesToImport.AddStrings( OpenDlg.Files );
        FileDropped( nil, FilesToImport );

      finally
        FilesToImport.Free;
      end;
  end;
end; // ImportFiles


//=================================================================
// ImportAsNotes
//=================================================================
procedure ImportAsNotes( ImportFileList : TWideStringList );
var
  ext, FN, s : wideString;
  myNote : TTabNote;
  filecnt : integer;
  ImportFileType : TImportFileType;
  tNote : TTreeNote;
  OutStream: TMemoryStream;

begin
  with Form_Main do begin

        if ( not HaveNotes( true, false )) then exit;
        if (( not assigned( ImportFileList )) or ( ImportFileList.Count = 0 )) then exit;

        OutStream:= TMemoryStream.Create;
        try

          for filecnt := 0 to pred( ImportFileList.Count ) do
          begin
            FN := normalFN( ImportFileList[filecnt] );
            OutStream.Clear;

            ext := WideLowercase( WideExtractfileext( FN ));
            ImportFileType := itText;

            if ext = ext_TXT then
              ImportFileType := itText
            else
            if ext = ext_RTF then
              ImportFileType := itRTF
            else
            if ExtIsHTML( ext ) then
            begin
              if ( KeyOptions.HTMLImportMethod = htmlSource ) then
                ImportFileType := itText
              else
                ImportFileType := itHTML;
            end
            else
            if ext = ext_TreePad then
              ImportFileType := itTreePad
            else
            if ExtIsText( ext ) then
              ImportFileType := itText
            else
            begin
              case DoMessageBox( WideFormat(STR_58, [WideExtractFilename( FN )]),
                mtWarning, [mbYes,mbNo], 0 ) of
              mrYes : ImportFileType := itText;
              else
                continue;
              end;
            end;

            myNote := nil;
            screen.Cursor := crHourGlass;

            try

              StatusBar.Panels[PANEL_HINT].Text := STR_59 + WideExtractFilename( FN );

              if ( ImportFileType = itHTML ) then   // first see if we can do the conversion, before we create a new note for the file
              begin
                if not ConvertHTMLToRTF( FN, OutStream) then begin
                   DoMessageBox( WideFormat(STR_60, [FN]), mtWarning, [mbOK], 0 );
                   exit;
                end;
              end;

              try
                case ImportFileType of
                  itText, itRTF, itHTML : begin
                    myNote := TTabNote.Create;
                  end;
                  itTreePad : begin
                    myNote := TTreeNote.Create;
                  end;
                end;

                myNote.SetEditorProperties( DefaultEditorProperties );
                myNote.SetTabProperties( DefaultTabProperties );
                myNote.EditorChrome := DefaultEditorChrome;
                if KeyOptions.ImportFileNamesWithExt then
                  s := WideExtractFilename( FN )
                else
                  s := ExtractFilenameNoExt( FN );
                myNote.Name := s;
                NoteFile.AddNote( myNote );

                try
                  case ImportFileType of
                    itText : begin
                      myNote.DataStream.LoadFromFile( FN );
                      end;
                    itHTML : begin
                      myNote.DataStream.LoadFromStream(OutStream);
                      end;
                    itRTF : begin
                      myNote.DataStream.LoadFromFile( FN );
                      end;
                    itTreePad : begin
                      tNote := TTreeNote( myNote );
                      tNote.SetTreeProperties( DefaultTreeProperties );
                      tNote.TreeChrome := DefaultTreeChrome;
                      tNote.LoadFromTreePadFile( FN );
                    end;
                  end;

                  CreateVCLControlsForNote( myNote );
                  myNote.DataStreamToEditor;
                  SetUpVCLControls( myNote );

                finally
                  if assigned( myNote.TabSheet ) then
                  begin
                    myNote.TabSheet.TabVisible := true; // was created hidden
                    Pages.ActivePage := myNote.TabSheet;
                  end;
                  ActiveNote := myNote;
                end;

              except
                on E : Exception do begin
                  DoMessageBox( STR_61 + FN + #13#13 + E.Message, mtError, [mbOK], 0 );
                  exit;
                end;
              end;

            finally
              screen.Cursor := crDefault;
              AddToFileManager( NoteFile.FileName, NoteFile ); // update manager (number of notes has changed)
              PagesChange( Form_Main );
              StatusBar.Panels[PANEL_HINT].text := STR_62;
              NoteFile.Modified := true;
              UpdateNoteFileState( [fscModified] );
            end;
          end;

        finally
            if assigned( OutStream ) then OutStream.Free;
            FreeConvertLibrary;
        end;
  end;
end; // ImportAsNotes


//=================================================================
// PromptForFileAction
//=================================================================
function PromptForFileAction( const FileCnt : integer; const aExt : string ) : TDropFileAction;
var
  Form_DropFile: TForm_DropFile;
  LastFact, fact : TDropFileAction;
  facts : TDropFileActions;
  actidx : integer;
  actionname : string;
  FileIsHTML, ActiveNoteIsReadOnly : boolean;
  myTreeNode : TTreeNTNode;
  IsKnownFileFormat : boolean;
begin
  with Form_Main do begin
        if (( aExt = ext_Plugin ) or ( aExt = ext_Macro )) then
        begin
          result := factExecute;
          exit;
        end;

        result := factUnknown;
        LastFact := FactUnknown;
        ActiveNoteIsReadOnly := NoteIsReadOnly( ActiveNote, false );

        FileIsHTML := ExtIsHTML( aExt );

        IsKnownFileFormat := ( FileIsHTML or ExtIsText( aExt ) or ExtIsRTF( aExt ));

          // select actions which can be performed
          // depending on extension of the dropped file
          // and on whether we are in a tree-type note
          for fact := low( fact ) to high( fact ) do
            facts[fact] := false;

          facts[factHyperlink] := ( not ActiveNoteIsReadOnly ); // this action can always be perfomed unless current note is read-only

          // .KNT, .KNE and DartNotes files
          // can only be opened or merged,
          // regardless of where they were dropped.
          // This can only be done one file at a time.
          if ( aExt = ext_KeyNote ) or
             ( aExt = ext_Encrypted ) or
             ( aExt = ext_DART ) then
          begin
            facts[factOpen] := true;
            facts[factMerge] := ( not ActiveNoteIsReadOnly );
          end
          else
          if ( aExt = ext_TreePad ) then
          begin
            facts[factImport] := true;
          end
          else
          begin
            // all other files we can attempt to import...
            facts[factImport] := IsKnownFileFormat;
            if (( ActiveNote.Kind = ntTree ) and ( not ActiveNoteIsReadOnly )) then
            begin
              // ...or, in a tree note, import as a tree node
              myTreeNode := TTreeNote( ActiveNote ).TV.Selected;
              if assigned( myTreeNode ) then
              begin
                facts[factImportAsNode] := IsKnownFileFormat;
                facts[factMakeVirtualNode] := IsKnownFileFormat;
                {$IFDEF WITH_IE}
                facts[factMakeVirtualIENode] := FileIsHTML;
                {$ENDIF}
              end;
            end;
          end;

          if (( LastFact = factUnknown ) or ( not facts[LastFact] )) then
          begin
            Form_DropFile := TForm_DropFile.Create( Form_Main );
            try
              Form_DropFile.Btn_HTML.Enabled := FileIsHTML;
              Form_DropFile.Btn_HTML.Visible := FileIsHTML;
              if FileIsHTML then
              begin
                Form_DropFile.RG_HTML.ItemIndex := ord( KeyOptions.HTMLImportMethod );
              end;
              for fact := low( fact ) to high( fact ) do
              begin
                if facts[fact] then
                  Form_DropFile.RG_Action.Items.Add( FactStrings[fact] );
              end;
              if ( Form_DropFile.RG_Action.Items.Count > 0 ) then
              begin
                Form_DropFile.RG_Action.ItemIndex := 0;
                Form_DropFile.NumberOfFiles := FileCnt;
                Form_DropFile.FileExt := aExt;
                case Form_DropFile.ShowModal of
                  mrOK : begin
                    // since we created the radio items dynamically,
                    // we can only figure out which one was selected thusly:
                    if FileIsHTML then
                    begin
                      KeyOptions.HTMLImportMethod := THTMLImportMethod( Form_DropFile.RG_HTML.ItemIndex );
                    end;
                    actidx := Form_DropFile.RG_Action.ItemIndex;
                    LastFact := factUnknown;
                    if ( actidx >= 0 ) then
                    begin
                      actionname := Form_DropFile.RG_Action.Items[actidx];
                      for fact := low( fact ) to high( fact ) do
                      begin
                        if ( FactStrings[fact] = actionname ) then
                        begin
                          LastFact := fact;
                          break;
                        end;
                      end;

                    end;
                  end; // mrOK

                  mrCancel : begin
                    LastFact := factUnknown;
                    exit;
                  end;
                end;
              end
              else
              begin
                messagedlg( STR_63, mtError, [mbOK], 0 );
                exit;
              end;
            finally
              result := LastFact;
              Form_DropFile.Free;
            end;
          end;
  end;

end; // PromptForFileAction


//=================================================================
// ConsistentFileType
//=================================================================
function ConsistentFileType( const aList : TWideStringList ) : boolean;
var
  i, cnt : integer;
  ext : string;
  ift : TImportFileType;
begin
  with Form_Main do begin
        result := true;
        cnt := aList.Count;
        if ( cnt < 2 ) then exit;

        ext := extractfileext( aList[0] );
        if ExtIsRTF( ext ) then
          ift := itRTF
        else
        if ExtIsText( ext ) then
          ift := itText
        else
        if ExtisHTML( ext ) then
          ift := itHTML
        else
        begin
          result := FilesAreOfSameType( aList );
          exit;
        end;

        for i := 1 to pred( cnt ) do
        begin
          ext := extractfileext( aList[i] );
          case ift of
            itRTF : if ( not ExtIsRTF( ext )) then
            begin
              result := false;
              break;
            end;
            itText : if ( not ExtIsText( ext )) then
            begin
              result := false;
              break;
            end;
            itHTML : if ( not ExtIsHTML( ext )) then
            begin
              result := false;
              break;
            end;
          end;
        end;
  end;
end; // ConsistentFileType


//=================================================================
// FileDropped
//=================================================================
procedure FileDropped( Sender : TObject; FileList : TWideStringList );
var
  myTreeNode : TTreeNTNode;
  myNoteNode : TNoteNode;
  fName, fExt : wideString;
  myAction : TDropFileAction;
  i : integer;
  FileIsHTML, FileIsFolder : boolean;
  OutStream: TMemoryStream;

begin
  with Form_Main do begin
        if ( FileList.Count = 0 ) then exit;

        myAction := factUnknown;
        fName := FileList[0];
        fExt := extractfileext( fName );
        FileIsHTML := ExtIsHTML( fExt );
        FileIsFolder := DirectoryExists( fName );

        if ( not ( assigned( NoteFile ) and assigned( ActiveNote ))) then
        begin
          // no active note; we can only OPEN a file
          if ((( fExt = ext_KeyNote ) or
             ( fExt = ext_Encrypted ) or
             ( fExt = ext_DART )) and ( not FileIsFolder )) then
          begin
            myAction := factOpen;
          end
          else
          begin
            HaveNotes( true, true );
            exit;
          end;
        end;

        myTreeNode := nil;

        WinOnTop.AlwaysOnTop := false;
        try

          Application.BringToFront;

          if ( myAction = factUnknown ) then
          begin

            if ( not ConsistentFileType( FileList )) then
            begin
              //Messagedlg( STR_64, mtError, [mbOK], 0 );
              //exit;
              fExt:= '.*';
            end;

            if FileIsFolder then
              myAction := factHyperlink
            else
              myAction := PromptForFileAction( FileList.Count, fExt );

          end;

          screen.Cursor := crHourGlass;
          try

            case myAction of
              factOpen : begin
                NoteFileOpen( fName );
              end;

              factExecute : begin
                if ( fExt = ext_Plugin ) then
                begin
                  ExecutePlugin( fName );
                end
                else
                if ( fExt = ext_Macro ) then
                begin
                  ExecuteMacro( fName, '' );
                end;
              end;

              factMerge : begin
                MergeFromKNTFile( fName );
              end;

              factHyperlink : begin
                for i := 0 to pred( FileList.Count ) do
                begin
                  InsertFileOrLink( FileList[i], true );
                  ActiveNote.Editor.SelText:= #13#10;
                  ActiveNote.Editor.SelLength:= 0;
                  ActiveNote.Editor.SelStart:= ActiveNote.Editor.SelStart+2;
                end;
              end;

              factImport : begin
                ImportAsNotes( FileList );
              end;

              factImportAsNode : begin
                ActiveNote.Editor.OnChange := nil;
                ActiveNote.Editor.Lines.BeginUpdate;
                SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 0, 0 ); // don't draw richedit yet
                OutStream:= TMemoryStream.Create;
                try
                  for i := 0 to pred( FileList.Count ) do
                  begin
                    OutStream.Clear;
                    FName := FileList[i];
                    if DirectoryExists( FName ) then
                    begin
                      if ( DoMessageBox( WideFormat( STR_65, [FName] ), mtWarning, [mbOK,mbAbort], 0 ) = mrAbort ) then
                        exit
                      else
                        continue;
                    end;

                    // first see if we can do the conversion, before we create a new note for the file
                    if ( FileIsHTML and ( KeyOptions.HTMLImportMethod <> htmlSource )) then
                    begin
                      if not ConvertHTMLToRTF( FName, OutStream) then begin
                         DoMessageBox( WideFormat(STR_60, [FName]), mtWarning, [mbOK], 0 );
                         exit;
                      end;
                    end;

                    myTreeNode := TreeNoteNewNode( nil, tnAddLast, nil, '', true );
                    if assigned( myTreeNode ) then
                    begin
                      myNoteNode := TNoteNode( myTreeNode.Data );
                      if assigned( myNoteNode ) then begin
                          if ( FileIsHTML and ( KeyOptions.HTMLImportMethod <> htmlSource )) then
                            myNoteNode.Stream.LoadFromStream(OutStream)
                          else
                            myNoteNode.Stream.LoadFromFile( FName );

                          SelectIconForNode( myTreeNode, TTreeNote( ActiveNote ).IconKind );
                          if KeyOptions.ImportFileNamesWithExt then
                            myNoteNode.Name := WideExtractFilename( FName )
                          else
                            myNoteNode.Name := ExtractFilenameNoExt( FName );
                          myTreeNode.Text := myNoteNode.Name;
                          ActiveNote.DataStreamToEditor;
                      end;
                    end;
                  end;
                finally
                  if assigned( OutStream ) then OutStream.Free;
                  FreeConvertLibrary;
                  NoteFile.Modified := true;
                  SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 1, 0 ); // ok to draw now
                  ActiveNote.Editor.Lines.EndUpdate;
                  ActiveNote.Editor.Invalidate; // in fact, I insist on it
                  UpdateNoteFileState( [fscModified] );
                  ActiveNote.Editor.Modified := false;
                  ActiveNote.Editor.OnChange := RxRTFChange;
                end;
              end;

              factMakeVirtualNode : begin
                SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 0, 0 );
                try
                  for i := 0 to pred( FileList.Count ) do
                  begin
                    FName := FileList[i];
                    if DirectoryExists( FName ) then
                    begin
                      if ( DoMessageBox( WideFormat( STR_65, [FName] ), mtWarning, [mbOK,mbAbort], 0 ) = mrAbort ) then
                        exit
                      else
                        continue;
                    end;
                    myTreeNode := TreeNoteNewNode( nil, tnAddLast, nil, '', true );
                    VirtualNodeProc( vmNone, myTreeNode, FName );
                  end;
                finally
                  SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 1, 0 ); // ok to draw now
                  ActiveNote.Editor.Invalidate; // in fact, I insist on it
                end;
              end;

              {$IFDEF WITH_IE}
              factMakeVirtualIENode : begin
                SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 0, 0 );
                try
                  for i := 0 to pred( FileList.Count ) do
                  begin
                    FName := FileList[i];
                    if DirectoryExists( FName ) then
                    begin
                      if ( DoMessageBox( WideFormat( STR_65, [FName] ), mtWarning, [mbOK,mbAbort], 0 ) = mrAbort ) then
                        exit
                      else
                        continue;
                    end;
                    myTreeNode := TreeNoteNewNode( nil, tnAddLast, nil, '', true );
                    VirtualNodeProc( vmIELocal, myTreeNode, FName );
                  end;
                finally
                  SendMessage( ActiveNote.Editor.Handle, WM_SetRedraw, 1, 0 ); // ok to draw now
                  ActiveNote.Editor.Invalidate; // in fact, I insist on it
                end;
              end;
              {$ENDIF}

              factUnknown : begin
                // MessageDlg( 'No action was taken: could not determine method for handling files.', mtWarning, [mbOK], 0 );
                exit;
              end;

              else begin
                messagedlg( Format( STR_67, [ord( myAction )] ), mtError, [mbOK], 0 );
                exit;
              end;

            end; // case myAction

          except
            on E : Exception do begin
              messagedlg( STR_68 + E.Message, mtError, [mbOK], 0 );
              exit;
            end;
          end;

        finally
          screen.Cursor := crDefault;
          WinOnTop.AlwaysOnTop := KeyOptions.AlwaysOnTop;
        end;
  end;

end; // FileDropped


//=================================================================
// NoteFileProperties
//=================================================================
procedure NoteFileProperties;
var
  Form_FileInfo : TForm_FileInfo;
begin
  with Form_Main do begin
      // Edits properties for currently open file

      if ( not HaveNotes( true, false )) then exit;

      Form_FileInfo := TForm_FileInfo.Create( Form_Main );

      try
        Form_FileInfo.myNotes := NoteFile;

        if ( Form_FileInfo.ShowModal = mrOK ) then
        begin
          Virtual_UnEncrypt_Warning_Done := false;

          with Form_FileInfo do
          begin
            ShowHint := KeyOptions.ShowTooltips;

            NoteFile.Comment := trim( Edit_Comment.Text );
            NoteFile.Description := trim( Edit_Description.Text );
            NoteFile.NoMultiBackup := CB_NoMultiBackup.Checked;
            NoteFile.OpenAsReadOnly := CB_AsReadOnly.Checked;
            if ( not CB_AsReadOnly.Checked ) then NoteFile.ReadOnly := false;
            NoteFile.ShowTabIcons := CB_ShowTabIcons.Checked;
            NoteFile.FileFormat := TNoteFileFormat( Combo_Format.ItemIndex );
            NoteFile.CompressionLevel := TZCompressionLevel( Combo_CompressLevel.ItemIndex );

            if ( CB_TrayIcon.Checked and ( Edit_TrayIcon.Text <> '' )) then
              NoteFile.TrayIconFN := normalFN( Edit_TrayIcon.Text )
            else
              NoteFile.TrayIconFN := '';

            if RB_TabImgDefault.Checked then
            begin
              NoteFile.TabIconsFN := '';
            end
            else
            if RB_TabImgBuiltIn.Checked then
            begin
              NoteFile.TabIconsFN := _NF_Icons_BuiltIn;
            end
            else
            begin
              if ( Edit_TabImg.Text <> '' ) then
              begin
                NoteFile.TabIconsFN := normalFN( Edit_TabImg.Text );
              end
              else
              begin
                NoteFile.TabIconsFN := '';
              end;
            end;

            if ( NoteFile.FileFormat = nffEncrypted ) then
            begin
              NoteFile.CryptMethod := TCryptMethod( Combo_Method.ItemIndex );
              if PassphraseChanged then
                NoteFile.Passphrase := Edit_Pass.Text;
            end;

            if ( NoteFile.FileName <> '' ) then
            case NoteFile.FileFormat of
              nffKeyNote : NoteFile.FileName := WideChangefileext( NoteFile.FileName, ext_KeyNote );
              nffEncrypted : if KeyOptions.EncFileAltExt then
                NoteFile.FileName := WideChangefileext( NoteFile.FileName, ext_Encrypted )
              else
                NoteFile.FileName := WideChangefileext( NoteFile.FileName, ext_KeyNote );
              nffDartNotes : NoteFile.FileName := WideChangefileext( NoteFile.FileName, ext_DART );
            end;

          end;
          NoteFile.Modified := true;
          AddToFileManager( NoteFile.FileName, NoteFile ); // update manager (properties have changed)

          LoadTrayIcon( ClipOptions.SwitchIcon and assigned( NoteFile.ClipCapNote ));
          if _FILE_TABIMAGES_SELECTION_CHANGED then
          begin
            _FILE_TABIMAGES_SELECTION_CHANGED := false;
            if (( NoteFile.TabIconsFN <> '' ) and ( NoteFile.TabIconsFN <> _NF_Icons_BuiltIn )) then
            begin
              // user specified an "Other" file that does not exist.
              // This means: create this file and use it later
              // (otherwise, to use an "other" file, user would have
              // to copy the original file manually in Explorer)
              // In essense, we are creating the file the user requested.
              if ( not fileexists( NoteFile.TabIconsFN )) then
                SaveCategoryBitmapsUser( NoteFile.TabIconsFN );
            end;
            LoadTabImages( true );
          end;
        end;
      finally
        Form_FileInfo.Free;
      end;

      UpdateNoteFileState( [fscSave,fscModified] );

      // [x] If passphrase changed or Encrypted state changed,
      // must SAVE FILE immediately.

   end;
end; // NoteFileProperties


//=================================================================
// UpdateNoteFileState
//=================================================================
procedure UpdateNoteFileState( AState : TFileStateChangeSet );
var
  s, thisFN : wideString;
  NotesOK : boolean;
  WasModified : boolean;
begin
  with Form_Main do begin
      NotesOK := HaveNotes( false, false );
      if (( fscNew in AState ) or ( fscOpen in AState ) or ( fscSave in AState ) or ( fscClose in AState )) then
      begin
        if NotesOK then
        begin
          // Pages.OnMouseDown := TabMouseDown;
          Pages.OnDblClick := PagesDblClick;

          if ( NoteFile.FileName <> '' ) then
          begin
            thisFN := WideExtractFilename( NoteFile.FileName );
            s := thisFN;
          end
          else
          begin
            s := STR_69;
          end;

          StatusBar.Panels.BeginUpdate;
          try
            StatusBar.Panels[PANEL_FILENAME].Text := #32 + s + #32;
            StatusBar.Hint := #32 + NoteFile.FileName;
            TrayIcon.Hint := Program_Name + ': ' + s;
            SelectStatusbarGlyph( true );
          finally
            Caption := Format( '%s  %s - %s',
              [Program_Name, Program_Version, s] );
            Application.Title := Format( '%s - %s', [s, Program_Name] );
            StatusBar.Panels.EndUpdate;
          end;
        end
        else
        begin
          // Pages.OnMouseDown := nil;
          Pages.OnDblClick := nil;
          StatusBar.Panels.BeginUpdate;
          try
            StatusBar.Panels[PANEL_FILENAME].Text := STR_70;
            StatusBar.Panels[PANEL_CARETPOS].Text := '';
            StatusBar.Panels[PANEL_NOTEINFO].Text := '';
            StatusBar.Panels[PANEL_STATUS].Text := '';
            StatusBar.Panels[PANEL_FILEICON].Text := '';
            StatusBar.Panels[PANEL_FILEICON].Hint := '';
            SelectStatusBarGlyph( false );

          finally
            StatusBar.Panels.EndUpdate;
          end;
          StatusBar.Hint := '';
          TrayIcon.Hint := Program_Name + STR_71;
          Caption := Format( '%s  %s -' + STR_71,
            [Program_Name, Program_Version] );
          TB_FileSave.Enabled := False;
          Application.Title := Program_Name;
        end;
        UpdateTabAndTreeIconsShow;
      end;

      if ( fscModified in AState ) then
      begin
        MMShiftTab_.Enabled := ( Pages.PageCount > 0 );
        if NotesOK then
        begin
          WasModified := NoteFile.Modified;
          if WasModified then
             Statusbar.Panels[PANEL_STATUS].Text := STR_73      //MOD
          else
             if KeyOptions.AutoSave then
                Statusbar.Panels[PANEL_STATUS].Text := STR_72   //Auto
             else
                Statusbar.Panels[PANEL_STATUS].Text := STR_74;   //Saved
        end
        else
          Statusbar.Panels[PANEL_STATUS].Text := ' ---';
      end;
  end;

end; // UpdateNoteFileState


//=================================================================
// AutoCloseFile
//=================================================================
procedure AutoCloseFile;
var
  i : integer;
begin

  // CAUTION: With KeyOptions.TimerCloseDialogs set,
  // we have a bug of major inconvenience.
  // AppLastActiveTime is NOT updated when a modal
  // dialog is open, so as long as a dialog is open,
  // KeyNote thinks it is inactive. It may lead to
  // a situation where we close file and minimize
  // while user is busy clicking stuff in a dialog box.
  // OTOH, if TimerCloseDialogs is set to false, the
  // file will not be autoclosed id any modal dialog
  // is open, leading to a potential security breach.

  if ( TransferNodes <> nil ) then
  begin
    try
      TransferNodes.Free;
    except
    end;
    TransferNodes := nil;
  end;

  if FileIsBusy then exit;
  if ( not ( KeyOptions.TimerClose and
             Form_Main.HaveNotes( false, false ) and
             KeyOptions.AutoSave
           )) then exit;


  // CloseNonModalDialogs;

  // Check if any modal dialog box is open, and close it, unless
  // config setting prevents us from doing so. If we cannot close
  // all modal forms, we will not auto-close the file.

  // Notes:
  // 1. We can close our own custom forms directly, by issuing
  //    a .Close to each form in Screen.Forms.
  // 2. The above won't let us close any standard Windows dialog
  //    boxes that may be open (FileOpen, FileSave, ColorDlg, etc.)
  //    For these, we can send a WM_CLOSE, but it won't work if
  //    the application (as a whole) is not active. So, once we
  //    know we are auto-closing anyway, we do the rude thing and
  //    grab focus for a short while, so that we can send WM_CLOSE
  //    to whatever dialog (belonging to us) is active. Then we
  //    minimize.

  // IsWindowEnabled( self.Handle )
  // when TRUE, we do not have any modal dialog open.
  // when FALSE, we do have one or more modal dialogs open.

  // GetActiveWindow = self.Handle
  // when TRUE, we do not have any modal dialog open, and
  //            the application is active (has focus)
  // when FALSE, we have one or more modal dialogs open,
  //             and/or the application is not active.


  if (( NoteFile.FileFormat = nffEncrypted ) or ( not KeyOptions.TimerCloseEncOnly )) then
  begin
    // only under these conditions do we try to autoclose...

    // First, do our own forms
    if ( Screen.FormCount > 1 ) then
    begin
      if KeyOptions.TimerCloseDialogs then
      begin
        for i := pred( Screen.FormCount ) downto 0 do
          if ( Screen.Forms[i] <> Form_Main ) then
            Screen.Forms[i].Close;
      end
      else
        exit; // config setting prevents us from forcing
              // our forms to close, so we must bail out
    end;


    // now, if the main form is still not "enabled",
    // it means we have some system dialog open
    if ( not IsWindowEnabled( Form_Main.Handle )) then
    begin
      if KeyOptions.TimerCloseDialogs then
      begin
        // there can only be one system dialog open,
        // unlike our own forms, of which there may be a few
        // on top of one another. But first, we must be the
        // active application, otherwise we'll send WM_CLOSE
        // to nowhere.
        Application.BringToFront;
        // we KNOW we have a modal dialog open, so this is safe,
        // i.e. we won't be sending WM_CLOSE to main form
        SendMessage( GetActiveWindow, WM_CLOSE, 0, 0 ); // close the modal window!
      end
      else
        exit; // bail out, if we haven't already
    end;

    // if the file was encrypted, we optionally want to be able to
    // automatically prompt for password and reopen the file when
    // user returns to the program. So, set a flag here.
    if ( NoteFile.FileFormat = nffEncrypted ) then
    begin
      _REOPEN_AUTOCLOSED_FILE := KeyOptions.TimerCloseAutoReopen;
    end;

    NoteFileClose;
    Application.Minimize;
  end;

end; // AutoCloseFile

//=================================================================
// RunFileManager
//=================================================================
procedure RunFileManager;
var
  MGR : TForm_FileMgr;
  s, olds : string;
  MGROK : boolean;
begin
  try
    MGROK := false;
    s := '';
    MGR := TForm_FileMgr.Create( Form_Main );
    try
      with MGR do
      begin
        MgrFileName := MGR_FN;
        ShowFullPaths := KeyOptions.MgrFullPaths;
        ShowHint := KeyOptions.ShowTooltips;
        if assigned( NoteFile ) then
          SelectedFileName := NoteFile.FileName;
      end;
      MGROK := ( MGR.ShowModal = mrOK );
      s := MGR.SelectedFileName;
      KeyOptions.MgrFullPaths := MGR.ShowFullPaths;
    finally
      MGR.Free;
    end;

    if Form_Main.HaveNotes( false, false ) then
      olds := NoteFile.Filename
    else
      olds := '';

    if MGROK then
    begin
      if (( s <> '' ) and ( s <> olds )) then
        NoteFileOpen( s );
    end;

  except
    on E : Exception do // [xx]
    begin
      messagedlg( 'Debug message: Error in RunFileManager.', mtWarning, [mbOK], 0 );
    end;
  end;

end; // RunFileManager

function CanRegisterFileType : boolean;
begin
  result := true;
  if opt_RegExt then
    exit;
  if KeyOptions.AutoRegisterFileType then
    if ( not FiletypeIsRegistered( ext_KeyNote, _KNT_FILETYPE )) then
      if ( not IsDriveRemovable( ParamStr( 0 ))) then
        exit;
  result := false;
end; // CanRegisterFileType

procedure AssociateKeyNoteFile;
begin

  if CanRegisterFileType then
  begin
    try
      RegisterFiletype( ext_KeyNote, _KNT_FILETYPE, _KNT_FILETYPE, 'open', '', '' );
      RegisterFileIcon( _KNT_FILETYPE, ParamStr( 0 ), 0 );

      RegisterFiletype( ext_Encrypted, _KNE_FILETYPE, _KNE_FILETYPE, 'open', '', '' );
      RegisterFileIcon( _KNE_FILETYPE, ParamStr( 0 ), 0 );

      RegisterFiletype( ext_Macro, _KNM_FILETYPE, _KNM_FILETYPE, 'open', '', '' );
      RegisterFileIcon( _KNM_FILETYPE, ParamStr( 0 ), 0 );

      RegisterFiletype( ext_Macro, _KNL_FILETYPE, _KNL_FILETYPE, 'open', '', '' );
      RegisterFileIcon( _KNL_FILETYPE, ParamStr( 0 ), 0 );

      if KeyOptions.AutoRegisterPrompt then
        messagedlg( Format( STR_75, [ext_KeyNote] ), mtInformation, [mbOK], 0 );
    except
      on E : Exception do
        MessageDlg( STR_76 + e.Message, mtWarning, [mbOK], 0 );
    end;
  end;
end; // AssociateKeyNoteFile

end.
