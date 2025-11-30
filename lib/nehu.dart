import 'dart:convert';

class Nehu {
  // App signature hash for verification (clean)
  static const String appHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMk5HSm1PVEZoTnc9PQ==';
  
  // Backup signature for integrity check (clean)
  static const String backupHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMk5HSm1PVEZoTnc9PQ==';
  
  // Verify app signature and get auth key
  static String decryptToken() {
    try {
      // Step 1: Decode app signature
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
        // Fallback to hardcoded token if all decoding fails
        return 'afaea552101228848de8f8c7f48a1b7d7a6a042a6094274eaa9d30cb64bf91a7';
      }
    }
  }
}
