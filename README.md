# DataDump4Android

Welcome to DataDump4Android

It's a tool (Windows batch script) what basically uses adb pull command to fetch contents of Android's user-data as stored in /data/media directory. If on Android FBE (FBE stands for File-Based Encryption) is enabled, that's default since Android 10, this encryption gets bypassed, means the files what get dumped are decrypted.
