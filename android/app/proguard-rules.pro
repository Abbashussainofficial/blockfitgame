# R8 rules for Block Fit's release build.
#
# Flutter and every plugin (google_mobile_ads, in_app_purchase, audioplayers,
# shared_preferences, url_launcher) ship their own consumer rules, so only
# app-specific additions belong here.

# Flutter references Play Core (deferred components) optionally. The app does
# not use it, so silence R8's "missing class" errors instead of adding the
# library.
-dontwarn com.google.android.play.core.**

# Keep line numbers so Play Console crash reports stay readable; upload the
# generated mapping.txt (build/app/outputs/mapping/release/) with each release.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# WorkManager (pulled in by the AdMob SDK) creates its Room database by
# reflection at app start. Without these, R8 strips the generated
# WorkDatabase_Impl constructor and the release build crashes on launch.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
