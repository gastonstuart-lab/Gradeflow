import 'package:flutter_test/flutter_test.dart';

import 'package:gradeflow/integrations/connected_destinations.dart';

void main() {
  group('ConnectedDestinations', () {
    test('registers the approved production destinations', () {
      expect(ConnectedDestinations.iedStudio.stableId, 'ied-studio');
      expect(
        ConnectedDestinations.iedStudio.url,
        'https://ied-hub.web.app/admin',
      );
      expect(ConnectedDestinations.iedStudio.owner, ConnectedSystemOwner.ied);
      expect(ConnectedDestinations.iedStudio.requiresAuthentication, isTrue);
      expect(ConnectedDestinations.iedStudio.isProduction, isTrue);

      expect(
        ConnectedDestinations.iedScienceHub.stableId,
        'ied-science-hub',
      );
      expect(
        ConnectedDestinations.iedScienceHub.url,
        'https://ied-hub.web.app/esl/science',
      );
      expect(
        ConnectedDestinations.iedScienceHub.owner,
        ConnectedSystemOwner.ied,
      );
      expect(
        ConnectedDestinations.iedScienceHub.requiresAuthentication,
        isFalse,
      );
      expect(ConnectedDestinations.iedScienceHub.isProduction, isTrue);
    });

    test('reserves Science Lessons without exposing a production URL', () {
      final destination = ConnectedDestinations.scienceLessons;

      expect(destination.stableId, 'science-lessons');
      expect(destination.owner, ConnectedSystemOwner.science);
      expect(
        destination.availability,
        ConnectedDestinationAvailability.deferred,
      );
      expect(destination.isProduction, isFalse);
      expect(destination.url, isNull);
      expect(destination.uri, isNull);
      expect(
        ConnectedDestinations.production,
        isNot(contains(destination)),
      );
    });

    test('production destinations contain no private class or student context', () {
      for (final destination in ConnectedDestinations.production) {
        final uri = destination.uri;
        expect(uri, isNotNull, reason: destination.stableId);
        expect(uri!.scheme, 'https');
        expect(uri.query, isEmpty, reason: destination.stableId);
        expect(uri.fragment, isEmpty, reason: destination.stableId);

        final lower = uri.toString().toLowerCase();
        expect(lower, isNot(contains('classid=')));
        expect(lower, isNot(contains('studentid=')));
        expect(lower, isNot(contains('teacherid=')));
        expect(lower, isNot(contains('grade=')));
      }
    });

    test('lookup returns the registered destination identity', () {
      expect(
        ConnectedDestinations.byId(ConnectedDestinationId.iedStudio),
        same(ConnectedDestinations.iedStudio),
      );
      expect(
        ConnectedDestinations.byId(ConnectedDestinationId.iedScienceHub),
        same(ConnectedDestinations.iedScienceHub),
      );
      expect(
        ConnectedDestinations.byId(ConnectedDestinationId.scienceLessons),
        same(ConnectedDestinations.scienceLessons),
      );
    });
  });

  group('ConnectedDestinationLauncher', () {
    test('opens an approved production destination', () async {
      Uri? openedUri;
      final launcher = ConnectedDestinationLauncher(
        opener: (uri) async {
          openedUri = uri;
          return true;
        },
      );

      final result = await launcher.open(ConnectedDestinations.iedStudio);

      expect(result, ConnectedDestinationLaunchResult.opened);
      expect(
        openedUri,
        Uri.parse('https://ied-hub.web.app/admin'),
      );
    });

    test('does not launch a deferred destination', () async {
      var openerCalled = false;
      final launcher = ConnectedDestinationLauncher(
        opener: (uri) async {
          openerCalled = true;
          return true;
        },
      );

      final result = await launcher.open(ConnectedDestinations.scienceLessons);

      expect(result, ConnectedDestinationLaunchResult.unavailable);
      expect(openerCalled, isFalse);
    });

    test('rejects an invalid external URL before launch', () async {
      var openerCalled = false;
      final launcher = ConnectedDestinationLauncher(
        opener: (uri) async {
          openerCalled = true;
          return true;
        },
      );
      const invalid = ConnectedDestination(
        id: ConnectedDestinationId.iedStudio,
        stableId: 'invalid-test-destination',
        owner: ConnectedSystemOwner.ied,
        label: 'Invalid test destination',
        description: 'Test only.',
        availability: ConnectedDestinationAvailability.production,
        requiresAuthentication: false,
        url: 'javascript:alert(1)',
      );

      final result = await launcher.open(invalid);

      expect(result, ConnectedDestinationLaunchResult.invalid);
      expect(openerCalled, isFalse);
    });

    test('reports a failed external launch without throwing', () async {
      final launcher = ConnectedDestinationLauncher(
        opener: (uri) async => false,
      );

      final result = await launcher.open(ConnectedDestinations.iedScienceHub);

      expect(result, ConnectedDestinationLaunchResult.failed);
    });

    test('converts opener exceptions into a safe failed result', () async {
      final launcher = ConnectedDestinationLauncher(
        opener: (uri) async => throw StateError('launch failed'),
      );

      final result = await launcher.open(ConnectedDestinations.iedScienceHub);

      expect(result, ConnectedDestinationLaunchResult.failed);
    });
  });
}
