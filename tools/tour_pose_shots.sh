#!/bin/zsh
U=9D4D2C8D-0061-4086-ABED-DEE6478B688B
cd ~/Documents/GreyInvasionPinball
mkdir -p build/poses
xcrun simctl spawn $U defaults write com.aarontilley.pinballlab cameraMode topDown
for p in "$@"; do
  xcrun simctl terminate $U com.aarontilley.pinballlab 2>/dev/null
  (xcrun simctl launch --console-pty $U com.aarontilley.pinballlab -playlab grandtour -tourCleanShot -tourPose $p > build/poses/$p.log 2>&1 &)
  sleep 6
  xcrun simctl io $U screenshot build/poses/$p.png >/dev/null 2>&1
  grep -a -m1 TOURPOSE build/poses/$p.log; grep -a TOURMAP build/poses/$p.log | tail -1
done
xcrun simctl terminate $U com.aarontilley.pinballlab 2>/dev/null
xcrun simctl spawn $U defaults write com.aarontilley.pinballlab cameraMode flying
