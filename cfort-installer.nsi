;Classic Fortress Client Installer Script

Name "Classic Fortress"
OutFile "Binaries\cfortress.exe"
InstallDir "C:\Classic Fortress"

!define DISTFILES_PATH "$LOCALAPPDATA\Classic Fortress\" # Note: no trailing slash!

# Editing anything below this line is not recommended
;---------------------------------------------------
;Header Files

!include "MUI.nsh"
!include "FileFunc.nsh"
!insertmacro GetSize
!insertmacro GetTime
!include "LogicLib.nsh"
!include "Time.nsh"
!include "Locate.nsh"
!include "WinMessages.nsh"
!include "MultiUser.nsh"
!include "cfort-macros.nsh"

;----------------------------------------------------
;Variables

Var DISTFILES_DELETE
Var DISTFILES_PATH
Var DISTFILES_REDOWNLOAD
Var DISTFILES_UPDATE
Var DISTFILES_URL
Var DISTFILES
Var DISTLOG
Var DISTLOGTMP
Var ERRLOG
Var ERRLOGTMP
Var ERRORS
Var INSTALLED
Var INSTLOG
Var INSTLOGTMP
Var INSTSIZE
Var CFORT_INI
Var OFFLINE
Var RETRIES
Var SIZE

;----------------------------------------------------
;Interface Settings

!define MUI_HEADERIMAGE

!define MULTIUSER_EXECUTIONLEVEL Highest

;----------------------------------------------------
;Installer Pages

!define MUI_PAGE_CUSTOMFUNCTION_PRE "WelcomeShow"
!define MUI_WELCOMEPAGE_TITLE "Classic Fortress Installation Wizard"
!insertmacro MUI_PAGE_WELCOME

LicenseForceSelection checkbox "I agree to these terms and conditions"
!insertmacro MUI_PAGE_LICENSE "license.txt"

Page custom DOWNLOAD

DirText "Setup will install Classic Fortress in the following folder. To install in a different folder, click Browse and select another folder. Click Next to continue.$\r$\n$\r$\nIt is NOT ADVISABLE to install in the Program Files folder." "Destination Folder" "Browse" "Select the folder to install Classic Fortress in:"
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryPageShow
!insertmacro MUI_PAGE_DIRECTORY

ShowInstDetails "nevershow"
!insertmacro MUI_PAGE_INSTFILES

Page custom ERRORS

!define MUI_PAGE_CUSTOMFUNCTION_SHOW "FinishShow"
!define MUI_FINISHPAGE_LINK "Get started with Classic Fortress"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/Classic-Fortress/client-installer/wiki"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!insertmacro MUI_PAGE_FINISH

;----------------------------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

;----------------------------------------------------
;NSIS Manipulation

LangString ^Branding ${LANG_ENGLISH} "Classic Fortress Client Installer"
LangString ^SetupCaption ${LANG_ENGLISH} "Classic Fortress Client Installer"
LangString ^SpaceRequired ${LANG_ENGLISH} "Download size: "

;----------------------------------------------------
;Reserve Files

ReserveFile "download.ini"
ReserveFile "errors.ini"

!insertmacro MUI_RESERVEFILE_INSTALLOPTIONS

;----------------------------------------------------
;Installer Sections

