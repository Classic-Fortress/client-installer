;Classic Fortress NSIS Distfiles.ini Creator Script

; Path where distribution files reside
InstallDir "C:\Users\Niclas\Dropbox\Projects\Classic Fortress\Files"

Name "Classic Fortress INI Generator"
OutFile "cfortini.exe"
!define OUTDIR "."

# Editing anything below this line is not recommended
;---------------------------------------------------

!define DISTFILES_PATH_RELATIVE "cfort-distfiles"

;----------------------------------------------------
;Header Files

!include "MUI.nsh"
!include "Sections.nsh"
!include "FileFunc.nsh"
!insertmacro GetSize
!insertmacro GetTime
!include "LogicLib.nsh"

;----------------------------------------------------
;Initialize Variables

Var MIRRORS_INI
Var INSTALLERVERSIONS_INI

;----------------------------------------------------
;Interface Settings

!define MUI_HEADERIMAGE

;----------------------------------------------------
;Pages

!define MUI_PAGE_HEADER_TEXT "Folder Selection"
!define MUI_PAGE_HEADER_SUBTEXT "Please select the folder in which the distribution files are located."
!define MUI_DIRECTORYPAGE_TEXT_TOP "The following folder will be used to retrieve information. To use a different folder, click Browse and select another folder. Click Generate to start the generation."
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Folder"
!insertmacro MUI_PAGE_DIRECTORY

ShowInstDetails "show"
!define MUI_PAGE_HEADER_TEXT "Generating"
!define MUI_PAGE_HEADER_SUBTEXT "Please wait while cfort.ini is being generated."
!define MUI_INSTFILESPAGE_FINISHHEADER_TEXT "Generation Successful"
!define MUI_INSTFILESPAGE_FINISHHEADER_SUBTEXT "Generation completed successfully!"
!define MUI_INSTFILESPAGE_ABORTHEADER_TEXT "Generation Aborted"
!define MUI_INSTFILESPAGE_ABORTHEADER_SUBTEXT "Generation could not complete successfully."
!insertmacro MUI_PAGE_INSTFILES

;----------------------------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

LangString ^Branding ${LANG_ENGLISH} "$(^Name)"
LangString ^SetupCaption ${LANG_ENGLISH} "$(^Name)"
LangString ^DirBrowseText ${LANG_ENGLISH} "Select the folder to retrieve distribution file sizes from:"
LangString ^InstallBtn ${LANG_ENGLISH} "Generate"

;----------------------------------------------------
;Macros

!macro WriteINIString PACKAGE
  StrCpy $R0 "${PACKAGE}.zip"
  StrCpy $R1 ${PACKAGE}
  # Write distfile size
  ${If} ${FileExists} "$EXEDIR\$R0"
    ${GetSize} "$EXEDIR" "/M=$R0 /S=0K /G=0" $7 $8 $9
    StrCpy $0 $7
  ${ElseIf} ${FileExists} "$INSTDIR\$R0"
    ${GetSize} "$INSTDIR" "/M=$R0 /S=0K /G=0" $7 $8 $9
    StrCpy $0 $7
  ${ElseIf} ${FileExists} "$EXEDIR\..\..\Classic Fortresssv\Distfiles\$R0"
    ${GetSize} "$EXEDIR\..\..\Classic Fortresssv\Distfiles" "/M=$R0 /S=0K /G=0" $7 $8 $9
    StrCpy $0 $7
  ${Else}
    ;Messagebox MB_OK|MB_ICONEXCLAMATION "Distribution package '$R0' is missing. Cannot complete generation."
	Messagebox MB_OK|MB_ICONEXCLAMATION "Distribution package '$R0' is missing. Entering zero bytes."
    StrCpy $0 0
  ${EndIf}
  WriteINIStr "$EXEDIR\cfort.ini" "distfile_sizes" $R0 $0
  DetailPrint "Writing to cfort.ini: [distfile_sizes] $R0=$0"
  # Write distfile date
  ${If} ${FileExists} "$EXEDIR\$R0"
    ${GetTime} "$EXEDIR\$R0" M $2 $3 $4 $5 $6 $7 $8
  ${ElseIf} ${FileExists} "$INSTDIR\$R0"
    ${GetTime} "$INSTDIR\$R0" M $2 $3 $4 $5 $6 $7 $8
  ${ElseIf} ${FileExists} "$EXEDIR\..\..\Classic Fortresssv\Distfiles\$R0"
    ${GetTime} "$EXEDIR\..\..\Classic Fortresssv\Distfiles\$R0" M $2 $3 $4 $5 $6 $7 $8
  ${Else}
    ${GetTime} "" L $2 $3 $4 $5 $6 $7 $8
  ${EndIf}
  # Fix hour format
  ${If} $6 < 10
    StrCpy $6 "0$6"
  ${EndIf}
  StrCpy $0 "$4$3$2$6$7$8"
  WriteINIStr "$EXEDIR\cfort.ini" "distfile_dates" $R0 $0
  DetailPrint "Writing to cfort.ini: [distfile_dates] $R0=$0"
