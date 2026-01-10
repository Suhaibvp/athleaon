import 'package:flutter/material.dart';

class ShootingFeedbackIcons {
  // Icon ID mapping to asset paths
  static String? getIconPath(String iconId) {
    final Map<String, String> iconPaths = {
      'movement': 'assets/icons/feedback/movement.png',
      'ft': 'assets/icons/feedback/ft.png',
      'cross': 'assets/icons/feedback/cross.png',
      'dry': 'assets/icons/feedback/dry.png',
      'lh': 'assets/icons/feedback/lh.png',
      'random_shoot': 'assets/icons/feedback/random_shoot.png',
      'shoot_tick': 'assets/icons/feedback/shoot_tick.png',
      'sitting': 'assets/icons/feedback/sitting.png',
      'stand': 'assets/icons/feedback/stand.png',
      'tr': 'assets/icons/feedback/tr.png',
      'talk_with_friends': 'assets/icons/feedback/talk_with_friends.png',
      'grip': 'assets/icons/feedback/icon_grip (1).png',
    };
    
    return iconPaths[iconId];
  }

  // Get fallback Material icon
  static IconData getFallbackIcon(String iconId) {
    final Map<String, IconData> fallbackIcons = {
      'movement': Icons.my_location,
      'ft': Icons.touch_app,
      'cross': Icons.close,
      'dry': Icons.flash_off,
      'lh': Icons.pan_tool,
      'random_shoot': Icons.scatter_plot,
      'shoot_tick': Icons.check_circle,
      'sitting': Icons.event_seat,
      'stand': Icons.accessibility_new,
      'tr': Icons.trending_up,
      'talk_with_friends': Icons.people_outline,
    };
    
    return fallbackIcons[iconId] ?? Icons.help_outline;
  }

  // NEW: Generate text icon from iconId
  static String getTextIcon(String iconId) {
    if (iconId.isEmpty) return '?';
    
    // Handle special cases with multiple words (use first letters)
    if (iconId.contains('_')) {
      final parts = iconId.split('_');
      if (parts.length >= 2) {
        // Take first letter of each word (max 2 letters)
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
    }
    
    // For single word or short codes, return first 1-2 characters
    if (iconId.length == 1) {
      return iconId.toUpperCase();
    } else if (iconId.length == 2) {
      return iconId.toUpperCase();
    } else {
      // For longer words, return first 2 characters
      return iconId.substring(0, 2).toUpperCase();
    }
  }

  // NEW: Get color for specific feedback types
  static Color getFeedbackColor(String iconId, bool isSelected) {
    // Special color for shoot_tick (green)
    if (iconId == 'shoot_tick') {
      return isSelected ? Colors.green : Colors.white;
    }
    
    // Special colors for specific feedback types
    final Map<String, Color> specialColors = {
      'dry': Colors.red,
      'cross': Colors.red,
      'malfunction': Colors.orange,
    };
    
    if (isSelected && specialColors.containsKey(iconId)) {
      return specialColors[iconId]!;
    }
    
    // Default: red when selected, white when not
    return isSelected ? const Color(0xFFD32F2F) : Colors.white;
  }

  // Build feedback button widget with color tint for selection
  static Widget buildFeedbackButton({
    required String iconId,
    required bool isSelected,
    required VoidCallback onPressed,
    String? label,
    double size = 42,
    double iconSize = 42,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: label != null
            ? Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: getFeedbackColor(iconId, isSelected),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : _buildIconWidget(iconId, iconSize, isSelected),
      ),
    );
  }

  // Widget builder with automatic fallback to text icon
  static Widget _buildIconWidget(String iconId, double iconSize, bool isSelected) {
    final iconPath = getIconPath(iconId);
    final selectedColor = getFeedbackColor(iconId, isSelected);
    
    // Try to load image first
    if (iconPath != null) {
      return ColorFiltered(
        colorFilter: isSelected
            ? ColorFilter.mode(selectedColor, BlendMode.modulate)
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: Image.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // If image fails, fall back to text icon
            return _buildTextIcon(iconId, iconSize, isSelected);
          },
        ),
      );
    }
    
    // No image path defined, use text icon directly
    return _buildTextIcon(iconId, iconSize, isSelected);
  }

  // NEW: Build text-based icon
// UPDATED: Build text-based icon with rounded square (like the reference image)
static Widget _buildTextIcon(String iconId, double iconSize, bool isSelected) {
  final textIcon = getTextIcon(iconId);
  final color = getFeedbackColor(iconId, isSelected);
  
  return Container(
    width: iconSize,
    height: iconSize,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(iconSize * 0.15), // Rounded corners (15% of size)
      color: isSelected 
          ? color.withOpacity(0.2) 
          : Colors.black,
      border: Border.all(
        color: color,
        width: 2,
      ),
    ),
    child: Center(
      child: Text(
        textIcon,
        style: TextStyle(
          color: color,
          fontSize: iconSize * 0.35, // Slightly smaller text
          fontWeight: FontWeight.bold,
          letterSpacing: textIcon.length > 2 ? -1 : 0,
        ),
      ),
    ),
  );
}


  // NEW: Build icon for display (smaller, for tables/reports)
// FIXED: Build icon for display with background container for ALL icons
static Widget buildDisplayIcon({
  required String iconId,
  double size = 16,
  bool isSelected = false,
}) {
  final iconPath = getIconPath(iconId);
  final color = getFeedbackColor(iconId, isSelected);
  
  // Always wrap in a container with dark background
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.15),
      color: const Color(0xFF1A1A1A), // Dark background for all icons
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    padding: EdgeInsets.all(size * 0.1), // Small padding
    child: iconPath != null
        ? Image.asset(
            iconPath,
            width: size * 0.8,
            height: size * 0.8,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to text icon WITHOUT container (already has one)
              return Center(
                child: Text(
                  getTextIcon(iconId),
                  style: TextStyle(
                    color: color,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          )
        : Center(
            child: Text(
              getTextIcon(iconId),
              style: TextStyle(
                color: color,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
  );
}

  // Build top-right app icon
  static Widget buildAppIcon({
    double size = 40,
    String iconId = 'shield',
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        'assets/images/custom_icon.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.shield,
            color: Colors.white,
            size: 24,
          );
        },
      ),
    );
  }
}