Section "" # Prepare installation

  SetOutPath $INSTDIR

  # Set progress bar
  RealProgress::SetProgress /NOUNLOAD 0

  # Read information from custom pages
  !insertmacro MUI_INSTALLOPTIONS_READ $DISTFILES_PATH "download.ini" "Field 3" "State"
  !insertmacro MUI_INSTALLOPTIONS_READ $DISTFILES_UPDATE "download.ini" "Field 4" "State"
  !insertmacro MUI_INSTALLOPTIONS_READ $DISTFILES_REDOWNLOAD "download.ini" "Field 5" "State"
  !insertmacro MUI_INSTALLOPTIONS_READ $DISTFILES_DELETE "download.ini" "Field 6" "State"

  # Create distfiles folder if it doesn't already exist
  ${Unless} ${FileExists} "$DISTFILES_PATH\*.*"
    CreateDirectory $DISTFILES_PATH
  ${EndUnless}

  # Calculate the installation size
  ${Unless} ${FileExists} "$INSTDIR\ID1\PAK0.PAK"
  ${OrUnless} ${FileExists} "$EXEDIR\pak0.pak"
  ${OrUnless} ${FileExists} "$DISTFILES_PATH\pak0.pak"
    ReadINIStr $0 $CFORT_INI "distfile_sizes" "qsw106.zip"
    IntOp $INSTSIZE $INSTSIZE + $0
  ${EndUnless}
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-gpl.zip"
  IntOp $INSTSIZE $INSTSIZE + $0
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-non-gpl.zip"
  IntOp $INSTSIZE $INSTSIZE + $0

  # Find out what mirror was selected
  !insertmacro MUI_INSTALLOPTIONS_READ $R0 "download.ini" "Field 8" "State"
  ${If} $R0 == "Randomly selected mirror (Recommended)"
    # Get amount of mirrors ($0 = amount of mirrors)
    StrCpy $0 1
    ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
    ${DoUntil} $1 == ""
      ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
      IntOp $0 $0 + 1
    ${LoopUntil} $1 == ""
    IntOp $0 $0 - 2
  
    # Get time (seconds)
    ${time::GetLocalTime} $1
    StrCpy $1 $1 "" -2
    
    # Fix seconds (00 -> 1, 01-09 -> 1-9)
    ${If} $1 == "00"
      StrCpy $1 1
    ${Else}
      StrCpy $2 $1 1 -2
      ${If} $2 == 0
        StrCpy $1 $1 1 -1
      ${EndIf}
    ${EndIf}
  
    # Loop until you get a number that's within the range 0 < x =< $0
    ${DoUntil} $1 <= $0
      IntOp $1 $1 - $0
    ${LoopUntil} $1 <= $0
    ReadINIStr $DISTFILES_URL $CFORT_INI "mirror_addresses" $1
    ReadINIStr $0 $CFORT_INI "mirror_descriptions" $1
  ${Else}
    ${For} $0 1 1000
      ReadINIStr $R1 $CFORT_INI "mirror_descriptions" $0
      ${If} $R0 == $R1
        ReadINIStr $DISTFILES_URL $CFORT_INI "mirror_addresses" $0
        ReadINIStr $0 $CFORT_INI "mirror_descriptions" $0
        ${ExitFor}
      ${EndIf}
    ${Next}
  ${EndIf}

  # Open temporary files
  GetTempFileName $INSTLOGTMP
  GetTempFileName $DISTLOGTMP
  GetTempFileName $ERRLOGTMP
  FileOpen $INSTLOG $INSTLOGTMP w
  FileOpen $DISTLOG $DISTLOGTMP w
  FileOpen $ERRLOG $ERRLOGTMP a

SectionEnd

