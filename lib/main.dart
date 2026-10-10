// ACATRAIN application entry point.
//
// Kept as a compatibility facade: existing integrations and widget tests
// can continue importing AcatrainApp and HomeShell from main.dart.
import 'app/bootstrap.dart';

export 'app/acatrain_app.dart' show AcatrainApp;
export 'features/shell/presentation/home_shell.dart' show HomeShell;

Future<void> main() => launchAcatrain();
