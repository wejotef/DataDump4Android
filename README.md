# Welcome to DataDump4Android

It's a tool (Windows batch script) what basically uses adb pull command to fetch contents of Android's user-data as stored in /data/media directory. If on Android FBE (FBE stands for File-Based Encryption) is enabled, that's default since Android 10, this encryption gets bypassed, means the files what get dumped are decrypted.

# What the script does:

The script will display a series of prompts and checks:
It will verify your Windows OS version.
Check if the ADB client is available.
Ensure an Android device is connected and in the correct mode.
Check the battery level of the Android device.
Verify the boot mode of the Android device.
Confirm that the ADB daemon can run as root.

Once all checks are complete, you will be prompted to select which user data to dump.
You can choose specific folders or select to back up all available data.

The script will display the progress of the backup process.

After the backup is complete, the script will show how many files were successfully transferred and how many failed.


# What the script does not:

If multiple devices (e.g. using a USB hub) are connected then interacting with each device individually via ADB is NOT supported: Only the first of the devices connected is focused.