Section "Classic Fortress" CFORT

  # Download and install pak0.pak (shareware data) unless pak0.pak can be found alongside the installer executable
  ${If} ${FileExists} "$EXEDIR\pak0.pak"
    StrCpy $R0 "$EXEDIR"
  ${ElseIf} ${FileExists} "$DISTFILES_PATH\pak0.pak"
    StrCpy $R0 "$DISTFILES_PATH"
  ${EndIf}
  ${GetSize} $R0 "/M=pak0.pak /S=0B /G=0" $7 $8 $9
  ${If} $7 == "18689235"
    CreateDirectory "$INSTDIR\qw"
    CopyFiles "$R0\pak0.pak" "$INSTDIR\qw\pak0.pak"
    # Keep pak0.pak and remove qsw106.zip in distfile folder if DISTFILES_DELETE is 0
    ${If} $DISTFILES_DELETE == 0
      CopyFiles "$INSTDIR\qw\pak0.pak" "$DISTFILES_PATH\pak0.pak"
      Delete "$DISTFILES_PATH\qsw106.zip"
    ${EndIf}
    FileWrite $INSTLOG "qw\pak0.pak$\r$\n"
    Goto SkipShareware
  ${EndIf}
  !insertmacro InstallSection qsw106.zip "Quake shareware"
  # Remove crap files extracted from shareware zip and rename uppercase files/folders
  Delete "$INSTDIR\CWSDPMI.EXE"
  Delete "$INSTDIR\QLAUNCH.EXE"
  Delete "$INSTDIR\QUAKE.EXE"
  Delete "$INSTDIR\GENVXD.DLL"
  Delete "$INSTDIR\QUAKEUDP.DLL"
  Delete "$INSTDIR\PDIPX.COM"
  Delete "$INSTDIR\Q95.BAT"
  Delete "$INSTDIR\COMEXP.TXT"
  Delete "$INSTDIR\HELP.TXT"
  Delete "$INSTDIR\LICINFO.TXT"
  Delete "$INSTDIR\MANUAL.TXT"
  Delete "$INSTDIR\ORDER.TXT"
  Delete "$INSTDIR\README.TXT"
  Delete "$INSTDIR\READV106.TXT"
  Delete "$INSTDIR\SLICNSE.TXT"
  Delete "$INSTDIR\TECHINFO.TXT"
  Delete "$INSTDIR\MGENVXD.VXD"
  Rename "$INSTDIR\ID1" "$INSTDIR\qw"
  Rename "$INSTDIR\qw\PAK0.PAK" "$INSTDIR\qw\pak0.pak"
  # Keep pak0.pak and remove qsw106.zip in distfile folder if DISTFILES_DELETE is 0
  ${If} $DISTFILES_DELETE == 0
    CopyFiles "$INSTDIR\qw\pak0.pak" "$DISTFILES_PATH\pak0.pak"
    Delete "$DISTFILES_PATH\qsw106.zip"
  ${EndIf}
  SkipShareware:
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "qsw106.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download and install GPL files
  !insertmacro InstallSection cfort-gpl.zip "Classic Fortress setup files (GPL licensed)"
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-gpl.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download and install non-GPL files
  !insertmacro InstallSection cfort-non-gpl.zip "Classic Fortress setup files (non-GPL licensed)"
  # Add to installed size
  ReadINIStr $0 $CFORT_INI "distfile_sizes" "cfort-non-gpl.zip"
  IntOp $INSTALLED $INSTALLED + $0
  # Set progress bar
  IntOp $0 $INSTALLED * 100
  IntOp $0 $0 / $INSTSIZE
  RealProgress::SetProgress /NOUNLOAD $0

  # Download configuration files
  Call .installConfigs

  # Copy pak1.pak if it can be found alongside the installer executable
  ${If} ${FileExists} "$EXEDIR\pak1.pak"
    StrCpy $R0 "$EXEDIR"
  ${ElseIf} ${FileExists} "$DISTFILES_PATH\pak1.pak"
    StrCpy $R0 "$DISTFILES_PATH"
  ${EndIf}
  ${GetSize} "$R0" "/M=pak1.pak /S=0B /G=0" $7 $8 $9
  ${If} $7 == "34257856"
    CopyFiles "$R0\pak1.pak" "$INSTDIR\qw\pak1.pak"
    ${If} $DISTFILES_DELETE == 0
    ${AndIf} $R0 != $DISTFILES_PATH
      CopyFiles "$R0\pak1.pak" "$DISTFILES_PATH\pak1.pak"
    ${EndIf}
    FileWrite $INSTLOG "qw\pak1.pak$\r$\n"
    # Remove gpl maps also
    Delete "$INSTDIR\qw\duds.pk3"
    Delete "$INSTDIR\qw\readme.txt"
  ${EndIf}

SectionEnd

Section "" # Clean up installation

  # Close open temporary files
  FileClose $INSTLOG
  FileClose $ERRLOG
  FileClose $DISTLOG

  # Write install.log
  FileOpen $INSTLOG "$INSTDIR\install.log" w
    ${time::GetFileTime} "$INSTDIR\install.log" $0 $1 $2
    FileWrite $INSTLOG "Install date: $1$\r$\n"
    FileOpen $R0 $INSTLOGTMP r
      ClearErrors
      ${DoUntil} ${Errors}
        FileRead $R0 $0
        StrCpy $0 $0 -2
        ${If} ${FileExists} "$INSTDIR\$0"
          FileWrite $INSTLOG "$0$\r$\n"
        ${EndIf}
      ${LoopUntil} ${Errors}
    FileClose $R0
  FileClose $INSTLOG

  # Remove downloaded distfiles
  ${If} $DISTFILES_DELETE == 1
    FileOpen $DISTLOG $DISTLOGTMP r
      ${DoUntil} ${Errors}
        FileRead $DISTLOG $0
        StrCpy $0 $0 -2
        ${If} ${FileExists} "$DISTFILES_PATH\$0"
          Delete /REBOOTOK "$DISTFILES_PATH\$0"
        ${EndIf}
      ${LoopUntil} ${Errors}
    FileClose $DISTLOG
    # Remove directory if empty
    !insertmacro RemoveFolderIfEmpty $DISTFILES_PATH
  # Copy cfort.ini to the distfiles directory if "update distfiles" and "keep distfiles" was set
  ${ElseIf} $DISTFILES_UPDATE == 1
    FlushINI $CFORT_INI
    CopyFiles $CFORT_INI "$DISTFILES_PATH\cfort.ini"
  ${EndIf}

