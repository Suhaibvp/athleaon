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
      'grip':'assets/icons/feedback/icon_grip (1).png'
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
                    color: isSelected ? const Color(0xFFD32F2F) : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : _buildIconWidget(iconId, iconSize, isSelected),
      ),
    );
  }

  // Widget builder with red tint for selection
// Widget builder with red tint for selection (green for shoot_tick)
static Widget _buildIconWidget(String iconId, double iconSize, bool isSelected) {
  final iconPath = getIconPath(iconId);
  
  if (iconPath == null) {
    print('❌ Icon path not found for: $iconId - using fallback');
    return Icon(
      getFallbackIcon(iconId),
      color: isSelected 
          ? (iconId == 'shoot_tick' ? Colors.green : const Color(0xFFD32F2F))
          : Colors.white,
      size: iconSize * 0.5,
    );
  }

  // ✅ Green for shoot_tick, red for all others
  final selectedColor = iconId == 'shoot_tick' 
      ? Colors.green 
      : const Color(0xFFD32F2F);

  return ColorFiltered(
    colorFilter: isSelected
        ? ColorFilter.mode(
            selectedColor, // ✅ Green for shoot_tick, red for others
            BlendMode.modulate,
          )
        : const ColorFilter.mode(
            Colors.transparent,
            BlendMode.dst,
          ),
    child: Image.asset(
      iconPath,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Failed to load: $iconId at $iconPath');
        return Icon(
          getFallbackIcon(iconId),
          color: isSelected ? selectedColor : Colors.white,
          size: iconSize * 0.5,
        );
      },
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
