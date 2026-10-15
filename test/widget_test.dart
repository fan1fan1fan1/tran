import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tran/main.dart';
import 'package:tran/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('界面冒烟测试：标题、输入框与翻译按钮存在', (tester) async {
    await tester.pumpWidget(const TranApp());
    await tester.pump();

    expect(find.text('tran'), findsOneWidget);
    expect(find.text('输入要翻译的文字…'), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
  });

  test('语言表覆盖中英日法俄德韩泰', () {
    expect(kLanguages.length, 8);
    final codes = kLanguages.map((l) => l.code).toSet();
    expect(
      codes,
      containsAll(['zh-CN', 'en', 'ja', 'fr', 'ru', 'de', 'ko', 'th']),
    );
  });
}