SectionEnd

;----------------------------------------------------
;Custom Pages

Function DOWNLOAD

  !insertmacro MUI_INSTALLOPTIONS_EXTRACT "download.ini"
  # Change the text on the distfile folder page if the installer is in offline mode
  ${If} $OFFLINE == 1
    !insertmacro MUI_HEADER_TEXT "Setup Files" "Select where the setup files are located."
    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 1" "Text" "Setup will use the setup files located in the following folder. To use a different folder, click Browse and select another folder. Click Next to continue."
    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 4" "Type" ""
    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 4" "State" "0"
    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 5" "Type" ""
    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 5" "State" "0"
  ${Else}
    !insertmacro MUI_HEADER_TEXT "Setup Files" "Select the download location for the setup files."
  ${EndIf}
  !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 3" "State" "${DISTFILES_PATH}"

  # Only display mirror selection if the installer is in online mode
  ${Unless} $OFFLINE == 1
    # Fix the mirrors for the Preferences page
    StrCpy $0 1
    StrCpy $2 "Randomly selected mirror (Recommended)"
    ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
    ${DoUntil} $1 == ""
      ReadINIStr $1 $CFORT_INI "mirror_descriptions" $0
      ${Unless} $1 == ""
        StrCpy $2 "$2|$1"
      ${EndUnless}
      IntOp $0 $0 + 1
    ${LoopUntil} $1 == ""

    StrCpy $0 $2 3
    ${If} $0 == "|"
      StrCpy $2 $2 "" 1
    ${EndIf}

    !insertmacro MUI_INSTALLOPTIONS_WRITE "download.ini" "Field 8" "ListItems" $2
  ${EndUnless}

  !insertmacro MUI_INSTALLOPTIONS_DISPLAY "download.ini"

FunctionEnd

Function ERRORS

  # Only display error page if errors occured during installation
  ${If} $ERRORS > 0
    # Read errors from error log
    StrCpy $1 ""
    FileOpen $R0 $ERRLOGTMP r
      ClearErrors
      FileRead $R0 $0
      StrCpy $1 $0
      ${DoUntil} ${Errors}
        FileRead $R0 $0
        ${Unless} $0 == ""
          StrCpy $1 "$1|$0"
        ${EndUnless}
      ${LoopUntil} ${Errors}
    FileClose $R0

    !insertmacro MUI_INSTALLOPTIONS_EXTRACT "errors.ini"
    ${If} $ERRORS == 1
      !insertmacro MUI_HEADER_TEXT "Error" "An error occurred during the installation of Classic Fortress."
      !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 1" "Text" "There was an error during the installation of Classic Fortress. See below for more information."
    ${Else}
      !insertmacro MUI_HEADER_TEXT "Errors" "Some errors occurred during the installation of Classic Fortress."
      !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 1" "Text" "There were some errors during the installation of Classic Fortress. See below for more information."
    ${EndIf}
    !insertmacro MUI_INSTALLOPTIONS_WRITE "errors.ini" "Field 2" "ListItems" $1
    !insertmacro MUI_INSTALLOPTIONS_DISPLAY "errors.ini"
  ${EndIf}

FunctionEnd

;----------------------------------------------------
;Welcome/Finish page manipulation

