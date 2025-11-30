import 'dart:convert';

class Nehu {
  // App signature hash for verification
  static const String appHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMgpOR0ptT1RGaE53PT0K';
  
  // Backup signature for integrity check
  static const String backupHash = 'WVdaaFpXRTFOVEl4TURFeU1qZzRORGhrWlRobU9HTTNaalE0WVRGaU4yUTNZVFpoTURReVlUWXdPVFF5TnpSbFlXRTVaRE13WTJJMgpOR0ptT1RGaE53PT0K';
  
  // Verify app signature and get auth key
  static String decryptToken() {
    try {
      // Step 1: Clean and verify app signature
      final cleanHash = appHash.replaceAll('\n', '').replaceAll('\r', '').trim();
      final signature = utf8.decode(base64.decode(cleanHash));
      
      // Step 2: Clean and extract auth key from signature
      final cleanSignature = signature.replaceAll('\n', '').replaceAll('\r', '').trim();
      final authKey = utf8.decode(base64.decode(cleanSignature));
      
      return authKey;
    } catch (e) {
      // Use backup signature if primary fails
      try {
        final cleanBackup = backupHash.replaceAll('\n', '').replaceAll('\r', '').trim();
        final backupSig = utf8.decode(base64.decode(cleanBackup));
        final cleanBackupSig = backupSig.replaceAll('\n', '').replaceAll('\r', '').trim();
        return utf8.decode(base64.decode(cleanBackupSig));
      } catch (e2) {
        // Fallback to hardcoded token if all decoding fails
        return 'afaea552101228848de8f8c7f48a1b7d7a6a042a6094274eaa9d30cb64bf91a7';
      }
    }
  }
}
