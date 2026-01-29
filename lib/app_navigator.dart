import 'main.dart';

class AppNavigator {
  static void goLogin() {
    navKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false);
  }
}