Function WelcomeShow
  # Remove the part about Classic Fortress being an online installer on welcome page if the installer is in offline mode
  ${Unless} $OFFLINE == 1
    !insertmacro MUI_INSTALLOPTIONS_WRITE "ioSpecial.ini" "Field 3" "Text" "This is the installation wizard of Classic Fortress, the only true way to experience the original Team Fortress as it was meant to be.\r\n\r\nThis is an online installer and therefore requires a stable internet connection."
  ${Else}
    !insertmacro MUI_INSTALLOPTIONS_WRITE "ioSpecial.ini" "Field 3" "Text" "This is the installation wizard of Classic Fortress, the only true way to experience the original Team Fortress as it was meant to be."
  ${EndUnless}
FunctionEnd

Function FinishShow
  # Hide the Back button on the finish page if there were no errors
  ${Unless} $ERRORS > 0
    GetDlgItem $R0 $HWNDPARENT 3
    EnableWindow $R0 0
  ${EndUnless}
  # Hide the community link if the installer is in offline mode
  ${If} $OFFLINE == 1
    !insertmacro MUI_INSTALLOPTIONS_READ $R0 "ioSpecial.ini" "Field 5" "HWND"
    ShowWindow $R0 ${SW_HIDE}
  ${EndIf}
FunctionEnd

;----------------------------------------------------
;Download size manipulation

!define SetSize "Call SetSize"

Function SetSize
  # Only add shareware if pak0.pak doesn't exist
  IntOp $1 0 + 0
  ${Unless} ${FileExists} "$INSTDIR\ID1\pak0.pak"
    ${If} ${FileExists} "$EXEDIR\pak0.pak"
      StrCpy $R0 "$EXEDIR"
    ${ElseIf} ${FileExists} "$DISTFILES_PATH\pak0.pak"
      StrCpy $R0 "$DISTFILES_PATH"
    ${EndIf}
    ${GetSize} $R0 "/M=pak0.pak /S=0B /G=0" $7 $8 $9
    ${If} $7 == "18689235"
      Goto SkipShareware
    ${EndIf}
  ${EndUnless}
  !insertmacro DetermineSectionSize qsw106.zip
  IntOp $1 $1 + $SIZE
  SkipShareware:
  !insertmacro DetermineSectionSize cfort-gpl.zip
  IntOp $1 $1 + $SIZE
  !insertmacro DetermineSectionSize cfort-non-gpl.zip
  IntOp $1 $1 + $SIZE
FunctionEnd

Function DirectoryPageShow
  ${SetSize}
  SectionSetSize ${CFORT} $1
FunctionEnd 

;----------------------------------------------------
;Functions

Function .onInit

  !insertmacro MULTIUSER_INIT
  GetTempFileName $CFORT_INI

  # Download cfort.ini
  Start:
  inetc::get /NOUNLOAD /CAPTION "Initializing..." /BANNER "Classic Fortress is initializing, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/cfort.ini" $CFORT_INI /END
  Pop $0
  ${Unless} $0 == "OK"
    ${If} $0 == "Cancelled"
      MessageBox MB_OK|MB_ICONEXCLAMATION "Installation aborted."
      Abort
    ${Else}
      ${Unless} $RETRIES > 0
        MessageBox MB_YESNO|MB_ICONEXCLAMATION "Are you trying to install Classic Fortress offline?" IDNO Online
        StrCpy $OFFLINE 1
        Goto InitEnd
      ${EndUnless}
      Online:
      ${Unless} $RETRIES == 2
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "Could not download cfort.ini." IDCANCEL Cancel
        IntOp $RETRIES $RETRIES + 1
        Goto Start
      ${EndUnless}
      MessageBox MB_OK|MB_ICONEXCLAMATION "Could not download cfort.ini. Please try again later."
      Cancel:
      Abort
    ${EndIf}
  ${EndUnless}

  InitEnd:

FunctionEnd

