# R8 keep rules for the release build.
#
# Everything here is reached by reflection or JNI, which R8 cannot see. The
# failure mode is a release-only crash that never reproduces in debug, so
# prefer keeping too much over debugging a stripped class in the wild.

# --- Flutter engine -------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- PDFBox (file-backed text extraction) ---------------------------------
# Loads fonts and glyph tables by name at runtime.
-keep class com.tom_roush.pdfbox.** { *; }
-keep class com.tom_roush.fontbox.** { *; }
-dontwarn com.tom_roush.**
-dontwarn org.apache.**
-dontwarn javax.**

# --- SQLite / drift -------------------------------------------------------
-keep class io.requery.android.database.** { *; }
-dontwarn io.requery.**

# --- Firebase / FCM -------------------------------------------------------
# Messaging instantiates services declared in the manifest.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- RevenueCat -----------------------------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# --- Play Billing ---------------------------------------------------------
-keep class com.android.billingclient.** { *; }

# --- Local notifications --------------------------------------------------
# Scheduled notifications are restored by a broadcast receiver after reboot.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Gson-backed notification payloads are deserialised by field name.
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory

# --- Kotlin coroutines ----------------------------------------------------
-dontwarn kotlinx.coroutines.**

# Keep enough of the stack trace to make Play Console reports readable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
