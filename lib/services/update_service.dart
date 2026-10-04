import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aura/core/constants.dart';
import 'package:aura/core/theme.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String title;
  final String releaseNotes;
  final String downloadUrl;
  final bool mandatory;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
    this.mandatory = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      versionCode: json['version_code'] as int? ?? 1,
      title: json['title'] as String? ?? 'New Update Available',
      releaseNotes: json['release_notes'] as String? ??
          'A new version of AURA is ready with performance improvements and bug fixes.',
      downloadUrl: json['download_url'] as String? ?? AppConstants.defaultWebsiteUrl,
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// Checks remote JSON endpoint for available updates
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    try {
      final uri = Uri.parse(AppConstants.updateCheckUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final updateInfo = AppUpdateInfo.fromJson(data);

        final isNewer = _isRemoteNewer(
          remoteVersion: updateInfo.latestVersion,
          remoteCode: updateInfo.versionCode,
          currentVersion: AppConstants.appVersion,
          currentCode: AppConstants.appVersionCode,
        );

        if (!isNewer) return null;

        // If user already dismissed this specific version and force is false, skip
        if (!force && !updateInfo.mandatory) {
          final prefs = await SharedPreferences.getInstance();
          final dismissedVersion = prefs.getString(AppConstants.keyDismissedUpdateVersion);
          if (dismissedVersion == updateInfo.latestVersion) {
            return null;
          }
        }

        return updateInfo;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
    }
    return null;
  }

  /// Compares semantic versions or version codes
  bool _isRemoteNewer({
    required String remoteVersion,
    required int remoteCode,
    required String currentVersion,
    required int currentCode,
  }) {
    // 1. If versionCode is provided and higher, definitely newer
    if (remoteCode > currentCode) return true;

    // 2. Compare semver numbers
    try {
      final remoteParts = remoteVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currentParts = currentVersion.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLen = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;
      while (remoteParts.length < maxLen) {
        remoteParts.add(0);
      }
      while (currentParts.length < maxLen) {
        currentParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
    } catch (_) {}

    return false;
  }

  /// Mark this version as dismissed so user isn't pestered repeatedly
  Future<void> dismissUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyDismissedUpdateVersion, version);
    } catch (e) {
      debugPrint('[AppUpdateService] Error saving dismissed version: $e');
    }
  }

  /// Opens the download link in default browser
  Future<bool> launchDownload(String url) async {
    final target = url.trim().isNotEmpty ? url.trim() : AppConstants.defaultWebsiteUrl;
    final uri = Uri.parse(target);

    // 1. Try launching directly in external application (system browser)
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (e) {
      debugPrint('[AppUpdateService] externalApplication failed: $e');
    }

    // 2. Try launching in platform default mode
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (launched) return true;
    } catch (e) {
      debugPrint('[AppUpdateService] platformDefault failed: $e');
    }

    // 3. Fallback: check canLaunchUrl
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] canLaunchUrl fallback failed: $e');
    }

    // 4. In-app webview as final fallback
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}

    return false;
  }

  /// Shows the alert modal with an 'X' button to dismiss or Download button to get APK
  Future<void> showUpdateAlertModal(
    BuildContext context,
    AppUpdateInfo update, {
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (BuildContext ctx) {
        final isDark = AuraColors.isDark(ctx);
        final cardBg = AuraColors.card(ctx);
        final textPrimary = AuraColors.text(ctx);
        final textSecondary = AuraColors.subtext(ctx);
        final accent = AuraColors.primary(ctx);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : AuraColors.creamBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with badge and 'X' close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.system_update_rounded, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            'v${update.latestVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 'X' cut / close button
                    if (!update.mandatory)
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 22, color: textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Dismiss',
                        onPressed: () {
                          dismissUpdate(update.latestVersion);
                          Navigator.of(ctx).pop();
                          onDismiss?.call();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  update.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Release notes
                Text(
                  update.releaseNotes,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (!update.mandatory) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            dismissUpdate(update.latestVersion);
                            Navigator.of(ctx).pop();
                            onDismiss?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textSecondary,
                            side: BorderSide(
                              color: isDark ? Colors.white.withValues(alpha: 0.15) : AuraColors.creamBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Later', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: update.mandatory ? 1 : 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Opening browser to download APK...'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          final success = await launchDownload(update.downloadUrl);

                          if (success) {
                            if (!update.mandatory && ctx.mounted) {
                              Navigator.of(ctx).pop();
                              onDismiss?.call();
                            }
                          } else {
                            await Clipboard.setData(ClipboardData(text: update.downloadUrl));
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Browser could not be opened automatically.\nDownload link copied to clipboard! Paste it into your browser.',
                                  ),
                                  duration: const Duration(seconds: 5),
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'OK',
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Update', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