Function .abortInstallation

  # Close open temporary files
  FileClose $ERRLOG
  FileClose $INSTLOG
  FileClose $DISTLOG

  # Write install.log
  FileOpen $INSTLOG "$INSTDIR\install.log" w
    ${time::GetFileTime} "$INSTDIR\install.log" $0 $1 $2
    FileWrite $INSTLOG "Install date: $1$\r$\n"
    FileOpen $R0 $INSTLOGTMP r
      ClearErrors
      ${DoUntil} ${Errors}
        FileRead $R0 $0
        FileWrite $INSTLOG $0
      ${LoopUntil} ${Errors}
    FileClose $R0
  FileClose $INSTLOG

  # Ask to remove installed files
  Messagebox MB_YESNO|MB_ICONEXCLAMATION "Installation aborted.$\r$\n$\r$\nDo you wish to remove the installed files?" IDNO SkipInstRemoval
  # Show details window
  SetDetailsView show
  # Get line count for install.log
  Push "$INSTDIR\install.log"
  Call .LineCount
  Pop $R1 # Line count
  IntOp $R1 $R1 - 1 # Remove the timestamp from the line count
  FileOpen $R0 "$INSTDIR\install.log" r
    # Get installation time from install.log
    FileRead $R0 $0
    StrCpy $1 $0 -2 14
    StrCpy $5 1 # Current line
    StrCpy $6 0 # Current % Progress
    ${DoUntil} ${Errors}
      FileRead $R0 $0
      StrCpy $0 $0 -2
      ${If} ${FileExists} "$INSTDIR\$0"
        ${time::GetFileTime} "$INSTDIR\$0" $2 $3 $4
        ${time::MathTime} "second($1) - second($3) =" $2
        ${If} $2 >= 0
          Delete /REBOOTOK "$INSTDIR\$0"
        ${EndIf}
      ${EndIf}
      # Set progress bar
      IntOp $7 $5 * 100
      IntOp $7 $7 / $R1
      RealProgress::SetProgress /NOUNLOAD $7
      IntOp $5 $5 + 1
    ${LoopUntil} ${Errors}
  FileClose $R0
  Delete /REBOOTOK "$INSTDIR\install.log"
  ${locate::RMDirEmpty} $INSTDIR /M=*.* $0
  DetailPrint "Removed $0 empty directories"
  # Remove directory if empty
  !insertmacro RemoveFolderIfEmpty $INSTDIR
  Goto InstEnd
  SkipInstRemoval:
  Delete /REBOOTOK "$INSTDIR\install.log"
  InstEnd:

  # Ask to remove downloaded distfiles
  Messagebox MB_YESNO|MB_ICONEXCLAMATION "Do you wish to keep the downloaded distribution files?" IDYES DistEnd
  # Get line count for distfiles.log
  Push $DISTLOGTMP
  Call .LineCount
  Pop $R1 # Line count
  FileOpen $R0 $DISTLOGTMP r
    StrCpy $5 0 # Current line
    StrCpy $6 0 # Current % Progress
    ${DoUntil} ${Errors}
      FileRead $R0 $0
      StrCpy $0 $0 -2
      ${If} ${FileExists} "$DISTFILES_PATH\$0"
        Delete /REBOOTOK "$DISTFILES_PATH\$0"
      ${EndIf}
      # Set progress bar
      IntOp $7 $5 * 100
      IntOp $7 $7 / $R1
      RealProgress::SetProgress /NOUNLOAD $7
      IntOp $5 $5 + 1
    ${LoopUntil} ${Errors}
  FileClose $R0
  # Remove directory if empty
  !insertmacro RemoveFolderIfEmpty $DISTFILES_PATH
  DistEnd:

  # Set progress bar to 100%
  RealProgress::SetProgress /NOUNLOAD 100

  Abort

FunctionEnd

Function .checkDistfileDate
  StrCpy $R2 0
  ReadINIStr $0 $CFORT_INI "distfile_dates" $R0
  ${If} ${FileExists} "$DISTFILES_PATH\$R0"
    ${GetTime} "$DISTFILES_PATH\$R0" M $2 $3 $4 $5 $6 $7 $8
    # Fix hour format
    ${If} $6 < 10
      StrCpy $6 "0$6"
    ${EndIf}
    StrCpy $1 "$4$3$2$6$7$8"
    ${If} $1 < $0
    ${OrIf} $DISTFILES_REDOWNLOAD == 1
      StrCpy $R2 1
    ${Else}
      ReadINIStr $1 "$DISTFILES_PATH\cfort.ini" "distfile_dates" $R0
      ${Unless} $1 == ""
        ${If} $1 < $0
          StrCpy $R2 1
        ${EndIf}
      ${EndUnless}
    ${EndIf}
  ${EndIf}
