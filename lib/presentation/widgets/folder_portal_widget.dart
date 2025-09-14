import 'dart:io';
import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hsas_desktop/data/models/desktop_model.dart';
import 'package:hsas_desktop/data/models/folder_portal_model.dart';
import 'package:hsas_desktop/data/services/system_service.dart';
import 'package:hsas_desktop/presentation/providers/app_provider.dart';

class FolderPortalWidget extends StatefulWidget {
  final FolderPortalModel portalData;

  const FolderPortalWidget({super.key, required this.portalData});

  @override
  State<FolderPortalWidget> createState() => _FolderPortalWidgetState();
}

class _FolderPortalWidgetState extends State<FolderPortalWidget> {
  final SystemService _systemService = SystemService();
  late String _currentPath;
  final List<String> _pathHistory = [];
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.portalData.path;
    _loadAndSortFiles();
  }

  @override
  void didUpdateWidget(covariant FolderPortalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部状态（如排序方式或点击方式）改变时，重新构建
    if (oldWidget.portalData.sortType != widget.portalData.sortType ||
        oldWidget.portalData.clickBehavior != widget.portalData.clickBehavior) {
      _loadAndSortFiles();
    }
  }

  Future<void> _navigateTo(String newPath) async {
    setState(() {
      _pathHistory.add(_currentPath);
      _currentPath = newPath;
    });
    await _loadAndSortFiles();
  }

  Future<void> _navigateBack() async {
    if (_pathHistory.isNotEmpty) {
      setState(() {
        _currentPath = _pathHistory.removeLast();
      });
      await _loadAndSortFiles();
    }
  }

  Future<void> _loadAndSortFiles() async {
    final dir = Directory(_currentPath);
    if (await dir.exists()) {
      List<FileSystemEntity> files = dir.listSync();
      files.sort((a, b) {
        bool aIsFolder = a is Directory;
        bool bIsFolder = b is Directory;
        if (aIsFolder != bIsFolder) return aIsFolder ? -1 : 1;
        switch (widget.portalData.sortType) {
          case SortType.nameAsc: return a.path.toLowerCase().compareTo(b.path.toLowerCase());
          case SortType.nameDesc: return b.path.toLowerCase().compareTo(a.path.toLowerCase());
          case SortType.dateAsc: return a.statSync().modified.compareTo(b.statSync().modified);
          case SortType.dateDesc: return b.statSync().modified.compareTo(a.statSync().modified);
        }
      });
      if (mounted) setState(() => _files = files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final bool canNavigateBack = _pathHistory.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.portalData.size.width,
          height: widget.portalData.size.height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (canNavigateBack)
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _navigateBack)
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      _currentPath.split(Platform.pathSeparator).last,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // --- 关键修复：更新 PopupMenuButton ---
                  PopupMenuButton<dynamic>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    tooltip: '更多选项',
                    onSelected: (value) {
                      // 根据返回值的类型，调用不同的更新方法
                      if (value is SortType) {
                        appProvider.updatePortalSortType(widget.portalData.id, value);
                      } else if (value is ClickBehavior) {
                        appProvider.updatePortalClickBehavior(widget.portalData.id, value);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(enabled: false, child: Text('排序方式')),
                      CheckedPopupMenuItem(
                        value: SortType.nameAsc,
                        checked: widget.portalData.sortType == SortType.nameAsc,
                        child: const Text('按名称 (A-Z)'),
                      ),
                      CheckedPopupMenuItem(
                        value: SortType.nameDesc,
                        checked: widget.portalData.sortType == SortType.nameDesc,
                        child: const Text('按名称 (Z-A)'),
                      ),
                      CheckedPopupMenuItem(
                        value: SortType.dateAsc,
                        checked: widget.portalData.sortType == SortType.dateAsc,
                        child: const Text('按日期 (旧→新)'),
                      ),
                      CheckedPopupMenuItem(
                        value: SortType.dateDesc,
                        checked: widget.portalData.sortType == SortType.dateDesc,
                        child: const Text('按日期 (新→旧)'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(enabled: false, child: Text('打开方式')),
                      CheckedPopupMenuItem(
                        value: ClickBehavior.singleClick,
                        checked: widget.portalData.clickBehavior == ClickBehavior.singleClick,
                        child: const Text('单击打开'),
                      ),
                      CheckedPopupMenuItem(
                        value: ClickBehavior.doubleClick,
                        checked: widget.portalData.clickBehavior == ClickBehavior.doubleClick,
                        child: const Text('双击打开'),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100, childAspectRatio: 1, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isFolder = file is Directory;
                    return GestureDetector(
                      // 这里使用的就是 portalData 自己的 clickBehavior
                      onTap: widget.portalData.clickBehavior == ClickBehavior.singleClick
                          ? () => isFolder ? _navigateTo(file.path) : _systemService.openPath(file.path, context)
                          : null,
                      onDoubleTap: widget.portalData.clickBehavior == ClickBehavior.doubleClick
                          ? () => isFolder ? _navigateTo(file.path) : _systemService.openPath(file.path, context)
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FutureBuilder<ImageProvider?>(
                            // 调用 AppProvider 的方法，isSmall: true 表示获取小图标
                            future: appProvider.getIconProvider(file.path, isSmall: true),
                            builder: (context, snapshot) {
                              // ... (这里的逻辑与 IconWidget 中的类似)
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)));
                              }
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image(image: snapshot.data!, width: 40, height: 40, fit: BoxFit.contain);
                              }
                              return Icon(isFolder ? Icons.folder : Icons.insert_drive_file, size: 40, color: Colors.white);
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            file.path.split(Platform.pathSeparator).last,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: -10,
          bottom: -10,
          child: GestureDetector(
            onPanUpdate: (details) {
              final newWidth = (widget.portalData.size.width + details.delta.dx).clamp(200.0, 800.0);
              final newHeight = (widget.portalData.size.height + details.delta.dy).clamp(150.0, 600.0);
              appProvider.updatePortalSize(widget.portalData.id, Size(newWidth, newHeight));
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeDownRight,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_full, size: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}