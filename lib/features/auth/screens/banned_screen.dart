import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../core/theme/app_colors.dart';

class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: BrandCard(
                highlighted: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: 72, color: AppColors.danger),
                    const SizedBox(height: 16),
                    const Text('Вы забанены в игре!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Ваш аккаунт заблокирован администратором. Обратитесь в поддержку если это ошибка.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => ref.read(authProvider.notifier).logout(),
                        child: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
