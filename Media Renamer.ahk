

;============================== Start Auto-Execution Section ==============================
; Always run as admin
if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"  ; Requires v1.0.92.01+
   ExitApp
}

; Keeps script permanently running
#Persistent

; Determines how fast a script will run (affects CPU utilization).
; The value -1 means the script will run at it's max speed possible.
SetBatchLines, -1

; Avoids checking empty variables to see if they are environment variables.
; Recommended for performance and compatibility with future AutoHotkey releases.
#NoEnv

; Ensures that there is only a single instance of this script running.
#SingleInstance, Force

; Makes a script unconditionally use its own folder as its working directory.
; Ensures a consistent starting directory.
SetWorkingDir %A_ScriptDir%

; sets title matching to search for "containing" instead of "exact"
SetTitleMatchMode, 2

; sets the key send input type. Event is used to make use of KeyDelay.
SendMode, Input

; Sets delay between key strokes and how long a key should be pressed.
; SetKeyDelay KeyStrokeDelay, 
SetKeyDelay 25, 10

GroupAdd, saveReload, %A_ScriptName%

gosub, mainGui

return

;============================== Save Reload ==============================
#IfWinActive, ahk_group saveReload

; Use Control+S to save your script and reload it at the same time.
~^s::
	TrayTip, Reloading updated script, %A_ScriptName%
	SetTimer, RemoveTrayTip, 1500
	Sleep, 1750
	Reload
return

; Removes any popped up tray tips.
RemoveTrayTip:
	SetTimer, RemoveTrayTip, Off 
	TrayTip 
return 

#IfWinActive

;============================== Hard exit ==============================
; Shift+Escape to suspend hotkeys and pause script.
; Control+Shift+Escape to exit app
+Esc::
	Suspend, On
	Pause, On
return
	
^+Esc::
	ExitApp

;============================== Main Script ==============================

mainGUI:
	; Clear paths
	clear()

	FileDelete, %A_Temp%\mediaInfoTemp.txt
	FileDelete, %A_Temp%\AHKTempMediaRenamer.txt

	Gui, Destroy
	Gui, Add, GroupBox, x2 y9 w270 h200 , Rename Media Files
	Gui, Add, Button, x12 y29 w100 h30 gselectFolder, Select Media Folder
	Gui, Add, Text, x12 y69 w250 h30 vGUIMediaFolderPath, Click "Select Media Folder"
	Gui, Add, Button, x12 y99 w100 h30 gselectMediaTitleText, Browse for Media Title Text File
	Gui, Add, Text, x12 y139 w250 h30 vGUITextTitlePath, Click "Browse for Media Title Text File"
	Gui, Add, Button, x162 y170 w100 h30 grenameFiles, Rename Files
	Gui, Add, GroupBox, x2 y211 w270 h50 , Progress
	Gui, Add, Progress, x12 y231 w250 h20 , Progress Bar
	Gui, Add, Button, x12 y270 w100 h30 gmainGUI, Reset
	Gui, Add, Button, x162 y270 w100 h30 gGUIClose, Exit
	Gui, Show, w275 h315, Rename Media
return

