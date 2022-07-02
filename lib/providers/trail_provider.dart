import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tappable_polyline/flutter_map_tappable_polyline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_park_reports/providers/http_provider.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';

/// Represents a Trail in Forest Park
class Trail {
  String name;
  String uuid;
  Track? track;
  Trail(this.name, this.uuid, [this.track]);
  Trail copyWith({String? name, String? uuid, Track? track}) {
    return Trail(name ?? this.name, uuid ?? this.uuid, track ?? this.track);
  }

  // Perform equality checks on trail based off only the uuid and name
  // This means two trails with different tracks but the same
  // name and uuid will be considered equal.
  @override
  bool operator ==(Object other) =>
      other is Trail &&
          other.runtimeType == runtimeType &&
          other.name == name &&
          other.uuid == uuid;

  @override
  int get hashCode => hashValues(name, uuid);
}

//TODO reduce polyline points client side
/// Represents a GPX file (list of coordinates) in an easy to use way
class Track {
  List<LatLng> path = [];
  List<double> elevation = [];
  Track(Gpx path) {
    // loop through every track point and add the coordinates to the path array
    // we also construct a separate elevation array for, the elevation of one
    // coordinate has the same index as the coordinate
    for (var track in path.trks) {
      for (var trackSegment in track.trksegs) {
        for (var point in trackSegment.trkpts) {
          this.path.add(LatLng(point.lat!, point.lon!));
          elevation.add(point.ele!);
        }
      }
    }
  }
}

/// Holds a Map of Trails along with a set of polylines and the selected trail
///
/// Polylines are used to render on top of the GoogleMap widget. When a trail
/// is selected, we remove the selected polyline and add in 2 more polylines,
/// one being the trail in a different color, and one being a transparent
/// highlight.
/// The ParkTrails class holds the currently selected polyline
class ParkTrails {
  Map<String, Trail> trails;
  Trail? selectedTrail;
  List<TrackPolyline> trackPolylines;
  /// Returns a list of Polylines from the TrailPolylines, adding the main
  /// Polyline for unselected Trails and the 2 selection Polylines
  /// for selected ones
  List<TaggedPolyline> get polylines => trackPolylines
      .map((e) => e.polylines)
      .expand((e) => e)
      .toList()..sort((a, b) {
        // sorts the list to have selected polylines at the top, with the
        // selected line first and the highlight second. We do this by
        // assigning a value to each type of polyline, and comparing the
        // difference in values to determine the sort order
        final at = a.tag?.split("_");
        final bt = b.tag?.split("_");
        return (at?.length != 2 ? 0 : at?[1] == "selected" ? 2 : at?[1] == "highlight" ? 1 : 0) -
            (bt?.length != 2 ? 0 : bt?[1] == "selected" ? 2 : bt?[1] == "highlight" ? 1 : 0);
      }
  );
  bool get isPopulated => !(trails.isEmpty || polylines.isEmpty);

  ParkTrails({this.trails = const {}, this.selectedTrail, this.trackPolylines = const []});

  // We need a copyWith function for everything being used in a StateNotifier
  // because riverpod StateNotifier state is immutable
  ParkTrails copyWith({required Trail? selectedTrail, List<TrackPolyline>? trackPolylines}) {
    return ParkTrails(
      trails: trails,
      selectedTrail: selectedTrail,
      trackPolylines: trackPolylines ?? this.trackPolylines
    );
  }
}

/// Holds information for drawing a Trail object in a GoogleMap widget
class TrackPolyline {
  final Trail trail;
  final bool selected;
  late final TaggedPolyline polyline;
  late final TaggedPolyline selectedPolyline;
  late final TaggedPolyline highlightPolyline;
  /// Returns a list of all polylines that should be displayed
  Set<TaggedPolyline> get polylines => selected ? {selectedPolyline, highlightPolyline} : {polyline};
  // private constructor used to copy without recreating Polylines
  TrackPolyline._fromPolylines(
      this.trail,
      this.selected,
      this.polyline,
      this.selectedPolyline,
      this.highlightPolyline,
  );
  TrackPolyline({
    required this.trail,
    required this.selected,
  }) {
    // this is the polyline that will be shown when not selected
    polyline = TaggedPolyline(
      tag: trail.uuid,
      points: trail.track!.path,
      strokeWidth: 2.0,
      color: Colors.orange,
    );
    // these two are when selected
    selectedPolyline = TaggedPolyline(
      tag: "${trail.uuid}_selected",
      points: trail.track!.path,
      strokeWidth: 2.0,
      color: Colors.green,
    );
    highlightPolyline = TaggedPolyline(
      tag: "${trail.uuid}_highlight",
      points: trail.track!.path,
      strokeWidth: 10.0,
      color: Colors.green.withAlpha(80),
    );
  }
  TrackPolyline copyWith({bool? selected}) {
    return TrackPolyline._fromPolylines(trail, selected ?? this.selected, polyline, selectedPolyline, highlightPolyline);
  }
}

//TODO custom markers
// final bitmapsProvider = FutureProvider<List<BitmapDescriptor>>((ref) async {
//   return Future.wait([
//     BitmapDescriptor.fromAssetImage(
//         const ImageConfiguration(),
//         'assets/markers/start.png'
//     ),
//     BitmapDescriptor.fromAssetImage(
//         const ImageConfiguration(),
//         'assets/markers/end.png'
//     )
//   ]);
// });

class ParkTrailsNotifier extends StateNotifier<ParkTrails> {
  // initial state is an empty ParkTrails
  ParkTrailsNotifier(StateNotifierProviderRef ref) : super(ParkTrails()) {
    // watch the raw trail provider for updates. When the trails have been
    // loaded or refreshed it will call _buildPolylines.
    var remoteTrails = ref.watch(remoteTrailsProvider);
    _buildPolylines(remoteTrails);
  }

  // builds the TrailPolylines for each Trail and handles selection logic
  // plus updates ParkTrails state
  Future _buildPolylines(Map<String, Trail> trails) async {
    // initial state update
    state = ParkTrails(
      trails: trails,
      trackPolylines: [
        for (var trail in trails.values.where((t) => t.track != null))
          TrackPolyline(
            trail: trail,
            selected: false,
          )
      ],
    );
  }

  // deselects the selected trail if any and updates state
  // must call on the *notifier*
  void deselectTrail() {
    state = state.copyWith(
      selectedTrail: null,
      trackPolylines: [
        for (final tp in state.trackPolylines) tp.copyWith(selected: false)
      ],
    );
  }

  // selects the trial with the given uuid
  void selectTrail(Trail selected) {
    state = state.copyWith(
      selectedTrail: selected,
      trackPolylines: [
        for (final tp in state.trackPolylines)
          tp.copyWith(selected: tp.trail == selected)
      ],
    );
  }

}

final parkTrailsProvider = StateNotifierProvider<ParkTrailsNotifier, ParkTrails>((ref) {
  return ParkTrailsNotifier(ref);
});
