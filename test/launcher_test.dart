import 'package:bloxawys/services/roblox_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsePlaceId', () {
    expect(parsePlaceId(''), isNull);
    expect(parsePlaceId('920587237'), 920587237);
    expect(
      parsePlaceId('https://www.roblox.com/games/920587237/Adopt-Me'),
      920587237,
    );
    expect(parsePlaceId('https://www.roblox.com/home'), isNull);
  });

  test('buildLaunchUri', () {
    final app = RobloxLauncher.buildLaunchUri(ticket: 'T');
    expect(app, startsWith('roblox-player:1+launchmode:app+gameinfo:T+'));
    expect(app, isNot(contains('placelauncherurl')));

    final play = RobloxLauncher.buildLaunchUri(ticket: 'T', placeId: 42);
    expect(play, contains('launchmode:play'));
    final launcherUrl = Uri.decodeComponent(
      RegExp(r'placelauncherurl:([^+]+)').firstMatch(play)!.group(1)!,
    );
    expect(Uri.parse(launcherUrl).queryParameters['placeId'], '42');
  });
}
