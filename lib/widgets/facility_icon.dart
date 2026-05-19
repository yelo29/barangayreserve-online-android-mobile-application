import 'package:flutter/material.dart';
import 'base64_image_widget.dart';

class FacilityIcon extends StatelessWidget {
  final String iconName;
  final double size;
  final Color? color;

  const FacilityIcon({
    super.key,
    required this.iconName,
    this.size = 32.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = color ?? Theme.of(context).primaryColor;

    // Check if iconName is a base64 image (starts with data:image or is long base64 string)
    if (iconName.startsWith('data:image') || (iconName.length > 100 && !iconName.contains(' '))) {
      // It's a base64 image, display as image
      return Base64ImageWidget(
        base64Data: iconName,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(8),
      );
    }

    // Check if iconName is an emoji (contains non-ASCII characters)
    if (iconName.codeUnits.any((unit) => unit > 127)) {
      // It's an emoji, display as text
      return Text(
        iconName,
        style: TextStyle(
          fontSize: size,
          color: iconColor,
        ),
      );
    }

    // It's a Material Design icon name, map to IconData
    IconData iconData;
    switch (iconName) {
      case 'sports_basketball':
        iconData = Icons.sports_basketball;
        break;
      case 'event_seat':
        iconData = Icons.event_seat;
        break;
      case 'sports_volleyball':
        iconData = Icons.sports_volleyball;
        break;
      case 'park':
        iconData = Icons.park;
        break;
      case 'music_note':
        iconData = Icons.music_note;
        break;
      case 'art_track':
        iconData = Icons.art_track;
        break;
      case 'computer':
        iconData = Icons.computer;
        break;
      case 'wifi':
        iconData = Icons.wifi;
        break;
      default:
        // Fallback to a generic icon
        iconData = Icons.location_city;
    }

    return Icon(
      iconData,
      size: size,
      color: iconColor,
    );
  }
}
