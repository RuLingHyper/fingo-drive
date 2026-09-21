import 'package:flutter_test/flutter_test.dart';
import 'package:fingo_drive_mobil/main.dart';

void main() {
  testWidgets('Uygulama açılış testi', (WidgetTester tester) async {
    // 1. Uygulamayı başlat
    await tester.pumpWidget(const FingoDriveApp());

    // 2. Ekranda "Fingo Drive" yazısının göründüğünü doğrula
    // (SplashScreen veya Login ekranında bu yazı var)
    expect(find.text('Fingo Drive'), findsOneWidget);
  });
}
