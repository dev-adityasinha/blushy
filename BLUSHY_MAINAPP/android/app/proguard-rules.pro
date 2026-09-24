# R8 / ProGuard keep rules for the release build.
#
# R8 is enabled in build.gradle.kts (isMinifyEnabled + isShrinkResources) to
# answer Play Console's "improve performance with R8 optimization" advice: it
# shrinks and optimizes the app, cutting size and startup cost. Shrinking is
# only safe when the classes reached by reflection or JNI are kept, so the
# rules below protect Flutter's own embedding and the plugins this app ships.
# Most plugins also bundle their own consumer rules inside their AARs; these
# are the extra guards on top of Flutter's default proguard file.

# --- Flutter engine / embedding (reached from native via reflection) ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Play Core (Flutter's deferred-components stubs reference it even when
#     the app has no dynamic feature modules) ---
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# --- Google Sign-In / Google APIs ---
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Kotlin coroutines / metadata (record, just_audio, others use them) ---
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**
-keep class kotlin.Metadata { *; }

# --- Native methods and enums (generic safety for JNI + valueOf reflection) ---
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- Parcelable / Serializable (plugin data classes crossing the platform
#     channel) ---
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- Keep annotations and signatures so kept classes stay usable ---
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
