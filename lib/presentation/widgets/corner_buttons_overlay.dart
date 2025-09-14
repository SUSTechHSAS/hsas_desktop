import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hsas_desktop/data/services/system_service.dart';
import 'package:hsas_desktop/presentation/providers/app_provider.dart';
import 'package:hsas_desktop/presentation/screens/settings_screen.dart';
import 'package:hsas_desktop/presentation/widgets/all_apps_dialog.dart';
import 'package:hsas_desktop/utils/app_constants.dart';

class CornerButtonsOverlay extends StatelessWidget {
  final SystemService _systemService = SystemService();

  CornerButtonsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to AppProvider to get active desktop settings
    final settings = context.watch<AppProvider>().activeDesktop.settings;

    return Stack(
      children: [
        // Left Top: Shutdown
        Visibility(
          visible: settings.showShutdownButton,
          child: Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.power_settings_new, color: Colors.white),
              iconSize: AppConstants.cornerButtonSize,
              onPressed: () => _systemService.shutdown(context),
              tooltip: '关机',
            ),
          ),
        ),
        // Right Top: Settings
        Visibility(
          visible: settings.showSettingsButton,
          child: Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              iconSize: AppConstants.cornerButtonSize,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              tooltip: '设置',
            ),
          ),
        ),
        // Left Bottom: All Apps
        Visibility(
          visible: settings.showAllAppsButton,
          child: Positioned(
            bottom: 80,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.apps, color: Colors.white),
              iconSize: AppConstants.cornerButtonSize,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AllAppsDialog(),
                );
              },
              tooltip: '所有应用',
            ),
          ),
        ),
        // Right Bottom: Minimize
        Visibility(
          visible: settings.showMinimizeButton,
          child: Positioned(
            bottom: 80,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.minimize, color: Colors.white),
              iconSize: AppConstants.cornerButtonSize,
              onPressed: _systemService.toggleMinimize,
              tooltip: '最小化',
            ),
          ),
        ),
      ],
    );
  }
}