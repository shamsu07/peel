# Streaming formats are excluded from the build (see build.gradle.kts);
# plugins still mention them, so don't fail on the missing classes.
-dontwarn androidx.media3.exoplayer.dash.**
-dontwarn androidx.media3.exoplayer.hls.**
-dontwarn androidx.media3.exoplayer.rtsp.**
-dontwarn androidx.media3.exoplayer.smoothstreaming.**
