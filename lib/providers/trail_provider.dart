import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_park_reports/providers/http_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:gpx/gpx.dart';

/// Represents a Trail in Forest Park
class Trail {
  String name;
  String uuid;
  Track? track;
  Trail(this.name, this.uuid, [this.track]);
  Trail copyWith({String? name, String? uuid, Track? track}) {
    return Trail(name ?? this.name, uuid ?? this.uuid, track ?? this.track);
  }
}

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
  String? selectedTrail;
  Set<TrackPolyline> trailPolylines;
  /// Returns a list of Polylines from the TrailPolylines, adding the main
  /// Polyline for unselected Trails and the 2 selection Polylines
  /// for selected ones
  Set<Polyline> get polylines => trailPolylines.map((e) => e.polylines).expand((e) => e).toSet();
  bool get isPopulated => !(trails.isEmpty || polylines.isEmpty);

  ParkTrails({this.trails = const {}, this.selectedTrail, this.trailPolylines = const {}});

  // We need a copyWith function for everything being used in a StateNotifier
  // because riverpod StateNotifier state is immutable
  ParkTrails copyWith({required String? selectedTrail, Set<TrackPolyline>? trailPolylines}) {
    return ParkTrails(
      trails: trails,
      selectedTrail: selectedTrail,
      trailPolylines: trailPolylines ?? this.trailPolylines
    );
  }
}

/// Holds information for drawing a Trail object in a GoogleMap widget
class TrackPolyline {
  /// Returns a list of all polylines that should be displayed
  Set<Polyline> get polylines => selected ? {selectedPolyline, highlightPolyline} : {polyline};
  final bool selected;
  late final Polyline polyline;
  late final Polyline selectedPolyline;
  late final Polyline highlightPolyline;
  // private constructor used to copy without recreating Polylines
  TrackPolyline._fromPolylines(
      this.selected,
      this.polyline,
      this.selectedPolyline,
      this.highlightPolyline,
  );
  TrackPolyline({
    required String id,
    required Track track,
    required this.selected,
    required BitmapDescriptor startCap,
    required BitmapDescriptor endCap,
    required ValueSetter<bool> onSelect,
  }) {
    // this is the polyline that will be shown when not selected
    polyline = Polyline(
        polylineId: PolylineId(id),
        points: track.path,
        width: 2,
        color: Colors.orange,
        consumeTapEvents: true,
        onTap: () {
          // we pass back the selection to the notifier in a callback
          onSelect(true);
        }
    );
    // these two are when selected
    // zIndex above highlight polyline to show above
    selectedPolyline = polyline.copyWith(
      colorParam: Colors.green,
      startCapParam: Cap.customCapFromBitmap(startCap),
      endCapParam: Cap.customCapFromBitmap(endCap),
      zIndexParam: 10,
      onTapParam: () {
        onSelect(false);
      },
    );
    highlightPolyline = Polyline(
      polylineId: PolylineId("${id}_highlight"),
      points: track.path,
      color: Colors.green.withAlpha(80),
      width: 10,
      zIndex: 2,
    );
  }
  TrackPolyline copyWith(bool? selected) {
    return TrackPolyline._fromPolylines(selected ?? this.selected, polyline, selectedPolyline, highlightPolyline);
  }
}

class ParkTrailsNotifier extends StateNotifier<ParkTrails> {
  // initial state is an empty ParkTrails
  ParkTrailsNotifier(StateNotifierProviderRef ref) : super(ParkTrails()) {
    // we need to load the asset files for the end caps
    _loadBitmaps();
    // watch the raw trail provider for updates. When the trails have been
    // loaded or refreshed it will call _buildPolylines.
    ref.listen(rawTrailsProvider, (_, Map<String, Trail> rawTrails) {_buildPolylines(rawTrails);});
  }

  // we load the assets into a Completer so we can listen to when the load
  // is done and update state then
  final Completer<List<BitmapDescriptor>> bitmaps = Completer();
  Future _loadBitmaps() async {
    bitmaps.complete(await Future.wait([
      BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(),
          'assets/markers/start.png'
      ),
      BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(),
          'assets/markers/end.png'
      )
    ]));
  }

  // builds the TrailPolylines for each Trail and handles selection logic
  // plus updates ParkTrails state
  Future _buildPolylines(Map<String, Trail> trails) async {
    // wait on completer
    var bitmaps = await this.bitmaps.future;
    Set<TrackPolyline> trailPolylines = {};
    for (var trail in trails.values.where((t) => t.track != null)) {
      late TrackPolyline trailPolyline;
      trailPolyline = TrackPolyline(
          id: trail.name,
          track: trail.track!,
          selected: false,
          startCap: bitmaps.first,
          endCap: bitmaps.last,
          onSelect: (selected) {
            if (selected) {
              // when we've selected this trail, we should create a new copy
              // of the state with this TrailPolyline copied as selected
              state = state.copyWith(
                selectedTrail: trail.name,
                trailPolylines: {
                  for (final tp in state.trailPolylines)
                    if (tp.polyline.polylineId.value == trail.name)
                      tp.copyWith(true)
                    else
                      tp.copyWith(false)
                },
              );
            } else {
              // when we've unselected this trail, we need to remove the
              // selectedTrail and update the TrailPolyline
              state = state.copyWith(
                selectedTrail: null,
                trailPolylines: {
                  for (final tp in state.trailPolylines) tp.copyWith(false)
                },
              );
            }
          }
      );
      trailPolylines.add(trailPolyline);
    }
    // initial state update
    state = ParkTrails(
        trails: trails,
        trailPolylines: trailPolylines
    );
  }

  // function on the notifier which deselects all trails and updates state
  void deselectTrails() {
    state = state.copyWith(
      selectedTrail: null,
      trailPolylines: {
        for (final tp in state.trailPolylines) tp.copyWith(false)
      },
    );
  }

}

final parkTrailsProvider = StateNotifierProvider<ParkTrailsNotifier, ParkTrails>((ref) {
  return ParkTrailsNotifier(ref);
});
