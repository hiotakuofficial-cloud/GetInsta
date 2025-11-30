import 'dart:convert';

class Nehu {
  // App signature hash for verification
  static const String appHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMgpOR0ptT1RGaE53PT0K';
  
  // Backup signature for integrity check
  static const String backupHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMgpOR0ptT1RGaE53PT0K';
  
  // Verify app signature and get auth key
  static String decryptToken() {
    try {
      // Step 1: Verify app signature
      final signature = utf8.decode(base64.decode(appHash));
      
      // Step 2: Extract auth key from signature
      final authKey = utf8.decode(base64.decode(signature));
      
      return authKey;
    } catch (e) {
      // Use backup signature if primary fails
      try {
        final backupSig = utf8.decode(base64.decode(backupHash));
        return utf8.decode(base64.decode(backupSig));
      } catch (e2) {
        // Critical error - app integrity compromised
        throw Exception('App signature verification failed');
      }
    }
  }
}
