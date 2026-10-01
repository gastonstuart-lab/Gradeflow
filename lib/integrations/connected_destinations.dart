import 'package:url_launcher/url_launcher.dart';

enum ConnectedSystemOwner {
  ied,
  science,
}

enum ConnectedDestinationAvailability {
  production,
  deferred,
}

enum ConnectedDestinationId {
  iedStudio,
  iedScienceHub,
  scienceLessons,
}

class ConnectedDestination {
  const ConnectedDestination({
    required this.id,
    required this.stableId,
    required this.owner,
    required this.label,
    required this.description,
    required this.availability,
    required this.requiresAuthentication,
    this.url,
    this.external = true,
  });

  final ConnectedDestinationId id;
  final String stableId;
  final ConnectedSystemOwner owner;
  final String label;
  final String description;
  final ConnectedDestinationAvailability availability;
  final bool requiresAuthentication;
  final String? url;
  final bool external;

  bool get isProduction =>
      availability == ConnectedDestinationAvailability.production;

  Uri? get uri {
    final value = url?.trim();
    if (value == null || value.isEmpty) return null;

    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        (parsed.scheme != 'https' && parsed.scheme != 'http')) {
      return null;
    }

    return parsed;
  }
}

/// Canonical cross-system destinations known to InstructOS.
///
/// These entries are references only. They do not copy IED/Science data into
/// GradeFlow and do not imply shared Firebase identity.
class ConnectedDestinations {
  const ConnectedDestinations._();

  static const iedStudio = ConnectedDestination(
    id: ConnectedDestinationId.iedStudio,
    stableId: 'ied-studio',
    owner: ConnectedSystemOwner.ied,
    label: 'IED Studio',
    description: 'Departments, hubs, publishing, and shared content.',
    availability: ConnectedDestinationAvailability.production,
    requiresAuthentication: true,
    url: 'https://ied-hub.web.app/admin',
  );

  static const iedScienceHub = ConnectedDestination(
    id: ConnectedDestinationId.iedScienceHub,
    stableId: 'ied-science-hub',
    owner: ConnectedSystemOwner.ied,
    label: 'Science',
    description: 'Science Hub, shared resources, and teaching content.',
    availability: ConnectedDestinationAvailability.production,
    requiresAuthentication: false,
    url: 'https://ied-hub.web.app/esl/science',
  );

  /// Reserved identity for the private Science Lessons workspace.
  ///
  /// The workspace exists in the IED codebase but is not deployed on the
  /// current production host. It therefore has no production URL and must not
  /// appear as a normal production destination.
  static const scienceLessons = ConnectedDestination(
    id: ConnectedDestinationId.scienceLessons,
    stableId: 'science-lessons',
    owner: ConnectedSystemOwner.science,
    label: 'Science Lessons',
    description: 'Private Science lesson/courseware workspace.',
    availability: ConnectedDestinationAvailability.deferred,
    requiresAuthentication: true,
  );

  static const all = <ConnectedDestination>[
    iedStudio,
    iedScienceHub,
    scienceLessons,
  ];

  static ConnectedDestination byId(ConnectedDestinationId id) {
    return switch (id) {
      ConnectedDestinationId.iedStudio => iedStudio,
      ConnectedDestinationId.iedScienceHub => iedScienceHub,
      ConnectedDestinationId.scienceLessons => scienceLessons,
    };
  }

  static Iterable<ConnectedDestination> get production =>
      all.where((destination) => destination.isProduction);
}

enum ConnectedDestinationLaunchResult {
  opened,
  unavailable,
  invalid,
  failed,
}

typedef ConnectedDestinationOpener = Future<bool> Function(Uri uri);

class ConnectedDestinationLauncher {
  ConnectedDestinationLauncher({ConnectedDestinationOpener? opener})
      : _opener = opener ?? _openExternalUri;

  final ConnectedDestinationOpener _opener;

  Future<ConnectedDestinationLaunchResult> open(
    ConnectedDestination destination,
  ) async {
    if (!destination.isProduction) {
      return ConnectedDestinationLaunchResult.unavailable;
    }

    final uri = destination.uri;
    if (uri == null) {
      return ConnectedDestinationLaunchResult.invalid;
    }

    try {
      final opened = await _opener(uri);
      return opened
          ? ConnectedDestinationLaunchResult.opened
          : ConnectedDestinationLaunchResult.failed;
    } catch (_) {
      return ConnectedDestinationLaunchResult.failed;
    }
  }

  static Future<bool> _openExternalUri(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.platformDefault);
  }
}
