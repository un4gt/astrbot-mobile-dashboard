// Version comparison for the self-update flow.
import 'package:flutter_test/flutter_test.dart';

import 'package:astrbot_mobile/features/update/data/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('plain semver ordering', () {
      expect(UpdateService.compareVersions('1.2.0', '1.1.9'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.0'), 0);
      expect(UpdateService.compareVersions('0.9.9', '1.0.0'), lessThan(0));
    });

    test('different segment counts pad with zero', () {
      expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersions('1.10', '1.9.5'), greaterThan(0));
    });

    test('tolerates non-numeric suffixes', () {
      expect(UpdateService.compareVersions('1.2.0-beta', '1.1.9'),
          greaterThan(0));
      expect(UpdateService.compareVersions('v1.2.0', '1.2.0'), 0);
    });

    test('garbage does not crash and compares as zero segments', () {
      expect(UpdateService.compareVersions('', ''), 0);
      expect(UpdateService.compareVersions('x', '1'), lessThan(0));
    });
  });
}
