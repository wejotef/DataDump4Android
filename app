:: Source code of DataDump4Android
::
@echo off & setlocal enabledelayedexpansion
:: Set location of batch file
set "wrkPath=%~dp0"
pushd %wrkPath%
::
::
set "backupFolderBase=%TEMP%"
set "this=%~n0"
title !this! 
set /a dumpAll=0
set /a cntFilesTransferred=0
set /a cntFilesnotTransferred=0
set "userID=0"
set "leave=0"
set "indent=   "
set "delimiter=|"
::
::
call :show_purpose_prequistes_screen leave
if "!leave!"=="1" ( goto :quit )
call :show_copyright_license_screen leave
if "!leave!"=="1" ( goto :quit )
cls
set /a step=0
echo(
echo Prepairing...
::
echo(
set /a step+=1
<nul set /p="!step!. Verifying Windows OS version is 21H2 or later... "
::
for /f "tokens=4 delims= " %%i in ('ver') do set "versionNumber=%%i"
for /f "tokens=3 delims=." %%i in ("%versionNumber%") do set /a buildNumber=%%i
if !buildNumber! lss 22000 (
     echo NOK
	 echo( & echo Exiting...
	 goto :quit
)
echo OK
set "versionNumber=" & set "buildNumber="
::
echo(
set /a step+=1
<nul set /p="!step!. Checking presence of ADB client... "
::
set "ADB_CLIENT="
:: Search for adb.exe in the PATH environment variable
set "fileName=adb.exe"
for %%a in (%PATH%) do (
    set "adbPath=%%a\!fileName!"
    if exist "%adbPath%" (
        set "ADB_CLIENT=%adbPath%"
        goto :adbTested
    )
)
set "searchPath=\"
FOR /R "%searchPath%" %%a  in (%fileName%) DO (
    IF EXIST "%%~fa" (
        SET "ADB_CLIENT=%%~fa"
		goto :adbTested
    )
)
:adbTested
if not defined ADB_CLIENT (
    echo NOK
    echo( & echo Exiting...
    goto :quit
)
echo OK
set "adbPath=" & set "fileName=" & set "searchPath="
::
::
"!ADB_CLIENT!" kill-server
"!ADB_CLIENT!" start-server 2>nul
"!ADB_CLIENT!" usb 2>nul
::
::
echo(
set /a step+=1
<nul set /p="!step!. Testing on connected Android device... "
::
set "deviceId="
:: If a device is connected via ADB we only look for its connection is "device" or "recovery" mode
for /f "skip=1 tokens=*" %%a in ('"!ADB_CLIENT!" devices 2^>nul') do (
 	set "connection=%%a"
if not "!connection!"=="" (
	call :right_trim "!connection!"
	if "!connection:~-6!"=="device" (
   	     set "deviceId=!connection:~0,-6!"
         break
	) else (
		if "!connection:~-8!"=="recovery" (
	     	set "deviceId=!connection:~0,-8!"
			break
 		)
	)
)
)
if not defined deviceId (
	echo NOK
    echo( & echo Exiting...
    goto :quit
)
echo OK
call :right_trim "!deviceId!"
set "connection="
::
echo(
set /a step+=1
<nul set /p="!step!. Checking Android device's battery charge level is ^>=60%%... "
for /f "tokens=1,2 delims=:" %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "dumpsys battery"') do  (
	set "battProperty=%%a"
	echo !battProperty! | findstr /I /C:"Level" > nul
	if "%errorlevel%"=="0" ( set /a battLevel=%%b & break )
)
if !battLevel! lss 60 (
	echo NOK
	echo( & echo Exiting...
	goto :quit
)
echo OK
set "battProperty=" & set "battLevel="
::
echo(
set /a step+=1
<nul set /p="!step!. Checking the current boot mode ... "
::
set /a acceptedBootMode=0
for /f "delims=" %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "getprop ro.bootmode"') do set "bootMode=%%a"
if "!bootMode!"=="normal" (
   set /a acceptedBootMode=1
) else if "!bootMode!"=="recovery" (
   set /a acceptedBootMode=1
)
if !acceptedBootMode! equ 0 (
    echo NOK
    echo(
    echo Improper boot mode of connected device detected.
    echo Connected device must be booted in either normal or recovery mode.
    echo Exiting...
    goto :quit
)
echo OK
if "!bootMode!"=="normal" (
::
rem
)
::
echo(
set /a step+=1
<nul set /p="!step!. Verifying ADB daemon can run as root...
set /a adbRunsAsRoot=0
for /f "delims=" %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "getprop ro.secure"') do set "adbSecure=%%a"
if "!adbSecure!"=="0" (
	for /f "delims=" %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "getprop ro.debuggable"') do set "adbDebuggable=%%a"
	if "!adbDebuggable!"=="1" (
		for /f "tokens=*" %%i in ('"!ADB_CLIENT!" -s !deviceId! root 2^>^&1') do (
   			if /i "%%i"=="restarting adbd as root" ( set /a adbRunsAsRoot=1  )
		)
	)
)
set "adbSecure=" & set "adbDebuggabe="
if !adbRunsAsRoot! equ 0 (
	echo NOK
) else (
	echo OK
    goto :done_test_android_is_rooted
)
::
echo(
set /a step+=1
<nul set /p="!step!. Checking presence of SU binary (what indicates Android is got rooted)... "
::
set SU_CMD="
:: Recovery mode is a special boot state designed for system recovery and maintenance tasks. It's a separate environment
:: from the main Android system, and many system-level modifications, including those made by Magisk, aren't active in this mode.
for /f "delims=" %%i in ('"!ADB_CLIENT!"-s !deviceId! shell "find / -type f -name su -perm /u+x"') do (
	set "outputPath=%%i"
	if not "!outputPath!"=="" (
		:: Termux comes with a script called SU: that's unusable
		if "!outputPath!"=="/data/data/com.termux/files/usr/bin/su" (
			rem Ignore it
			set "outputPath="
		) else (
			if "!outputPath!"=="/data/user/0/com.termux/files/usr/bin/su" (
				rem Ignore it
				set "outputPath="
			) else (
				if "!outputPath!"=="/data/data/com.termux/files/home/bin/su" (
					rem Accept it
				)
			)
		)
		if defined outputPath (
			set "SU_CMD=!outputPath!"
			break
		)
	)
)
if not defined SU_CMD (
	:: If Magisk installed then SU binary should be found as /data/adb/magisk/su
	for /f "delims=" %%i in ('"!ADB_CLIENT!"-s !deviceId! shell "find /data/adb/magisk -type f -name su -perm /u+x"') do set "outputPath=%%i"
	if not "!outputPath!"=="" (
		set "SU_CMD=/data/adb/magisk/su"
	)
)
if not defined SU_CMD (
	:: If KernelSU is installed then SU binary should be found as /data/adb/ksu/bin/busybox what contains it
	for /f "delims=" %%i in ('"!ADB_CLIENT!"-s !deviceId! shell "find /data/adb/ksu/bin -type f -name busybox -perm /u+x"') do set "outputPath=%%i"
	if not "!outputPath!"=="" (
		set "SU_CMD=!outputPath! su"
	)
)
if not defined SU_CMD (
 	:: Additionally search for user-installed BUSYBOX applet suite what by default has the SU binary inside
	for /f "delims=" %%i in ('"!ADB_CLIENT!"-s !deviceId! shell "find / -type f -name busybox -perm /u+x"') do set "outputPath=%%i"
	if not "!outputPath!"=="" (
  		:: Verify user-installed BUSYBOX contains SU binary
		for /f "delims=" %%i in ('"!ADB_CLIENT!"-s !deviceId! shell "!outputPath! --list ^| grep su"') do set "outPut=%%i"
		if not "!outPut!"=="" (
			set "SU_CMD=!outputPath! su"
		)
	)
)
if not defined SU_CMD (
	   echo NOK
	   echo( & echo Exiting...
	   goto :quit
)
for /f "tokens=*" %%i in ('"!ADB_CLIENT!" -s !deviceId! shell "!SU_CMD! root -c 'id'") do set "suPerm=%%i"
echo !suPerm! | findstr /I /C:"uid=0(root) gid=0(root) groups=0(root)" > nul
if not "%errorlevel%"=="0" (
   echo NOK
   echo( & echo Exiting...
   goto :quit
)
echo OK
set "suPerm=" & set "outputPath=" & set "output="
:done_test_android_is_rooted
::
echo(
set /a step+=1
<nul set /p="!step!. Mounting /data partition as RW... "
::
set "adbCmd=mount -o rw,rewrite -t auto /data"
if !adbRunsAsRoot! equ 0 (
	call :add_su_to_adb_cmd "adbCmd"
)
"!ADB_CLIENT!" -s !deviceId! shell "!adbCmd!" || ( echo NOK & echo Exiting... & goto :quit )
echo OK
set "adbCmd="
::
echo(
set /a step+=1
<nul set /p="!step!. Testing on FBE... "
::
set /a fbeEnabled=0
for /f "tokens=*" %%i in ('"!ADB_CLIENT!" -s !deviceId! shell "getprop ro.crypto.state"') do set "cryptoState=%%i"
echo !cryptoState! | findstr /I /C:"unencrypted" > nul || ( set /a fbeEnabled=1 )
if !fbeEnabled! equ 1 (
	set /a step+=1
	<nul set /p="!step!. Preparing tempory storage on Android device... "
	set "androidTmpStorage=/data/local/tmp/backup"
	set "adbCmd=mkdir -p !androidTmpStorage!;chmod +rw  !androidTmpStorage!"
	if !adbRunsAsRoot! equ 0 (
		call :add_su_to_adb_cmd "adbCmd"
	)
	"!ADB_CLIENT!" -s !deviceId! shell "!adbCmd!" || ( echo NOK & echo Exiting... & goto :quit )
	echo OK
)
set "cryptoState=" & set "adbCmd="
::
echo(
set /a step+=1
<nul set /p="!step!. Getting current user ID... "
for /f %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "settings get secure userID"') do set "userID=%%a"
:: If the value is 10000 or higher, the user is a guest.
if "!userID!" geq "10000" (
	echo NOK
	echo(
	echo The logged in Android user is a GUEST user, means he/she hasn't a persistent
	echo storage space within /data/media directory this because upon logging out their
	echo user-data typically gets removed from the device
	echo(
	timeout /t 10 > nul
	echo( & echo Exiting...
	goto :quit
)
echo OK
::
echo(
set /a step+=1
<nul set /p="!step! Getting name and disk-space used by each subfolder of /data/media/<USER-ID>... "
::
set /a cntSharedFolders=0
set "adbCmd=find /data/media/!userID! -type d"
if !adbRunsAsRoot! equ 0 (
	call :add_su_to_adb_cmd "adbCmd"
)
for /f %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "!adbCmd!"') do (
	set "directoryPath=%%a"
	for %%a in ("%directoryPath%") do ( set "directory=%%~dpa" )
 	for /f "skip=1 tokens=3 delims= " %%s in ('"!ADB_CLIENT!" -s !deviceId! shell "df /!directoryPath!"') do (
		set "spaceUsedKB=%%s" & set "strLength=0"
		call :str_length "spaceUsedKB" "strLength"
		if !strLength! geq 4 (
			set "spaceUsedMB=!spaceUsedKB:~0,-3!"
		) else (
			set "spaceUsedMB=1"
		)
	)
	set /a cntSharedFolders+=1
	set "sharedFolders"!cntSharedFolders!"=!directory!!delimiter!!spaceUsedMB!"
)
if !cntSharedFolders! equ 0 (
	echo NOK
	echo( & echo Exiting...
	goto :quit
)
echo OK
set "adbCmd=" & set "spaceUsedKB=" & set "strLength="
::
echo(
set /a step+=1
<nul set /p="!step!. Creating backup folder on Windows computer... "
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /value ^| find "="') do set "dateTime=%%i"
set year=%dateTime:~0,4%
set month=%dateTime:~4,2%
set day=%dateTime:~6,2%
set "backupFolder=!backupFolderBase!\backup\%year%-%month%-%day%"
cmd /C mkdir "!backupFolder!"
if not exist "!backupFolder!" (
	echo NOK
	echo( & echo Exiting...
	goto :quit
)
echo OK
set "dateTime=" & set "year=" & set "month=" & set "day="
timeout /T 3 > nul
cls
echo(
echo Please select what user-data to dump:
echo(
for /L %%i in (1,1,!cntSharedFolders!) do (
	for /f "tokens=1 delims=!delimiter!" %%a in (!sharedFolders"%i%"!) do set "directory=%%a"
	echo %indent% %%i. !directory!
)
set /a cntItems=!cntSharedFolders! & set /a cntItems+=1
echo %indent% !cntItems!. All the above
echo %indent% 0. Exit
echo(
:input
set /p choice="Enter your choice (0-!cntItems!): "
:: Check if the input is a number
for /L %%i in (0,1,!cntItems!) do (
    if "%choice%"=="%%i" ( goto :valid_input )
)
echo Invalid choice. Please enter a number between 0 and !cntItems!.
goto :input
:valid_input
if "%choice%"=="0" ( echo( & echo Exiting... & goto :quit )
if not "%choice%"=="!cntItems!" (
	for /L %%i in (1,1,!cntSharedFolders!) do (
		if "%choice%"=="%i%" (
			for /f "tokens=1,2 delims=!delimiter!" %%a in (!sharedFolders"%i%"!) do (
				set "directory=%%a"
				set "neededBackupSpaceMB=%%b"
			)
			set "dumpPath=/data/media/!userID!/!directory!"
			break
		)
	)
) else (
	set /a dumpAll=1
	set "dumpPath=/data/media/!userID!"
	for /f "skip=1 tokens=3 delims= " %%s in ('"!ADB_CLIENT!" -s !deviceId! shell "df /!dumpPath!"') do (
		set "neededBackupSpaceKB=%%s" & set "strLength=0"
		call :str_length "neededBackupSpaceKB" "strLength"
		if !strLength! geq 4 (
			set "neededBackupSpaceMB=!spaceUsedKB:~0,-3!"
		) else (
			set "neededBackupSpaceMB=1"
		)
	)
)
set "neededBackupSpaceKB=" & set "strLength=" & set "directory=" & set "choice="
timeout /T 3 > nul
cls
echo(
echo Processing...
::
echo(
set /a step=1
<nul set /p="!step!. Querying free storage space in !backupDir! folder on Windows computer... "
::
for /f "tokens=2 delims= " %%a in ('dir "!backupDir!" /a') do (	set "availSpaceB=%%a" )
set "availSpaceB=!availSpaceB:,=!"
set "strLength=0"
call :str_length "availSpaceB" "strLength"
if "!strLength!" geq 4 (
	set "availSpaceKB=!availSpaceB:~0,-3!"
	set "strLength=0"
	call :str_length "availSpaceKB" "strLength"
	if "!strLength!" geq 4 (
		set "availSpaceMB=!availSpaceKB:~0,-3!"
	) else (
		set "availSpaceMB=1"
 	)
) else (
	set "availSpaceMB=0"
)
if !neededBackupSpaceMB! gtn !availSpaceMB! (
	echo NOK
	echo( & echo Exiting...
	goto :quit
)
echo OK
set "availSpaceB=" & set "availSpaceKB=" & set "strLength="
::
set /a step+=1
::
echo(
echo Do NOT unplug the USB-cable!!
<nul set /p="!step!. Transferring !dumpPath! to !backupDir! folder on Windows computer... "
::
if !dumpAll! equ 1 (
:: Running adb pull against /data/media/<USER_ID> in one go is generally not recommended.
:: The /data/media/<USER_ID> directory often contains a significant amount of data, including photos,
:: videos, and other media files. Trying to pull all of this data at once can be time-consuming and
:: may lead to errors or interruptions.
	for /L %%i in (1,1,!cntSharedFolders!) do (
		for /f "tokens=1,2 delims=!delimiter!" %%a in (!sharedFolders"%i%"!) do set "directory=%%a"
		set "dumpPath=!dumpPath!/!directory!"
		call :dump_directory "!dumpPath!"
	)
) else (
	call :dump_directory "!dumpPath!"
)
echo OK
echo(
timeout /t 5 > nul
::
cls
if !adbRunsAsRoot! equ 1 (
"!ADB_CLIENT!"-s !deviceId! unroot > nul 2>&1
:: notify user
echo !cntFilesTransferred! files got stored in !backupFolder!, !cntFilesnotTransferred! files failed to get stored.
:quit
echo Press any key to continue...
pause > nul
endlocal & popd & exit /B
::
:show_copyright_license_screen
echo(
echo  Copyright (c) 2024 xXx yYy ^< wejotef@gmail.com ^>
echo(
echo  Redistribution and use in source and binary forms, with or without
echo  modification, are permitted provided that the following conditions are met:
echo(
echo    1. Redistributions of source code must retain the above copyright notice,
echo       this list of conditions and the following disclaimer.
echo(
echo    2. Redistributions in binary form must reproduce the above copyright
echo       notice, this list of conditions and the following disclaimer in the
echo       documentation and/or other materials provided with the distribution.
echo(
echo    3. Neither the name of the copyright holder nor the names of its
echo       contributors may be used to endorse or promote products derived from
echo       this software without specific prior written permission.
echo(
echo  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
echo  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT not LIMITED TO, THE
echo  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
echo  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
echo  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
echo  CONSEQUENTIAL DAMAGES (INCLUDING, BUT not LIMITED TO, PROCUREMENT OF
echo  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
echo  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
echo  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
echo  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
echo  POSSIBILITY OF SUCH DAMAGE.
echo(
echo(
choice /M "Accept" /C "YN"
if %errorlevel% equ 2 (
	echo(
	echo Exiting...
	echo(
	set %1=1
)
goto :EOF
::
:show_purpose_prequistes_screen
cls
echo(
echo This script attempts to fetch from non-feature phones (which generally
echo do not support ADB commands) during Android's operation (AKA "online")
echo user-selectable shared data tied to current user, to a USB-connected
echo Windows PC - where it doesn't matter Android is booted into normal or
echo recovery mode - if and only if the following pre-requisites are met:
echo(
echo %indent%1. Windows OS's version must be 11 or later
echo %indent%2. Android's version must be 10 or higher
echo %indent%3. An ADB connection with device is successfully established
echo %indent%4. ADB daemon must can run as root and/or Android must be got
echo %indent%   rooted (e.g. via KernelSU) - what allows full root access
echo %indent%5. Device's battery charge level must be at least 60%%
echo(
echo notice: If FBE is active, the files get decrypted automatically!
echo(
echo Important:
echo If multiple devices are connected, the script will only process the
echo first one encountered.
echo(
choice /M "Proceed" /C "YN"
if %errorlevel% equ 2 (
	echo(
	echo Exiting...
	echo(
	set %1=1
)
goto :EOF
::
:add_su_to_adb_cmd
setlocal
set "cmd=%~1"
:: -f -> Starts a shell quickly by skipping reading the initialization files (~/.bashrc, ~/.bash_profile, etc.).
:: It's useful for non-interactive shell sessions and executing single commands without loading the full shell environment.
set 'cmd='!SU_CMD!' root -f -c "source /system/etc/profile;!cmd!"'
endlocal & set %1=%cmd%
goto :EOF
::
:right_trim
setlocal
set "string=%~1"
:trim_loop
if "!string:~-1!"==" " set "string=!string:~0,-1!" & goto :trim_loop
endlocal & set "%1=%string%"
goto :EOF
::
:left_trim
setlocal
set "string=%~1"
set trimmedString=%string:* =%
endlocal & set "%1=%trimmedString%"
goto :EOF
::
:str_length
setlocal
set "string=%~1"
set /A length=0
:strlen_loop
if not "!string:~%length%,1!"=="" ( set /a length+=1 & goto :strlen_loop )
endlocal & set "%2=%length%"
goto :EOF
::
:dump_directory
setlocal
set "dirToDump=%~1"
set "backupLocation=!backupFolder\!dirToDump!"
cmd /C mkdir "!backupLocation!"
set "adbShellCommand=ls -l -R -A /!dirToDump!"
if !adbClientGotRooted! equ 0 (	call :add_su_to_adb_cmd "!adbShellCommand!" )
for /f "skip=1 tokens=9 delims= " %%a in ('"!ADB_CLIENT!" -s !deviceId! shell "!adbShellCommand!"') do (
	set "dumpFilePath=%%a"
	set "dumpFileName=%~nX%dumpFilePath%
 	set "dumpFile=!androidTmpStorage!/!dumpFileName!"
	if !fbeEnabled! equ 1 (
		set "adbShellCommand=cat !dumpFilePath! > !dumpFile!"
		if !adbClientGotRooted! equ 0 (	call :wrap_adb_shell_cmd "!adbShellCommand!" )
		"!ADB_CLIENT!" -s !deviceId! shell "!adbShellCommand!"
        	"!ADB_CLIENT!" -s !deviceId! pull "!dumpFile!" "!backupLocation!" > nul && ( set /a cntFilesTransferred+=1 ) || ( set /a cntFilesnotTransferred+=1 )
		"!ADB_CLIENT!" -s !deviceId! shell "rm -f !dumpFile!"
	) else (
       		"!ADB_CLIENT!" -s !deviceId! pull "!dumpFilePath!" "!backupLocation!" > nul && ( set /a cntFilesTransferred+=1 ) || ( set /a cntFilesnotTransferred+=1 )
	)
	title !this! [OK: !cntFilesTransferred! NOK: !cntFilesnotTransferred!]
)
endlocal
goto :EOF
::
