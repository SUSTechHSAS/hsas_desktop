import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class SystemService {
  // 单击打开文件或应用
  Future<void> openPath(String path, BuildContext context) async {
    try {
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $path';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开: $e')),
      );
    }
  }

  // 最小化窗口
  Future<void> minimizeWindow() async {
    await windowManager.minimize();
  }

  Future<void> toggleMinimize() async {
    bool isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      // 如果已最小化，则恢复
      await windowManager.restore();
      await windowManager.focus();
    } else {
      // 如果未最小化，则最小化
      await windowManager.minimize();
    }
  }

  // 关机 (危险操作)
  Future<void> shutdown(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认操作'),
        content: const Text('您确定要关闭计算机吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && Platform.isWindows) {
      await Process.run('shutdown', ['/s', '/t', '0']);
    }
  }
}