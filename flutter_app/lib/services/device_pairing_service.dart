import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevicePairingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Simulates the Python client pairing functionality
  /// Updates a pending pairing request to approved status
  static Future<bool> pairDevice(String deviceId, String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Format device ID (replace colons with dashes and uppercase)
      final formattedDeviceId = deviceId.replaceAll(':', '-').toUpperCase();
      
      final docRef = _firestore.collection("pairing_requests").doc(formattedDeviceId);
      
      // Get the current document
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('No pairing request found for device $formattedDeviceId');
      }
      
      final data = doc.data()!;
      final status = data['status'] as String? ?? '';
      
      if (status != 'pending') {
        throw Exception('Pairing request not pending (status: $status)');
      }
      
      // Update the document with approved status
      final updateData = {
        'status': 'approved',
        'uid': user.uid,
        'user_id': userId,
        'deviceId': formattedDeviceId,
        'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
      };
      
      await docRef.set(updateData, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      print('Error pairing device: $e');
      rethrow;
    }
  }

  /// Check if a device is paired with the current user
  static Future<bool> isDevicePaired(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final formattedDeviceId = deviceId.replaceAll(':', '-').toUpperCase();
      
      final doc = await _firestore
          .collection("pairing_requests")
          .doc(formattedDeviceId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['status'] == 'approved' && data['uid'] == user.uid;
    } catch (e) {
      print('Error checking device pairing: $e');
      return false;
    }
  }

  /// Get the paired device info for the current user
  static Future<Map<String, dynamic>?> getPairedDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final querySnapshot = await _firestore
          .collection("pairing_requests")
          .where('uid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) return null;
      
      return querySnapshot.docs.first.data();
    } catch (e) {
      print('Error getting paired device: $e');
      return null;
    }
  }

  /// Unpair a device
  static Future<bool> unpairDevice(String deviceId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final formattedDeviceId = deviceId.replaceAll(':', '-').toUpperCase();
      
      await _firestore
          .collection("pairing_requests")
          .doc(formattedDeviceId)
          .update({
        'status': 'unpaired',
        'unpairedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('Error unpairing device: $e');
      return false;
    }
  }
} 