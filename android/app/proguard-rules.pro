# The hosted google_mlkit_text_recognition plugin references every
# per-script recognizer, but the app bundles only the Japanese model
# (plus built-in Latin) via the Gradle dependency in build.gradle.
# The other script branches are unreachable at runtime -- the app only
# ever constructs the Japanese recognizer -- so tell R8 not to fail on
# their absence.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**
