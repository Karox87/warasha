import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(String) onBarcodeScanned;
  final String title;

  const BarcodeScannerScreen({
    super.key,
    required this.onBarcodeScanned,
    required this.title,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? cameraController;
  bool _isScanned = false;
  bool _isTorchOn = false;
  bool _isInitialized = false;
  String? _errorMessage;
  StreamSubscription<Object?>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });

      cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        returnImage: false,
      );

      // ژەختانی 500ms بۆ دەستپێکردنی کامێرا
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        await cameraController?.start();
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'هەڵە لە دەستپێکردنی کامێرا';
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || cameraController == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _initializeCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        cameraController?.stop();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    cameraController?.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() => _isScanned = true);
        
        // وەستاندنی کامێرا
        cameraController?.stop();
        
        // دەنگی سەرکەوتوو
        _showSuccessAnimation();
        
        // گەڕانەوە دوای 500ms
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            widget.onBarcodeScanned(barcode.rawValue!);
            Navigator.of(context).pop();
          }
        });
        return;
      }
    }
  }

  void _showSuccessAnimation() {
    // ئەنیمەیشنی سەرکەوتوو
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('بارکۆد سکان کرا!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _toggleTorch() async {
    try {
      setState(() => _isTorchOn = !_isTorchOn);
      await cameraController?.toggleTorch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فلاش لەم دەستگایەدا بەردەست نییە'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      await cameraController?.switchCamera();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هەڵە لە گۆڕینی کامێرا'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            cameraController?.stop();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // دوگمەی فلاش
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _isInitialized ? _toggleTorch : null,
            tooltip: 'فلاش',
          ),
          // دوگمەی گۆڕینی کامێرا
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: _isInitialized ? _switchCamera : null,
            tooltip: 'گۆڕینی کامێرا',
          ),
          // دوگمەی هەوڵدانەوە
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _initializeCamera(),
            tooltip: 'هەوڵدانەوە',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 📷 کامێرا یان هەڵە
          if (_errorMessage != null)
            _buildErrorView()
          else if (!_isInitialized)
            _buildLoadingView()
          else
            _buildCameraView(),

          // 🎯 چوارچێوەی سکانەر (هەمیشە نیشان بدە)
          if (_isInitialized && _errorMessage == null)
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  isScanning: !_isScanned,
                ),
              ),
            ),

          // 📝 ڕێنمایی
          if (_isInitialized && !_isScanned && _errorMessage == null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: _buildInstructionBox(),
            ),

          // ✅ نیشاندەری سەرکەوتوو
          if (_isScanned)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '✓ سکان کرا!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: cameraController,
      onDetect: _handleBarcode,
    );
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.green,
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              'کامێرا دەکرێتەوە...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'هەڵەیەک ڕوویدا',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'تکایە دڵنیابە لە:\n'
                '• ڕێگەپێدان بە کامێرا درووستە\n'
                '• کامێرا لەلایەن ئەپێکی تر بەکار ناهێنرێت\n'
                '• دەستگاکەت کامێرای هەیە',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'هەوڵدانەوە',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionBox() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: Colors.green,
                size: 40,
              ),
              SizedBox(height: 12),
              Text(
                'بارکۆدەکە لە ناو چوارگۆشە سەوزەکەدا بێنە',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'بە خۆکاری سکان دەکرێت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // تیپس
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'فلاش بەکاربێنە لە شوێنی تاریک',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 🎨 ڕەسمی چوارگۆشەی سکانەر بە ئەنیمەیشن
class ScannerOverlayPainter extends CustomPainter {
  final bool isScanning;
  
  ScannerOverlayPainter({required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    // پاشبنەمای تاریک
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6);

    final rectPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final cornerPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final rectWidth = size.width * 0.75;
    final rectHeight = rectWidth * 0.65;

    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: rectWidth,
      height: rectHeight,
    );

    // کێشانی پاشبنەما بە کونێک لە ناوەڕاست
    final holePath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        scanRect,
        const Radius.circular(16),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(holePath, backgroundPaint);

    // کێشانی چوارگۆشە
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      rectPaint,
    );

    // کێشانی گۆشەکان
    const cornerLength = 40.0;

    // گۆشەی سەرەوەی چەپ
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + 16),
      Offset(scanRect.left + cornerLength, scanRect.top + 16),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + 16, scanRect.top),
      Offset(scanRect.left + 16, scanRect.top + cornerLength),
      cornerPaint,
    );

    // گۆشەی سەرەوەی ڕاست
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top + 16),
      Offset(scanRect.right - cornerLength, scanRect.top + 16),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - 16, scanRect.top),
      Offset(scanRect.right - 16, scanRect.top + cornerLength),
      cornerPaint,
    );

    // گۆشەی خوارەوەی چەپ
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - 16),
      Offset(scanRect.left + cornerLength, scanRect.bottom - 16),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + 16, scanRect.bottom),
      Offset(scanRect.left + 16, scanRect.bottom - cornerLength),
      cornerPaint,
    );

    // گۆشەی خوارەوەی ڕاست
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom - 16),
      Offset(scanRect.right - cornerLength, scanRect.bottom - 16),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - 16, scanRect.bottom),
      Offset(scanRect.right - 16, scanRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) {
    return oldDelegate.isScanning != isScanning;
  }
}