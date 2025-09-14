import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hsas_desktop/data/models/app_settings_model.dart';
import 'package:hsas_desktop/data/models/desktop_model.dart';
import 'package:hsas_desktop/data/models/drawing_point_model.dart';
import 'package:hsas_desktop/data/models/folder_portal_model.dart';
import 'package:hsas_desktop/data/models/icon_model.dart';
import 'package:hsas_desktop/data/models/timer_model.dart';
import 'package:hsas_desktop/data/services/persistence_service.dart';
import 'package:hsas_desktop/data/services/timer_service.dart';
import 'package:uuid/uuid.dart';
import 'package:hsas_desktop/data/services/icon_service.dart'; // 导入我们新的服务

class AppProvider extends ChangeNotifier {
  final PersistenceService _persistenceService = PersistenceService();
  final TimerService _timerService = TimerService();
  final Uuid _uuid = const Uuid();

  final IconService _iconService = IconService(); // 使用新的服务
  final Map<String, ImageProvider> _iconCache = {};

  List<DesktopModel> _desktops = [];
  int _activeDesktopIndex = 0;
  List<ScheduledSwitch> _schedules = [];
  AppSettingsModel _appSettings = AppSettingsModel();

  // New state for drawing mode
  String? drawingDesktopId;
  bool get isDrawingMode => drawingDesktopId != null;

  List<DesktopModel> get desktops => _desktops;
  int get activeDesktopIndex => _activeDesktopIndex;
  DesktopModel get activeDesktop => _desktops[_activeDesktopIndex];
  List<ScheduledSwitch> get schedules => _schedules;
  AppSettingsModel get appSettings => _appSettings;

  AppProvider() {
    loadState();
  }

  Future<void> loadState() async {
    _desktops = await _persistenceService.loadDesktops();
    _schedules = await _persistenceService.loadSchedules();
    _appSettings = await _persistenceService.loadAppSettings();
    if (_desktops.isEmpty) {
      _createDefaultDesktops();
    }
    _startTimerService();
    notifyListeners();
  }

  Future<void> saveState() async {
    await _persistenceService.saveDesktops(_desktops);
    await _persistenceService.saveSchedules(_schedules);
    await _persistenceService.saveAppSettings(_appSettings);
  }

  void _startTimerService() {
    _timerService.start(_schedules, (desktopId) {
      final index = _desktops.indexWhere((d) => d.id == desktopId);
      if (index != -1) {
        changeDesktop(index);
      }
    });
  }

  void _createDefaultDesktops() {
    _desktops = [
      DesktopModel(id: _uuid.v4(), name: '学习'),
      DesktopModel(id: _uuid.v4(), name: '娱乐'),
      DesktopModel(id: _uuid.v4(), name: '项目'),
    ];
  }

  void changeDesktop(int index) {
    if (index >= 0 && index < _desktops.length) {
      _activeDesktopIndex = index;
      notifyListeners();
    }
  }

