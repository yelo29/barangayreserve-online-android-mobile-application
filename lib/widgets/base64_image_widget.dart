import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/base64_image_service.dart';
import '../utils/debug_logger.dart';

class Base64ImageWidget extends StatelessWidget {
  final String? base64Data;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const Base64ImageWidget({
    super.key,
    required this.base64Data,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (base64Data == null || base64Data!.isEmpty) {
      return placeholder ?? _buildPlaceholder();
    }
    // Extract base64 from stored data (handles JSON-wrapped and plain base64)
    final String? pureBase64 = Base64ImageService.extractBase64(base64Data);
    if (pureBase64 == null) {
      return errorWidget ?? _buildErrorWidget();
    }

    try {
      final Uint8List bytes = base64Decode(pureBase64);

      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            DebugLogger.error('Error rendering base64 image: $error');
            return errorWidget ?? _buildErrorWidget();
          },
        ),
      );
    } catch (e) {
      DebugLogger.error('Error displaying base64 image', error: e);
      return errorWidget ?? _buildErrorWidget();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: borderRadius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: borderRadius,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 40,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to Load',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget for displaying receipt images
class ReceiptImageWidget extends StatelessWidget {
  final String? receiptData;
  final double? width;
  final double? height;

  const ReceiptImageWidget({
    super.key,
    required this.receiptData,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Base64ImageWidget(
      base64Data: receiptData,
      width: width,
      height: height,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.circular(8),
      placeholder: Container(
        width: width,
        height: height ?? 120,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt,
              size: 32,
              color: Colors.blue.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              'No Receipt',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for displaying verification photos
class VerificationPhotoWidget extends StatelessWidget {
  final String? photoData;
  final String type; // 'profile' or 'id'
  final double? width;
  final double? height;

  const VerificationPhotoWidget({
    Key? key,
    required this.photoData,
    required this.type,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Base64ImageWidget(
      base64Data: photoData,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      placeholder: Container(
        width: width,
        height: height ?? 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'profile' ? Icons.person : Icons.badge,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              type == 'profile' ? 'No Profile Photo' : 'No ID Photo',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for displaying facility images
class DocumentImageWidget extends StatelessWidget {
  final String? imageData;
  final double? width;
  final double? height;

  const DocumentImageWidget({
    super.key,
    required this.imageData,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Base64ImageWidget(
      base64Data: imageData,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      placeholder: Container(
        width: width,
        height: height ?? 200,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 48,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No Facility Image',
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
