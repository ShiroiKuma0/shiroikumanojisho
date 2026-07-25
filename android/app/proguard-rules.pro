# The hosted google_mlkit_text_recognition plugin references every
# per-script recognizer, but the app bundles only the Japanese model
# (plus built-in Latin) via the Gradle dependency in build.gradle.
# The other script branches are unreachable at runtime -- the app only
# ever constructs the Japanese recognizer -- so tell R8 not to fail on
# their absence.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**

# R8 full mode (the only mode in AGP 9; the old AGP 7 build ran compat
# mode) strips Room's generated *_Impl database classes, which Room
# loads reflectively via Class.forName(name + "_Impl"). androidx.work's
# WorkDatabase was the first casualty: the process died in
# InitializationProvider before Flutter even started (2026-07-25,
# 1.4.0+27 on the Palma). Keep every RoomDatabase subclass by name.
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# libvlcjni.so resolves Java classes by name from JNI_OnLoad
# (FindClass on org.videolan.libvlc.interfaces.IMedia$Track failed as
# UnsatisfiedLinkError on 1.4.0+31 -- player dead). JNI lookups are
# invisible to R8; keep the libVLC Java surface intact by name.
-keep class org.videolan.libvlc.** { *; }
