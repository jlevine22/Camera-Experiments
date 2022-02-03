# Camera Experiments

## XPC Service

Create a plist file at `~/Library/LaunchAgents/com.username.CameraExperimentsXPC.plist` with the following contents:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
  <string>com.username.CameraExperimentsXPC</string>
  <key>Program</key>
  <string>/Path/to/product/CameraExperimentsXPC</string>
    <key>MachServices</key>
    <dict>
        <key>com.username.CameraExperimentsXPC</key>
        <true/>
    </dict>
</dict>
</plist>
```

Launch the agent:
```
> launchctl load ~/Library/LaunchAgents/com.username.CameraExperimentsXPC.plist
```

