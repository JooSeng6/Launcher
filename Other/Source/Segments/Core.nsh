${SegmentFile}

Var LauncherFile
Var Bits
Var PALBits
Var CLParameters

${Segment.onInit}
		; These may be needed with RunAsAdmin so they can't go in Init.

		${GetBaseName} $EXEFILE $BaseName
		StrCpy $LauncherFile $EXEDIR\App\AppInfo\Launcher\$BaseName.ini

		ClearErrors
		ReadINIStr $AppID $EXEDIR\App\AppInfo\appinfo.ini Details AppID
		ReadINIStr $AppNamePortable $EXEDIR\App\AppInfo\appinfo.ini Details Name
		${If} ${Errors}
				;=== Launcher file missing or missing crucial details
				StrCpy $AppNamePortable "PortableApps.com Launcher"
				StrCpy $MissingFileOrPath $EXEDIR\App\AppInfo\appinfo.ini
				MessageBox MB_OK|MB_ICONSTOP `$(LauncherFileNotFound)`
				Quit
		${EndIf}

		${ReadLauncherConfig} $AppName Launch AppName
		${If} $AppName == ""
				; Calculate the application name - non-portable version
				${WordFind} `$AppNamePortable` " Portable" "+01" `$AppName`	
				StrCpy $1 $AppName -1
				${If} `$1` == ","
						StrCpy $AppName `$AppName` "" -1
				${EndIf}
		${EndIf}

		; Work out if it's 64-bit or 32-bit
		System::Call kernel32::GetCurrentProcess()i.s
		System::Call kernel32::IsWow64Process(is,*i.r0)
		${If} $0 == 0
				StrCpy $Bits 32
		${Else}
				StrCpy $Bits 64
		${EndIf}

		${ReadLauncherConfigWithDefault} $PALBits Launch BitsVariable$Bits $Bits
		${SetEnvironmentVariable} PAL:Bits $PALBits

		; Make the AppID available in launcher.ini
		${SetEnvironmentVariable} PAL:AppID $AppID
!macroend

${SegmentInit}
		; Copy the launcher INI file to $PLUGINSDIR so that it doesn't go splurk if
		; the disk is pulled out and can clean up.
		StrCpy $LauncherFile $EXEDIR\App\AppInfo\Launcher\$BaseName.ini
		${If} ${FileExists} $LauncherFile
				InitPluginsDir
				CopyFiles /SILENT $LauncherFile $PLUGINSDIR\launcher.ini
				StrCpy $LauncherFile $PLUGINSDIR\launcher.ini
		${Else}
				StrCpy $MissingFileOrPath $LauncherFile
				MessageBox MB_OK|MB_ICONSTOP `$(LauncherFileNotFound)`
				Quit
		${EndIf}

		; If there are command line arguments, we use
		; [Launch]:ProgramExecutableWhenParameters if it exists, falling back to
		; the normal [Launch]ProgramExecutable if it's not set or if there aren't
		; arguments.
		${GetParameters} $CLParameters
		StrCpy $ProgramExecutable ""
		
		${If} ${IsNativeARM64}
				${If} `$CLParameters` != ""
						${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutableWhenParametersARM64
						${If} `$ProgramExecutable` != ""
						${AndIfNot} ${FileExists} "$EXEDIR\App\$ProgramExecutable"
								StrCpy $ProgramExecutable ""
						${EndIf}
				${EndIf}
				
				${If} $ProgramExecutable == ""
						${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutableARM64
						${If} `$ProgramExecutable` != ""
						${AndIfNot} ${FileExists} "$EXEDIR\App\$ProgramExecutable"
								StrCpy $ProgramExecutable ""
						${EndIf}
				${EndIf}
		${EndIf}		
				
		${If} $ProgramExecutable == ""
				${If} ${IsNativeARM64}
				${AndIf} ${AtLeastW11}
				${OrIf} ${IsNativeAMD64}
						${If} `$CLParameters` != ""
								${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutableWhenParameters64
								${If} `$ProgramExecutable` != ""
								${AndIfNot} ${FileExists} "$EXEDIR\App\$ProgramExecutable"
										StrCpy $ProgramExecutable ""
								${EndIf}
						${EndIf}
								
						${If} $ProgramExecutable == ""
								${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutable64
								${If} `$ProgramExecutable` != ""
								${AndIfNot} ${FileExists} "$EXEDIR\App\$ProgramExecutable"
										StrCpy $ProgramExecutable ""
								${EndIf}
						${EndIf}	
				${EndIf}
		${EndIf}			
								
		${If} $ProgramExecutable == ""	
		${OrIf} $Bits = 32
				${If} `$CLParameters` != ""
						${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutableWhenParameters
						${If} `$ProgramExecutable` != ""
						${AndIfNot} ${FileExists} "$EXEDIR\App\$ProgramExecutable"
								StrCpy $ProgramExecutable ""
						${EndIf}
				${EndIf}
		
				${If} $ProgramExecutable == ""
						${ReadLauncherConfig} $ProgramExecutable Launch ProgramExecutable
				${EndIf}	
		${EndIf}		
		
		${If} $ProgramExecutable == ""
				; Launcher file missing or missing crucial details (what am I to launch?)
				MessageBox MB_OK|MB_ICONSTOP `$EXEDIR\App\AppInfo\Launcher\$BaseName.ini is missing [Launch]:ProgramExecutable - what am I to launch?`
				Quit
		${EndIf}
!macroend

${SegmentPreExecPrimary}
	; Save the $PLUGINSDIR so that in case of crash it can still be cleaned up next time
	${WriteRuntimeData} PortableApps.comLauncher PluginsDir $PLUGINSDIR
!macroend

${SegmentUnload}
	; Clear up $PLUGINSDIR, the runtime data which says we're running, and the
	; $PLUGINSDIR from before the hypothetical power failure.
	FileClose $_FEIP_FileHandle
	Delete $PLUGINSDIR\launcher.ini
	${If} $SecondaryLaunch != true
		${ReadRuntimeData} $0 PortableApps.comLauncher PluginsDir
		${If}    $0 != ""
		${AndIf} $0 != $PLUGINSDIR
			RMDir /r $0
		${EndIf}
		Delete $DataDirectory\PortableApps.comLauncherRuntimeData-$BaseName.ini
	${EndIf}
	Delete $PLUGINSDIR\runtimedata.ini
	; Unload the system plug-in (if it's still there?)
	System::Free 0
!macroend