FunctionEnd

Function .installConfigs
  CreateDirectory "$INSTDIR\fortress\classes"

  StrCpy $0 "fortress\default.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading default configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\scout.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading scout configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\sniper.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading sniper configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\soldier.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading soldier configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\demoman.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading demoman configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\medic.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading medic configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\hwguy.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading hwguy configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\pyro.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading pyro configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\spy.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading spy configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"

  StrCpy $0 "fortress\classes\engineer.cfg"
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading engineer configuration, please wait..." /TIMEOUT 5000 "https://raw.githubusercontent.com/Classic-Fortress/client-scripts/master/default.cfg" "$INSTDIR\$0" /END
  FileWrite $DISTLOG "$0$\r$\n"
FunctionEnd

Function .installDistfile
  Retry:
  ${Unless} $R2 == 0 # if $R2 is 1 then distfile needs updating, otherwise not
    inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading $R1 update, please wait..." /TIMEOUT 5000 "$DISTFILES_URL/$R0" "$DISTFILES_PATH\$R0" /END
  ${Else}
    inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading $R1, please wait..." /TIMEOUT 5000 "$DISTFILES_URL/$R0" "$DISTFILES_PATH\$R0" /END
  ${EndUnless}
  FileWrite $DISTLOG "$R0$\r$\n"
  Pop $0
  ${Unless} $0 == "OK"
    ${If} $0 == "Cancelled"
      Call .abortInstallation
    ${Else}
      MessageBox MB_ABORTRETRYIGNORE|MB_ICONEXCLAMATION "Error downloading $R0: $0" IDIGNORE Ignore IDRETRY Retry
      Call .abortInstallation
      Ignore:
      FileWrite $ERRLOG 'Error downloading "$R0": $0|'
      IntOp $ERRORS $ERRORS + 1
    ${EndIf}
  ${EndUnless}
  StrCpy $DISTFILES 1
  DetailPrint "Extracting $R1, please wait..."
  nsisunz::UnzipToStack "$DISTFILES_PATH\$R0" $INSTDIR
FunctionEnd

Function .installSection
  Pop $R1 # distfile info
  Pop $R0 # distfile filename
  Call .checkDistfileDate
  ${If} ${FileExists} "$EXEDIR\$R0"
    DetailPrint "Extracting $R1, please wait..."
    nsisunz::UnzipToStack "$EXEDIR\$R0" $INSTDIR
  ${ElseIf} ${FileExists} "$DISTFILES_PATH\$R0"
  ${OrIf} $OFFLINE == 1
    ${If} $DISTFILES_UPDATE == 0
    ${OrIf} $R2 == 0
      DetailPrint "Extracting $R1, please wait..."
      nsisunz::UnzipToStack "$DISTFILES_PATH\$R0" $INSTDIR
    ${ElseIf} $R2 == 1
    ${AndIf} $DISTFILES_UPDATE == 1
      Call .installDistfile
    ${EndIf}
  ${ElseUnless} ${FileExists} "$DISTFILES_PATH\$R0"
    Call .installDistfile
  ${EndIf}
  Pop $0
  ${If} $0 == "Error opening ZIP file"
  ${OrIf} $0 == "Error opening output file(s)"
  ${OrIf} $0 == "Error writing output file(s)"
  ${OrIf} $0 == "Error extracting from ZIP file"
  ${OrIf} $0 == "File not found in ZIP file"
    FileWrite $ERRLOG 'Error extracting "$R0": $0|'
    IntOp $ERRORS $ERRORS + 1
  ${Else}
    ${DoUntil} $0 == ""
      ${Unless} $0 == "success"
        FileWrite $INSTLOG "$0$\r$\n"
      ${EndUnless}
      Pop $0
    ${LoopUntil} $0 == ""
  ${EndIf}
FunctionEnd

Function .LineCount
  Exch $R0
  Push $R1
  Push $R2
   FileOpen $R0 $R0 r
  loop:
   ClearErrors
   FileRead $R0 $R1
   IfErrors +3
    IntOp $R2 $R2 + 1
  Goto loop
   FileClose $R0
   StrCpy $R0 $R2
  Pop $R2
  Pop $R1
  Exch $R0
FunctionEnd