import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';

void main() {
  group('AppConfig.normalizeBaseUrl', () {
    test('adds scheme, default port and API path to a bare LAN IP', () {
      expect(AppConfig.normalizeBaseUrl('192.168.1.20'), 'http://192.168.1.20:3000/api/v1');
    });
    test('keeps an explicit port', () {
      expect(AppConfig.normalizeBaseUrl('10.61.92.224:4000'), 'http://10.61.92.224:4000/api/v1');
    });
    test('does not duplicate the API path and strips trailing slashes', () {
      expect(AppConfig.normalizeBaseUrl('http://10.0.2.2:3000/api/v1/'), 'http://10.0.2.2:3000/api/v1');
    });
    test('https without a port uses 443 implicitly', () {
      expect(AppConfig.normalizeBaseUrl('https://erp.example.com'), 'https://erp.example.com/api/v1');
    });
    test('rejects empty and non-http input', () {
      expect(() => AppConfig.normalizeBaseUrl('  '), throwsFormatException);
      expect(() => AppConfig.normalizeBaseUrl('ftp://host'), throwsFormatException);
    });
  });

  group('AppConfig environment resolution', () {
    ApiEnvironment parse(String name, {bool web = false, TargetPlatform p = TargetPlatform.android, bool release = false}) =>
        AppConfig.parseEnvironment(name, isWeb: web, platform: p, isRelease: release);

    test('explicit names win', () {
      expect(parse('device'), ApiEnvironment.device);
      expect(parse('EMULATOR'), ApiEnvironment.emulator);
      expect(parse('prod'), ApiEnvironment.production);
      expect(parse('dev', p: TargetPlatform.windows), ApiEnvironment.local);
    });
    test('defaults: android debug -> emulator, desktop/web -> local, release -> production', () {
      expect(parse(''), ApiEnvironment.emulator);
      expect(parse('', p: TargetPlatform.windows), ApiEnvironment.local);
      expect(parse('', web: true), ApiEnvironment.local);
      expect(parse('', release: true), ApiEnvironment.production);
    });

    test('emulator uses the host loopback alias, never localhost', () {
      expect(AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.emulator), 'http://10.0.2.2:3000/api/v1');
    });
    test('physical device needs API_HOST; without it no URL is guessed', () {
      expect(AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.device), isNull);
      expect(
        AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.device, hostDefine: '192.168.1.20'),
        'http://192.168.1.20:3000/api/v1',
      );
    });
    test('production needs an explicit API_BASE_URL', () {
      expect(AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.production), isNull);
      expect(
        AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.production, baseUrlDefine: 'https://erp.example.com'),
        'https://erp.example.com/api/v1',
      );
    });
    test('web uses the page host', () {
      expect(AppConfig.resolveBuildTimeBaseUrl(environment: ApiEnvironment.local, webHost: 'erp.lan'),
          'http://erp.lan:3000/api/v1');
    });
  });

  test('validateBaseUrl enforces HTTPS when required', () {
    expect(AppConfig.validateBaseUrl('http://10.0.2.2:3000/api/v1', requireHttps: true), isNotNull);
    expect(AppConfig.validateBaseUrl('https://erp.example.com/api/v1', requireHttps: true), isNull);
    expect(AppConfig.validateBaseUrl('http://10.0.2.2:3000/api/v1', requireHttps: false), isNull);
  });
}
