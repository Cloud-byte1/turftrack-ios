---
layout: default
title: fairLie Support
permalink: /support/
---

# fairLie Support

Email [support@fairlie.app](mailto:support@fairlie.app) for help.

## Frequently asked questions

### How do I pair the GolfMat or radar?

Turn on the GolfMat and open Practice in fairLie, then use the Bluetooth device controls to connect to `GolfMat`. If you have the optional Acconeer XM125 radar ESP32, turn it on and connect to `GolfMatRadar` separately. Bluetooth is used only for these two devices. Make sure Bluetooth is enabled and allow fairLie Bluetooth access when iOS asks.

### What happens if Bluetooth disconnects?

fairLie automatically tries to reconnect to the last connected device. Keep the accessory powered on and nearby. If it does not reconnect, open the Bluetooth device controls in Practice and select it again.

### What is the difference between guest mode and an account?

Guests can use Home, Practice, Progress, the swing simulator, and their profile. Guest profile data and sessions are stored only on that iPhone and are never uploaded. The Clubhouse leaderboard, feed, challenges, and events require an account. Signed-in profiles, practice sessions, posts, likes, RSVPs, and challenge progress are stored in Supabase.

### How do I erase guest data or delete an account?

Guests can erase all guest data from Settings. Signed-in golfers can choose **Delete account** in Settings; this immediately deletes the Supabase Auth user and all data they own. Account deletion cannot be undone.

### Which numbers are estimates?

Carry distance, club speed, and attack angle are estimates derived from GolfMat sensor readings. Ball speed is measured only when an optional radar reading is merged with the strike; otherwise ball speed is an estimate. Simulated values are labeled **SIMULATED**. fairLie does not report smash factor or track putting.

### How do I report a Clubhouse post?

Open the post menu and choose **Report**. You can also hide the post or block its author. Golfers can delete their own posts.
