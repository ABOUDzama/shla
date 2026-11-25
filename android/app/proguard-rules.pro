# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WebRTC (voice chat)
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }

# socket.io client
-keep class io.socket.** { *; }
-keep class org.json.** { *; }

# Supabase / PostgREST serialization
-keep class io.supabase.** { *; }
-keep class com.jayway.jsonpath.** { *; }

# Model classes serialized by name
-keepattributes Signature, EnclosingMethod, InnerClasses, *Annotation*
-dontwarn org.slf4j.**
-dontwarn javax.annotation.**
