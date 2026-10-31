import 'package:app_novik/presentation/providers/shell_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pedir un módulo lo deja pendiente y avisa; atenderlo lo limpia', () {
    final nav = ShellNavigation();
    var notified = 0;
    nav.addListener(() => notified++);

    expect(nav.requested, isNull);
    nav.goTo('ventas');

    expect(nav.requested, 'ventas');
    expect(notified, 1);
    expect(nav.take(), 'ventas');
    expect(nav.requested, isNull);
    expect(nav.take(), isNull);
  });
}
