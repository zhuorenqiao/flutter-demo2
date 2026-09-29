import 'package:flutter/material.dart';

/// 执行一次后端写操作，失败时用 SnackBar 反馈（网络错误、分类校验等）。
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  String failure = '操作失败',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$failure：$e')));
  }
}