!macroend

;----------------------------------------------------
;Installer Sections

Section "cfort.ini"

  ${If} ${FileExists} "$EXEDIR\cfort.ini"
    Delete "$EXEDIR\cfort.ini"
  ${EndIf}

  StrCpy $1 "0"

  !insertmacro WriteINIString qwtf-gpl
  !insertmacro WriteINIString qwtf-non-gpl
  !insertmacro WriteINIString qwtf-sv-bin-x64
  !insertmacro WriteINIString qwtf-sv-bin-x86
  !insertmacro WriteINIString qwtf-sv-bin-win32
  !insertmacro WriteINIString qwtf-sv-configs
  !insertmacro WriteINIString qwtf-sv-gpl
  !insertmacro WriteINIString qwtf-sv-maps
  !insertmacro WriteINIString qwtf-sv-non-gpl
  !insertmacro WriteINIString qwtf-sv-win32
  !insertmacro WriteINIString qsw106

  GetTempFileName $MIRRORS_INI
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading mirror information..." "https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/mirrors.ini" $MIRRORS_INI /END

  # Extract information from mirrors.ini
  StrCpy $0 "1"
  ReadINIStr $1 $MIRRORS_INI "mirrors" $0
  ReadINIStr $2 $MIRRORS_INI "description" $0
  WriteINIStr "$EXEDIR\cfort.ini" "mirror_addresses" $0 $1
  WriteINIStr "$EXEDIR\cfort.ini" "mirror_descriptions" $0 '"$2"'
  DetailPrint "Writing to cfort.ini: [mirror_addresses] $0=$1"
  DetailPrint "Writing to cfort.ini: [mirror_descriptions] $0=$2"
  ${DoUntil} $1 == ""
    IntOp $0 $0 + 1
    ReadINIStr $1 $MIRRORS_INI "mirrors" $0
    ReadINIStr $2 $MIRRORS_INI "description" $0
    ${Unless} $1 == ""
      WriteINIStr "$EXEDIR\cfort.ini" "mirror_addresses" $0 $1
      WriteINIStr "$EXEDIR\cfort.ini" "mirror_descriptions" $0 '"$2"'
      DetailPrint "Writing to cfort.ini: [mirror_addresses] $0=$1"
      DetailPrint "Writing to cfort.ini: [mirror_descriptions] $0=$2"
    ${EndUnless}
  ${Loop}

  GetTempFileName $INSTALLERVERSIONS_INI
  inetc::get /NOUNLOAD /CAPTION "Downloading..." /BANNER "Downloading version information..." "https://raw.githubusercontent.com/Classic-Fortress/client-installer/master/installerversions.ini" $INSTALLERVERSIONS_INI /END

  # Copy version from installerversions.ini
  ReadINIStr $0 $INSTALLERVERSIONS_INI "versions" "windows"
  ReadINIStr $1 $INSTALLERVERSIONS_INI "versions" "linux"
  ReadINIStr $2 $INSTALLERVERSIONS_INI "versions" "macosx"
  ReadINIStr $3 $INSTALLERVERSIONS_INI "versions" "server"
  ReadINIStr $4 $INSTALLERVERSIONS_INI "versions" "serverwindows"

  WriteINIStr "$EXEDIR\cfort.ini" "versions" "windows" $0
  WriteINIStr "$EXEDIR\cfort.ini" "versions" "linux" $1
  WriteINIStr "$EXEDIR\cfort.ini" "versions" "macosx" $2
  WriteINIStr "$EXEDIR\cfort.ini" "versions" "server" $3
  WriteINIStr "$EXEDIR\cfort.ini" "versions" "server" $4
  DetailPrint "Writing to cfort.ini: [versions] windows=$0"
  DetailPrint "Writing to cfort.ini: [versions] linux=$1"
  DetailPrint "Writing to cfort.ini: [versions] macosx=$2"
  DetailPrint "Writing to cfort.ini: [versions] server=$3"
  DetailPrint "Writing to cfort.ini: [versions] serverwindows=$4"

SectionEnd