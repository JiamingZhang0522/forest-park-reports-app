import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forest_park_reports/pages/home_screen.dart';
import 'package:forest_park_reports/providers/trail_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class ForestParkMap extends ConsumerStatefulWidget {
  const ForestParkMap({Key? key}) : super(key: key);

  @override
  ConsumerState<ForestParkMap> createState() => _ForestParkMapState();
}

class _ForestParkMapState extends ConsumerState<ForestParkMap> with WidgetsBindingObserver {
  final _location = Location();
  LocationData? _lastLoc;
  // TODO set initial camera position to be centered on ForestPark
  late final MapController _mapController;

  // TODO allow more map styles (custom styles?) + satellite
  late String _darkMapStyle;
  late String _lightMapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    // listen for location changes and update _lastLoc
    _subscribeLocation();
    // load style jsons from assets
    _loadMapStyles();
  }

  Future _loadMapStyles() async {
    _darkMapStyle  = await rootBundle.loadString('assets/map_styles/dark.json');
    _lightMapStyle = await rootBundle.loadString('assets/map_styles/light.json');
    _setMapStyle();
  }

  // listen for brightness change so we can update map style
  @override
  void didChangePlatformBrightness() {
    setState(() {
      _setMapStyle();
    });
  }

  Future _setMapStyle() async {
    // final theme = WidgetsBinding.instance.window.platformBrightness;
    // if (theme == Brightness.dark) {
    //   controller.setMapStyle(_darkMapStyle);
    // } else {
    //   controller.setMapStyle(_lightMapStyle);
    // }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  void _subscribeLocation() {
    // runs on initial load, so update location and move camera without animation
    _location.getLocation().then((l) {
      _lastLoc = l;
      // widget.onStickyUpdate(true);
      // _lastCamera = CameraPosition(
      //     target: LatLng(l.latitude!, l.longitude!),
      //     zoom: 14.5
      // );
      // _mapController.future.then((c) {
      //   c.moveCamera(
      //       CameraUpdate.newCameraPosition(_lastCamera)
      //   );
      // });
    });
    // sets up listener which runs whenever location changes
    _location.onLocationChanged.listen((l) {
      _lastLoc = l;
      if (ref.read(stickyLocationProvider)) {
        _animateCamera(LatLng(l.latitude!, l.longitude!));
      }
    });
  }

  // helper function to animate the camera to a target while retaining other camera info
  void _animateCamera(LatLng target) {
    // _mapController.future.then((c) {
    //   c.animateCamera(
    //     CameraUpdate.newCameraPosition(
    //       CameraPosition(
    //           target: target,
    //           zoom: _lastCamera.zoom,
    //           bearing: _lastCamera.bearing,
    //           tilt: _lastCamera.tilt
    //       ),
    //     ),
    //   );
    // });
  }

  @override
  Widget build(BuildContext context) {
    // using ref.watch will allow the widget to be rebuilt everytime
    // the provider is updated
    ParkTrails parkTrails = ref.watch(parkTrailsProvider);
    // enable edge to edge mode on android
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: WidgetsBinding.instance.window.platformBrightness == Brightness.light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent
    ));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // if the sticky location button was just clicked, move camera
    // if (widget.followPointer != _lastStickyLocation) {
    //   // the button was pressed
    //   _lastStickyLocation = widget.followPointer;
    //   if (widget.followPointer && _lastLoc != null) {
    //     // the button was pressed and it is now enabled
    //     _animateCamera(LatLng(_lastLoc!.latitude!, _lastLoc!.longitude!));
    //   }
    // }
    ref.listen(stickyLocationProvider, (a, b) => {});

    // we use a listener to be able to detect when the map has been clicked as
    // the GoogleMap onCameraMove function does not differentiate moving
    // from a gesture, and moving the camera programmatically (_animateCamera)
    return Listener(
      onPointerDown: (e) {
        ref.read(stickyLocationProvider.notifier).update((state) => false);
      },
      // child: GoogleMap(
      //   polylines: parkTrails.polylines,
      //   onMapCreated: _mapController.complete,
      //   initialCameraPosition: _lastCamera,
      //   mapType: MapType.normal,
      //   zoomControlsEnabled: false,
      //   compassEnabled: false,
      //   indoorViewEnabled: true,
      //   myLocationEnabled: true,
      //   myLocationButtonEnabled: false,
      //   onCameraMove: (camera) {
      //     _lastCamera = camera;
      //   },
      //   // the polylines take priority for taps, so this will
      //   // only be called when tapping outside a polyline
      //   onTap: (loc) {
      //     // we're using ref.read on the *notifier* because we want to call a
      //     // function on the notifier, not the provider, and we don't want
      //     // listen for any value changes as calling a function on a notifier
      //     // will update the provider and we already listen to the provider
      //     ref.read(parkTrailsProvider.notifier).deselectTrails();
      //   },
      // ),
      child: FlutterMap(
        options: MapOptions(
          center: LatLng(45.57416784067063, -122.76892379502566),
          zoom: 11.5,
          enableMultiFingerGestureRace: true,
          pinchZoomThreshold: 0.1,
          rotationThreshold: 0.9
        ),
        layers: [
          TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c'],
          ),
        ],
        nonRotatedChildren: [
          AttributionWidget.defaultWidget(
            source: 'OpenStreetMap contributors',
            onSourceTapped: null,
          ),
        ],
      )
    );
  }

}
