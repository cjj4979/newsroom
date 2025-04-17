# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Rules for new Play Core libraries (feature-delivery and app-update)
# Updated to use the new package structure
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.featuredelivery.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }

# Rules for tasks (now part of the common package)
-keep class com.google.android.play.core.tasks.** { *; }

# Keep App Update related classes
-keep class com.google.android.play.appupdate.** { *; }

# Flutter Deferred Components with new Play Core libraries
-keep class io.flutter.plugins.play.core.** { *; }

# Suppress warnings for missing Play Core classes
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn com.google.android.play.core.**

# Keep your custom classes
-keep class com.kncc.newsroom.** { *; }