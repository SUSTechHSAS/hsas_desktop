import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hsas_desktop/data/models/desktop_model.dart';
import 'package:hsas_desktop/data/models/folder_portal_model.dart';
import 'package:hsas_desktop/data/models/icon_model.dart';
import 'package:hsas_desktop/presentation/providers/app_provider.dart';
import 'package:hsas_desktop/presentation/widgets/folder_portal_widget.dart';
import 'package:hsas_desktop/presentation/widgets/icon_widget.dart';
import 'package:hsas_desktop/presentation/widgets/wallpaper_widget.dart';

class DesktopPage extends StatelessWidget {
  final DesktopModel desktopData;

  const DesktopPage({super.key, required this.desktopData});

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = overlay.globalToLocal(globalPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: const [
        PopupMenuItem<String>(value: 'add_file', child: Text('添加文件...')),
        PopupMenuItem<String>(value: 'add_folder', child: Text('添加文件夹...')),
        PopupMenuItem<String>(value: 'add_portal', child: Text('添加文件夹传送门...')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'clear_drawings', child: Text('清除涂鸦')),
      ],
    ).then((value) async {
      if (value == null) return;
      switch (value) {
        case 'add_file':
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null) {
            appProvider.addIconToCurrentDesktop(
              result.files.single.path!,
              result.files.single.name,
              IconType.file,
              position,
            );
          }
          break;
        case 'add_folder':
          String? directoryPath = await FilePicker.platform.getDirectoryPath();
          if (directoryPath != null) {
            appProvider.addIconToCurrentDesktop(
              directoryPath,
              directoryPath.split(Platform.pathSeparator).last,
              IconType.folder,
              position,
            );
          }
          break;
        case 'add_portal':
          appProvider.addPortalToCurrentDesktop(position);
          break;
        case 'clear_drawings':
          final desktop = appProvider.activeDesktop;
          appProvider.exitDrawingModeAndSaveChanges(desktop.id, []);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final iconSizeScale = appProvider.appSettings.iconSizeScale;

    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      // 修复 #2: 触摸屏长按
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      // 关键修复 #4: DragTarget 现在是父级，负责接收所有可拖动对象
      child: DragTarget<Object>(
        onAcceptWithDetails: (details) {
          // 这里的 details.offset 是相对于这个 DragTarget (即整个桌面) 的正确局部坐标
          final localOffset = details.offset;

          // 根据拖动的对象类型，调用正确的更新方法
          if (details.data is IconModel) {
            appProvider.updateIconPosition((details.data as IconModel).id, localOffset);
          } else if (details.data is FolderPortalModel) {
            appProvider.updatePortalPosition((details.data as FolderPortalModel).id, localOffset);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Stack(
            children: [
              // 壁纸层
              Positioned.fill(
                child: WallpaperWidget(
                  wallpaperPath: desktopData.wallpaperPath,
                  drawingPaths: desktopData.drawingPaths,
                ),
              ),
              // 图标层
              ...desktopData.icons.map((iconData) {
                return Positioned(
                  left: iconData.position.dx,
                  top: iconData.position.dy,
                  child: Draggable<IconModel>(
                    data: iconData,
                    feedback: IconWidget(iconData: iconData, clickBehavior: desktopData.settings.clickBehavior, iconSizeScale: iconSizeScale),
                    childWhenDragging: Opacity(opacity: 0.4, child: IconWidget(iconData: iconData, clickBehavior: desktopData.settings.clickBehavior, iconSizeScale: iconSizeScale)),
                    child: IconWidget(iconData: iconData, clickBehavior: desktopData.settings.clickBehavior, iconSizeScale: iconSizeScale),
                  ),
                );
              }).toList(),
              // Folder Portal 层
              ...desktopData.portals.map((portalData) {
                return Positioned(
                  left: portalData.position.dx,
                  top: portalData.position.dy,
                  // 关键修复 #5: Draggable 在这里，包裹 FolderPortalWidget
                  child: Draggable<FolderPortalModel>(
                    data: portalData,
                    // feedback 是拖动时显示的样子
                    feedback: Material(
                      color: Colors.transparent,
                      child: Opacity(
                        opacity: 0.7,
                        child: FolderPortalWidget(portalData: portalData),
                      ),
                    ),
                    // childWhenDragging 是原来位置留下的占位符
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: FolderPortalWidget(portalData: portalData),
                    ),
                    // child 是正常显示的样子
                    child: FolderPortalWidget(portalData: portalData),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}