import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/device_pairing_service.dart';
import '../widgets/custom_scaffold.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? controller;
  bool isScanning = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      isProcessing = true;
      isScanning = false;
    });

    try {
      // Extract device ID from QR code
      // Assuming the QR code contains just the device ID (MAC address)
      final deviceId = qrData.trim();
      
      // Generate a simple user ID (you can modify this as needed)
      final userId = "user123"; // This could be from user profile or settings
      
      // Attempt to pair the device
      final formattedDeviceId = deviceId
          .replaceAll(':', '-')
          .replaceAll('/', '') // Remove slashes
          .replaceAll(' ', '') // Remove spaces
          .toUpperCase();
      
      final success = await DevicePairingService.pairDevice(formattedDeviceId, userId);
      
      if (success) {
        // Show success message and return
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device paired successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to pair device');
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('No pairing request found')) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Pairing Request Not Found'),
            content: Text('No pairing request found for this device.\nMake sure your ESP32 is powered on and displaying a QR code.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pairing device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        isProcessing = false;
        isScanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Scan QR Code',
      customAppBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (isScanning && !isProcessing) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _processQRCode(barcode.rawValue!);
                          break;
                        }
                      }
                    }
                  },
                ),
                // Overlay
                Positioned.fill(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: QrScannerOverlayShape(
                        borderColor: Colors.red,
                        borderRadius: 10,
                        borderLength: 30,
                        borderWidth: 10,
                        cutOutSize: 300,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isProcessing)
                    Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Processing...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  else
                    Text(
                      'Point camera at the ESP32 QR code',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width * 0.1;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > cutOutSize ? borderLength : cutOutSize * 0.1;
    final _cutOutSize = cutOutSize < width ? cutOutSize : width - borderWidthSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    // Draw corners
    final topLeft = cutOutRect.topLeft;
    final topRight = cutOutRect.topRight;
    final bottomLeft = cutOutRect.bottomLeft;
    final bottomRight = cutOutRect.bottomRight;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(topLeft.dx, topLeft.dy + _borderLength)
        ..lineTo(topLeft.dx, topLeft.dy)
        ..lineTo(topLeft.dx + _borderLength, topLeft.dy),
      borderPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(topRight.dx - _borderLength, topRight.dy)
        ..lineTo(topRight.dx, topRight.dy)
        ..lineTo(topRight.dx, topRight.dy + _borderLength),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(bottomLeft.dx, bottomLeft.dy - _borderLength)
        ..lineTo(bottomLeft.dx, bottomLeft.dy)
        ..lineTo(bottomLeft.dx + _borderLength, bottomLeft.dy),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(bottomRight.dx - _borderLength, bottomRight.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy - _borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? t, double x) {
    if (t is QrScannerOverlayShape) {
      return QrScannerOverlayShape(
        borderColor: Color.lerp(t.borderColor, borderColor, x)!,
        borderWidth: lerpDouble(t.borderWidth, borderWidth, x)!,
        overlayColor: Color.lerp(t.overlayColor, overlayColor, x)!,
      );
    }
    return super.lerpFrom(t, x);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? t, double x) {
    if (t is QrScannerOverlayShape) {
      return QrScannerOverlayShape(
        borderColor: Color.lerp(borderColor, t.borderColor, x)!,
        borderWidth: lerpDouble(borderWidth, t.borderWidth, x)!,
        overlayColor: Color.lerp(overlayColor, t.overlayColor, x)!,
      );
    }
    return super.lerpTo(t, x);
  }
} 