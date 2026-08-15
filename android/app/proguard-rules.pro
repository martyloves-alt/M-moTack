# Regles R8/ProGuard pour flutter_local_notifications.
#
# Sans elles, la build release echoue a l'execution avec :
#   PlatformException(error, Missing type parameter., null,
#   java.lang.RuntimeException: Missing type parameter.)
# levee dans saveScheduledNotification (via zonedSchedule) et dans
# loadScheduledNotifications (via pendingNotificationRequests).
#
# Cause : le plugin persiste les notifications programmees avec Gson, en
# s'appuyant sur des TypeToken anonymes du genre
#   new TypeToken<ArrayList<NotificationDetails>>() {}
# Gson lit le type generique reel dans l'attribut Signature de la classe.
# R8 supprime cet attribut par defaut, Gson ne retrouve plus le parametre de
# type, et leve « Missing type parameter. ».
#
# Symptome observe : les notifications immediates fonctionnent (aucune
# serialisation), les rappels programmes non, et pendingNotificationRequests()
# renvoie 0 puisque la lecture echoue elle aussi.

# --- Attributs necessaires a Gson ---
# Signature est LA regle indispensable : c'est elle qui conserve les types
# generiques. Les autres evitent des echecs voisins sur les adaptateurs.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# --- Gson ---
-dontwarn sun.misc.**

# Les sous-classes anonymes de TypeToken portent le type generique a preserver.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Les champs annotes @SerializedName peuvent etre obfusques, mais doivent
# survivre au shrinking : ils ne sont jamais references depuis le code.
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- flutter_local_notifications ---
# Les classes du plugin sont (de)serialisees par reflexion : ni leurs noms ni
# leurs champs ne doivent etre modifies.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# RuntimeTypeAdapterFactory resout les sous-types a partir de leur nom.
-keep class com.dexterous.flutterlocalnotifications.RuntimeTypeAdapterFactory { *; }
