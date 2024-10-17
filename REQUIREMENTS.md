# DataDump4Android

The Google USB Driver (adb.exe) is required to perform adb debugging on Windows with Google devices. For all other devices this driver is provided by the respective hardware manufacturer: go to the support section of the manufacturer's website and search for USB driver downloads for your device.
Once you've downloaded your USB driver, follow the instructions to install or upgrade the driver, based on your version of Windows and whether you're installing for the first time or upgrading an existing driver. DO NOT USE THE 15-SECONDS-ADB-INSTALLER.

USB Debugging must got enabled on Android device where to dump its user-data from.

Android device must got rooted, means the SU binary must be present in Android's filesystem. Most Android devices are not rooted by default due to security and warranty concerns. 
