# BlackHoleEffectDemo

A focused macOS reference app for the core desktop effect:

1. Request Screen Recording permission.
2. Capture the display while excluding the demo window itself.
3. Crop the pixels directly behind the window.
4. Apply `blackHoleLens` and draw `BlackHoleParticleMorphView` above them.

Open `BlackHoleEffectDemo.xcodeproj`, select the `BlackHoleEffectDemo` scheme, and run on My Mac. macOS may require quitting and reopening the app after Screen Recording permission is granted.

The sample deliberately excludes app consumption, restore timers, settings, telemetry, multi-panel coordination, and other host-app behavior.
