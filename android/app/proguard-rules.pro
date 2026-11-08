# libadb-android + BouncyCastle + Conscrypt (pemasangan app Wear OS lewat
# wireless debugging) memakai refleksi / provider JCA, jadi jangan di-shrink.
-keep class io.github.muntashirakon.adb.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class org.conscrypt.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn javax.naming.**
-dontwarn org.openjsse.**