  // --- Icon and Portal Management ---
  Future<ImageProvider?> getIconProvider(String path, {bool isSmall = false}) async {
    final cacheKey = '$path-${isSmall ? 'small' : 'large'}';
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey];
    }

    try {
      final provider = await _iconService.getFileIcon(path, isSmall: isSmall);
      if (provider != null) {
        _iconCache[cacheKey] = provider;
        return provider;
      }
    } catch (e) {
      print("无法获取图标 '$path': $e");
    }
    return null;
  }

  void addIconToCurrentDesktop(String path, String name, IconType type, Offset position) {
    final newIcon = IconModel(
      id: _uuid.v4(),
      name: name,
      path: path,
      position: position,
      type: type,
    );
    activeDesktop.icons.add(newIcon);
    notifyListeners();
    saveState();
  }

  Future<void> addPortalToCurrentDesktop(Offset position) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final newPortal = FolderPortalModel(
        id: _uuid.v4(),
        path: selectedDirectory,
        position: position,
      );
      activeDesktop.portals.add(newPortal);
      notifyListeners();
      saveState();
    }
  }

  void updateIconPosition(String iconId, Offset newPosition) {
    try {
      final icon = activeDesktop.icons.firstWhere((i) => i.id == iconId);
      icon.position = newPosition;
      notifyListeners();
      saveState();
    } catch (e) {
      print("Icon not found: $iconId");
    }
  }

  void updatePortalPosition(String portalId, Offset newPosition) {
    try {
      final portal = activeDesktop.portals.firstWhere((p) => p.id == portalId);
      portal.position = newPosition;
      notifyListeners();
      saveState();
    } catch (e) {
      print("Portal not found: $portalId");
    }
  }

  void updatePortalSize(String portalId, Size newSize) {
    try {
      final portal = activeDesktop.portals.firstWhere((p) => p.id == portalId);
      portal.size = newSize;
      notifyListeners();
      saveState();
    } catch (e) {
      print("Portal not found: $portalId");
    }
  }

  void updatePortalSortType(String portalId, SortType sortType) {
    try {
      final portal = activeDesktop.portals.firstWhere((p) => p.id == portalId);
      portal.sortType = sortType;
      notifyListeners();
      saveState();
    } catch (e) {
      print("Portal not found: $portalId");
    }
  }

  void updatePortalClickBehavior(String portalId, ClickBehavior behavior) {
    try {
      final portal = activeDesktop.portals.firstWhere((p) => p.id == portalId);
      portal.clickBehavior = behavior;
      notifyListeners();
      saveState();
    } catch (e) {
      print("Portal not found: $portalId");
    }
  }

  // --- Drawing Management ---
  void enterDrawingMode(String desktopId) {
    drawingDesktopId = desktopId;
    notifyListeners();
  }

  void exitDrawingModeAndSaveChanges(String desktopId, List<DrawingPath> newPaths) {
    final index = _desktops.indexWhere((d) => d.id == desktopId);
    if (index != -1) {
      _desktops[index].drawingPaths = newPaths;
    }
    drawingDesktopId = null;
    notifyListeners();
    saveState();
  }

  void exitDrawingModeWithoutSaving() {
    drawingDesktopId = null;
    notifyListeners();
  }

  // --- Desktop and Settings Management ---
  void addNewDesktop(String name) {
    _desktops.add(DesktopModel(id: _uuid.v4(), name: name));
    notifyListeners();
    saveState();
  }

  void deleteDesktop(String id) {
    if (_desktops.length <= 1) return;
    _desktops.removeWhere((d) => d.id == id);
    if (_activeDesktopIndex >= _desktops.length) {
      _activeDesktopIndex = _desktops.length - 1;
    }
    notifyListeners();
    saveState();
  }

  void updateDesktopSettings(String id, DesktopSettingsModel newSettings) {
    final index = _desktops.indexWhere((d) => d.id == id);
    if (index != -1) {
      _desktops[index].settings = newSettings;
      notifyListeners();
      saveState();
    }
  }

  Future<void> updateDesktopWallpaper(String id) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final index = _desktops.indexWhere((d) => d.id == id);
      if (index != -1) {
        _desktops[index].wallpaperPath = result.files.single.path;
        notifyListeners();
        saveState();
      }
    }
  }

  // --- Global App Settings ---
  void updateIconSizeScale(double newScale) {
    _appSettings.iconSizeScale = newScale;
    notifyListeners();
    saveState();
  }

  // --- Timer Schedule Management ---
  void addSchedule(ScheduledSwitch schedule) {
    _schedules.add(schedule);
    _timerService.updateSchedules(_schedules);
    notifyListeners();
    saveState();
  }

  void deleteSchedule(String id) {
    _schedules.removeWhere((s) => s.id == id);
    _timerService.updateSchedules(_schedules);
    notifyListeners();
    saveState();
  }

  @override
  void dispose() {
    _timerService.dispose();
    super.dispose();
  }
}