selectFolder:
	Gui +OwnDialogs
	FileSelectFolder, mediaFolderPath, , 3, Select Media Folder
	if (ErrorLevel = 1){
		return
	}

	; Display in GUI
	GuiControl, , GUIMediaFolderPath, %mediaFolderPath%
	GuiControl, , GUIMediaFolderPathSeason, %mediaFolderPath%

	MsgBox, 8244, Rename Folders?, Would you like to rename all folders to EPGuides standards?`n`nExample: Season 1`, Season 2`, Feature Movies`, Specials...
	IfMsgBox, Yes
	{
		renameSeasons(mediaFolderPath)
	}

	; Record number of seasons (folders) and files.
	Loop, %mediaFolderPath%\*.*, 2, 0
	{
		totalFolders++
		FileAppend, %A_LoopFileName%`n, %A_Temp%\AHKTempMediaRenamer.txt
		Loop, Files, %A_LoopFileLongPath%\*.*, F
		{
			totalFiles++
			FileAppend, %A_LoopFileLongPath%`n, %A_Temp%\AHKTempMediaRenamer.txt
		}
	}
; MsgBox Total seasons found: %totalFolders%`nTotal file found: %totalFiles%

return

selectMediaTitleText:
	InputBox, mediaWebAddress, Address for Show, Please paste the address for the show here., , , , , , , , http://epguides.com/BabyBlues/
	if (ErrorLevel = 1){
		return
	}
	GuiControl, , GUITextTitlePath, %mediaWebAddress%
return


renameFiles:
	; Pulls data from epguides.com
	; Stores data in %temp%\mediaTitlesTemp.txt    
	URLDownloadToFile, %mediaWebAddress%, %A_Temp%\mediaInfoTemp.txt
	if (ErrorLevel = 1){
		MsgBox There was an error getting the info from the website.
		return
	}

	; Format web page text
	Loop, Read, %A_Temp%\mediaInfoTemp.txt
	{
		; ftt = formatTextTemp. Saves some typing!
		ftt	:= A_LoopReadLine
		; Once </pre> is encountered, break because nothing else is needed.
		If (ftt = "</pre>"){
			foundPre	:= false
			break
		}
		
		; Get show title
		IfInString, ftt, <title>
		{
			; Remove title tag
			showTitle	:= RegExReplace(ftt, "^<title>", "")
			
			; Remove everything after the last open parentheses
			showTitle	:= RegExReplace(showTitle, "\((.*)$", "")
			
			; Remove all extra white space at the end of the title
			showTitle	:= RegExReplace(showTitle, "\s*$", "")
			
		}
		
		; Do not start appending until this string is found
		tempVar	:= RegExMatch(ftt, "^(_____)")
		if (tempVar > 0){
			foundPre	:= true
			continue
		}
		
		; Once foundPre=true, the info is saved to the new file mediaTitlesTemp.txt
		if (foundPre = true){
		
			; Removes all blank lines
			if (ftt = "")
			{
				continue
			}

			; Replaces any bullet markup code found
			ftt		:= RegExReplace(ftt, "[<]?(.*)&bull; ", "")
			
			; Replaces all multi-spaced areas with two spaces
			; This is used a couple steps later for formatting.
			Loop,
			{
				StringReplace, ftt, ftt, %A_Space%%A_Space%%A_Space%, %A_Space%%A_Space%, all
				if (ErrorLevel > 1){
					MsgBox An error occured.`nProcess is aborted.
					break
				}
			} until ErrorLevel = 1
			
			; Remove all HTML tags.
			Loop,
			{
				ftt	:= RegExReplace(ftt, "^<(.*?)>", "")
				if (ErrorLevel > 1){
					MsgBox An error occured.`nProcess is aborted.
					break
				}
			} until ErrorLevel = 0
			
			; Replaces all double spaces with tabs for readability and ease in text manipulation.
			ftt		:= RegExReplace(ftt, "\s{2}", A_Tab)
			
			; Deletes "Episode list number"
			ftt		:= RegExReplace(ftt, "^(.*?)\t", "")
			
			; Deletes everything from season/episode number to title
			ftt		:= RegExReplace(ftt, "\t(.*?)>", A_Tab)
			
			; Deletes closing href tag and everything till EOL.
			ftt		:= RegExReplace(ftt, "</a>(.*)", "")
			
			; Replaces dash with tab for 
			ftt		:= RegExReplace(ftt, "[^0-9]?-[^0-9]?", A_Tab)
			
			FileAppend, %ftt%`n, %A_Temp%\mediaTitlesTemp.txt
		}
	}

	; Create array to store info
	
	; Headings: Season #, Pilot, Feature Movies, Other Episodes, Specials
	; headingArray	:= [Season, Pilot, Feature Movies, Other Episodes, Specials]
	
	; Parse each line
	Loop, Read, %A_Temp%\mediaTitlesTemp.txt
	{
;		MsgBox Starting parse.
		; Media Titles Temp
		mtt	:= A_LoopReadLine
		Loop, Parse, mtt, %A_Tab%
		{
			if (A_Index = 1){
				seasonCheck	:= RegExMatch(A_LoopField, "^([S-s]eason )")
				if (seasonCheck > 0){
					FileAppend, %A_LoopField%`n, %A_Temp%\mediaTitlesFinal.txt
					continue
				}
				
				FileAppend, %showTitle% - S%A_LoopField%, %A_Temp%\mediaTitlesFinal.txt
			}
			if (A_Index = 2){
				FileAppend, E%A_LoopField% -%A_Space%, %A_Temp%\mediaTitlesFinal.txt
			}
			if (A_Index = 3){
				FileAppend, %A_LoopField%`n, %A_Temp%\mediaTitlesFinal.txt
			}
		}
	}
	Loop, Read, %A_Temp%\mediaTitlesFinal.txt
	{
		dest		:= A_LoopReadLine
		titleCheck	:= RegExMatch(dest, "^Season [0-9]*")
		if (titleCheck > 0){
			season	:= dest
			continue
		}
		FileReadLine, source, %A_Temp%\AHKTempMediaRenamer.txt, %A_Index%
		RegExMatch(source, "\.\w*$", ext)
		FileMove, %source%, %mediaFolderPath%\%season%\%dest%%ext%
	}

	MsgBox Finished!
	; clear()
return

clear()
{
	FileDelete, %A_Temp%\AHKTempMediaRenamer.txt
	FileDelete, %A_Temp%\mediaTitlesTemp.txt
	FileDelete, %A_Temp%\mediaTitlesFinal.txt
	ext				:= 0
	episode			:= 0
	totalSeasons	:= 0
	totalEpisodes	:= 0
	totalFolders	:= 0
	totalFiles		:= 0
	titleCheck		:= 0
	foundPre		:= false
	mediaTitle      := ""
}

;Make a backup module.
;Get title name
;File should be named: <title><date>.txt

/*
	; checks how many seasons are present based on website data.
	Loop, Read, %A_Temp%\mediaTitlesTemp.txt
	{
		seasonCheck	:= RegExMatch(A_LoopReadLine, "^([S-s]eason )")
		if (seasonCheck > 0){
			totalSeasons++
		}
	}

*/

renameSeasons(mfp)
{
	FileDelete, %A_Temp%\AHKTempMedaiRenamer.txt
	; Check to ensure a folder was selected.
	if (mfp = ""){
		MsgBox You must select a season folder path.
		return
	}
	; Start recording folder names
	; This needs to eventually have a regex check that looks for names like
	; Special/Specials/Deleted Scenes/Extras/Movie/Etc...
	; Also add an "ignore special titles" or "force rename of all folders" check box
	Loop, %mfp%\*.*, 2, 0
	{
		FileAppend, %A_LoopFileLongPath%`n, %A_Temp%\AHKTempMedaiRenamer.txt
	}
	Loop, Read, %A_Temp%\AHKTempMedaiRenamer.txt
	{
		FileMoveDir, %A_LoopReadLine%, %mfp%\Season %A_Index%
	}
	FileDelete, %A_Temp%\AHKTempMedaiRenamer.txt
}

progressBar:
	;will be implemented later
return

GUIClose:
ExitApp


;============================== End Script ==============================