import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../login_screen.dart';

/// Tab 4 — the user's profile: name, email, monthly budget, and logout.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + name + email
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 32, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Monthly budget card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.savings_outlined,
                      color: AppColors.primary),
                  title: const Text('Monthly budget'),
                  subtitle: Text(
                    user.monthlyBudget != null
                        ? formatMoney(user.monthlyBudget!)
                        : 'Not set',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editBudget(context, auth),
                ),
              ),
              const SizedBox(height: 24),

              // Logout
              OutlinedButton.icon(
                onPressed: () => _logout(context, auth),
                icon: const Icon(Icons.logout, color: AppColors.expense),
                label: const Text('Log out',
                    style: TextStyle(color: AppColors.expense)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.expense),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show a dialog to edit the monthly budget.
  Future<void> _editBudget(BuildContext context, AuthProvider auth) async {
    final controller = TextEditingController(
      text: auth.user?.monthlyBudget?.toStringAsFixed(2) ?? '',
    );

    final newBudget = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set monthly budget'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newBudget != null) {
      await auth.updateMonthlyBudget(newBudget);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget updated')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    await auth.logout();
    if (!context.mounted) return;
    // Send the user back to login and clear the navigation history.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
