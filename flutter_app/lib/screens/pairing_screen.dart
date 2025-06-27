import 'package:flutter/material.dart';
import '../services/device_pairing_service.dart';
import '../widgets/custom_scaffold.dart';
import 'qr_scanner_screen.dart';

class PairingScreen extends StatefulWidget {
  @override
  _PairingScreenState createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  Map<String, dynamic>? pairedDevice;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPairedDevice();
  }

  Future<void> _loadPairedDevice() async {
    setState(() {
      isLoading = true;
    });

    try {
      final device = await DevicePairingService.getPairedDevice();
      setState(() {
        pairedDevice = device;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        pairedDevice = null;
        isLoading = false;
      });
    }
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRScannerScreen()),
    );

    if (result == true) {
      // Refresh the paired device info
      await _loadPairedDevice();
    }
  }

  Future<void> _unpairDevice() async {
    if (pairedDevice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unpair Device'),
        content: Text('Are you sure you want to unpair this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unpair'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final deviceId = pairedDevice!['deviceId'] as String;
        await DevicePairingService.unpairDevice(deviceId);
        await _loadPairedDevice();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device unpaired successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unpairing device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Device Pairing',
      customAppBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Device Pairing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              pairedDevice != null ? Icons.check_circle : Icons.device_unknown,
                              size: 64,
                              color: pairedDevice != null ? Colors.green : Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              pairedDevice != null ? 'Device Paired' : 'No Device Paired',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: pairedDevice != null ? Colors.green : Colors.grey[700],
                              ),
                            ),
                            if (pairedDevice != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'Device ID: ${pairedDevice!['deviceId']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'User ID: ${pairedDevice!['user_id']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    // Action Buttons
                    if (pairedDevice == null) ...[
                      ElevatedButton.icon(
                        onPressed: _scanQRCode,
                        icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                        label: Text(
                          'Scan QR Code',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _scanQRCode,
                        icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                        label: Text(
                          'Scan New QR Code',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _unpairDevice,
                        icon: Icon(Icons.link_off, color: Colors.red),
                        label: Text(
                          'Unpair Device',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 24),
                    
                    // Instructions
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How to Pair:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1. Make sure your ESP32 device is powered on\n'
                              '2. The device should display a QR code\n'
                              '3. Tap "Scan QR Code" and point your camera at the QR code\n'
                              '4. The device will be automatically paired to your account',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 