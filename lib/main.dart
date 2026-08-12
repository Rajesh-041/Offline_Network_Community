import 'package:flutter/material.dart';
import 'ble/ble_simulation.dart';
import 'crypto/identity_manager.dart';
import 'data/database_helper.dart';
import 'mesh/mesh_router.dart';
import 'ml/adaptive_router.dart';
import 'ml/translation_engine.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize core services
  final identityManager = IdentityManager();
  final dbHelper = DatabaseHelper();
  final translationEngine = TranslationEngine();
  final mlRouter = TinyMlAdaptiveRouter();

  final simulationEngine = BleSimulationEngine(identityManager: identityManager);
  
  final meshRouter = MeshRouter(
    transport: simulationEngine,
    identityManager: identityManager,
    dbHelper: dbHelper,
    mlRouter: mlRouter,
    translationEngine: translationEngine,
  );

  // Start BLE mesh transport loop in background
  simulationEngine.startScanAndAdvertise();

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
