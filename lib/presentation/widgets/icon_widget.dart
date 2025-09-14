import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:hsas_desktop/data/models/desktop_model.dart';
import 'package:hsas_desktop/data/models/icon_model.dart';
import 'package:hsas_desktop/data/services/system_service.dart';
import 'package:hsas_desktop/utils/app_constants.dart';
import 'package:hsas_desktop/presentation/providers/app_provider.dart';

class IconWidget extends StatelessWidget {
  final IconModel iconData;
  final ClickBehavior clickBehavior;
  final double iconSizeScale;
  final SystemService _systemService = SystemService();

  IconWidget({
    super.key,
    required this.iconData,
    required this.clickBehavior,
    this.iconSizeScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final double scaledIconSize = AppConstants.iconSize * iconSizeScale;

    return GestureDetector(
      onTap: clickBehavior == ClickBehavior.singleClick
          ? () => _systemService.openPath(iconData.path, context)
          : null,
      onDoubleTap: clickBehavior == ClickBehavior.doubleClick
          ? () => _systemService.openPath(iconData.path, context)
          : null,
      child: SizedBox(
        width: scaledIconSize + 24,
        height: scaledIconSize + 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use the FileIcon widget to get an icon based on the file name/extension
            FutureBuilder<ImageProvider?>(
              // future 指向我们刚刚在 AppProvider 中创建的方法
              future: appProvider.getIconProvider(iconData.path, isSmall: false),
              builder: (context, snapshot) {
                // 状态 1: 正在加载中
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    width: scaledIconSize,
                    height: scaledIconSize,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                  );
                }
                // 状态 2: 加载完成且成功获取到图标
                if (snapshot.hasData && snapshot.data != null) {
                  return Image(
                    image: snapshot.data!,
                    width: scaledIconSize,
                    height: scaledIconSize,
                    fit: BoxFit.contain,
                  );
                }
                // 状态 3: 加载失败或未获取到图标，显示一个备用图标
                return Icon(
                  iconData.type == IconType.folder ? Icons.folder : Icons.insert_drive_file,
                  size: scaledIconSize,
                  color: Colors.white,
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              iconData.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12 * iconSizeScale,
                shadows: const [Shadow(blurRadius: 2.0, color: Colors.black)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}