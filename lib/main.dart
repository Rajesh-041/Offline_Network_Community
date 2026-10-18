import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ble/ble_simulation.dart';
import 'ble/ble_transport.dart';
import 'crypto/identity_manager.dart';
import 'data/database_helper.dart';
import 'mesh/mesh_router.dart';
import 'ml/adaptive_router.dart';
import 'ml/translation_engine.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services
  final identityManager = IdentityManager();
  final dbHelper = DatabaseHelper();
  final translationEngine = TranslationEngine();
  final mlRouter = TinyMlAdaptiveRouter();

  // Auto-select transport:
  // • Android / iOS  → Real hardware flutter_blue_plus BLE transport
  // • Windows / Web  → Simulation transport (for desktop testing)
  final IBleTransport transport = (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
      ? NativeBleTransport(identityManager: identityManager)
      : BleSimulationEngine(identityManager: identityManager);

  final simulationEngine = (transport is BleSimulationEngine)
      ? transport
      : BleSimulationEngine(identityManager: identityManager);

  final meshRouter = MeshRouter(
    transport: transport,
    identityManager: identityManager,
    dbHelper: dbHelper,
    mlRouter: mlRouter,
    translationEngine: translationEngine,
  );

  // Start BLE scanning & advertising in background
  // On Android: requests permissions then starts flutter_blue_plus scan
  // On Desktop: starts BLE simulation engine
  transport.startScanAndAdvertise();

  runApp(MeshLinkApp(
    meshRouter: meshRouter,
    identityManager: identityManager,
    dbHelper: dbHelper,
    simulationEngine: simulationEngine,
    translationEngine: translationEngine,
  ));
}

class MeshLinkApp extends StatelessWidget {
  final MeshRouter meshRouter;
  final IdentityManager identityManager;
  final DatabaseHelper dbHelper;
  final BleSimulationEngine simulationEngine;
  final TranslationEngine translationEngine;

  const MeshLinkApp({
    super.key,
    required this.meshRouter,
    required this.identityManager,
    required this.dbHelper,
    required this.simulationEngine,
    required this.translationEngine,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshLink - BLE Mesh Chat',
      debugShowCheckedModeBanner: false,
      theme: MeshTheme.lightTheme,
      darkTheme: MeshTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: HomeScreen(
        meshRouter: meshRouter,
        identityManager: identityManager,
        dbHelper: dbHelper,
        simulationEngine: simulationEngine,
        translationEngine: translationEngine,
      ),
    );
  }
}
