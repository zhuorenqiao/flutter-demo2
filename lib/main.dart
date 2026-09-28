import 'package:flutter/material.dart';

import 'data/ledger_repository.dart';
import 'pages/home_page.dart';
import 'state/ledger_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LedgerApp(LedgerStore(await openLedgerRepository())));
}

class LedgerApp extends StatefulWidget {
  const LedgerApp(this.store, {super.key});

  final LedgerStore store;

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  @override
  void initState() {
    super.initState();
    widget.store.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账本',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: HomePage(store: widget.store),
    );
  }
}
