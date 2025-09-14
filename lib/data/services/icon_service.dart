import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class IconService {
  // 将 HICON (Windows 图标句柄) 转换为 Flutter 可以使用的 ImageProvider
  ImageProvider? _imageProviderFromHICON(int hIcon) {
    if (hIcon == 0) return null;
    try {
      final iconInfo = calloc<ICONINFO>();
      if (GetIconInfo(hIcon, iconInfo) != 0) {
        final hBitmap = iconInfo.ref.hbmColor;
        if (hBitmap != 0) {
          final bmp = calloc<BITMAP>();
          GetObject(hBitmap, sizeOf<BITMAP>(), bmp);
          final buffer = _getBitmapBits(hBitmap, bmp.ref.bmWidth, bmp.ref.bmHeight);
          if (buffer != null) {
            // 使用 MemoryImage 来显示从内存中读取的位图数据
            return MemoryImage(buffer);
          }
          free(bmp);
        }
        free(iconInfo);
      }
    } finally {
      DestroyIcon(hIcon);
    }
    return null;
  }

  // 从位图句柄中提取像素数据
  Uint8List? _getBitmapBits(int hBitmap, int width, int height) {
    final hdc = GetDC(NULL);
    final bitmapInfo = calloc<BITMAPINFO>();
    bitmapInfo.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
    bitmapInfo.ref.bmiHeader.biWidth = width;
    bitmapInfo.ref.bmiHeader.biHeight = -height; // 负数表示从上到下
    bitmapInfo.ref.bmiHeader.biPlanes = 1;
    bitmapInfo.ref.bmiHeader.biBitCount = 32;
    bitmapInfo.ref.bmiHeader.biCompression = BI_RGB;

    final bufferSize = width * height * 4;
    final buffer = calloc<Uint8>(bufferSize);

    final result = GetDIBits(
      hdc,
      hBitmap,
      0,
      height,
      buffer.cast<Void>(),
      bitmapInfo,
      DIB_RGB_COLORS,
    );

    Uint8List? imageBytes;
    if (result > 0) {
      // Windows 位图是 BGRA 格式，我们需要转换为 RGBA
      final bgra = buffer.asTypedList(bufferSize);
      final rgba = Uint8List(bufferSize);
      for (int i = 0; i < bgra.length; i += 4) {
        rgba[i] = bgra[i + 2]; // R
        rgba[i + 1] = bgra[i + 1]; // G
        rgba[i + 2] = bgra[i]; // B
        rgba[i + 3] = bgra[i + 3]; // A
      }
      imageBytes = rgba;
    }

    free(bitmapInfo);
    free(buffer);
    ReleaseDC(NULL, hdc);
    return imageBytes;
  }

  // 公开的接口：获取文件图标
  Future<ImageProvider?> getFileIcon(String path, {bool isSmall = false}) async {
    final fileInfo = calloc<SHFILEINFOW>();
    final uFlags = SHGFI_ICON | (isSmall ? SHGFI_SMALLICON : SHGFI_LARGEICON);

    final hr = SHGetFileInfoW(
      path.toNativeUtf16(),
      0,
      fileInfo,
      sizeOf<SHFILEINFOW>(),
      uFlags,
    );

    if (hr != 0) {
      final hIcon = fileInfo.ref.hIcon;
      free(fileInfo);
      return _imageProviderFromHICON(hIcon);
    }

    free(fileInfo);
    return null;
  }
}