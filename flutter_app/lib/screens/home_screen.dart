import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../widgets/add_transaction_sheet.dart';
import 'tabs/ai_chat_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/transactions_tab.dart';

/// The main shell after logging in: a bottom navigation bar with 4 tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // The four tab screens. IndexedStack (below) keeps their state when switching.
  final List<Widget> _tabs = const [
    DashboardTab(),
    TransactionsTab(),
    AiChatTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Load categories + transactions + summary once the screen is ready.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<TransactionProvider>().init(),
    );
  }

  void _openAddTransaction() {
    AddTransactionSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    // Show the "add" button only on the Dashboard and Transactions tabs.
    final showFab = _currentIndex == 0 || _currentIndex == 1;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: _openAddTransaction,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'AI Chat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
