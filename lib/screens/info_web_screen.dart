import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/app_theme.dart';
import '../services/audio_service.dart';

/// Lightweight in-app browser used for the Privacy Policy and Support pages.
/// Plain WebView with a back button — no JS injection, no file picker, no
/// fullscreen handling. Designed for static informational pages only.
class InfoWebScreen extends StatefulWidget {
  final String title;
  final String url;

  const InfoWebScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<InfoWebScreen> createState() => _InfoWebScreenState();
}

class _InfoWebScreenState extends State<InfoWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.panel)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panel,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: Text(widget.title, style: AppTextStyles.button(size: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AudioService.instance.playSfx(Sfx.buttonClick);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 3,
              ),
            ),
        ],
      ),
    );
  }
}
