import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Hazard extends NewHazardRequest {
  String uuid;
  DateTime time;
  bool active;

  Hazard(this.uuid, this.time, this.active, super.hazard, super.location, [super.image]);

  Hazard.fromJson(Map<String, dynamic> json)
      : uuid = json['uuid'],
        time = DateTime.parse(json['time']),
        active = json['active'],
        super.fromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'time': time.toIso8601String(),
      ...super.toJson()
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class NewHazardRequest {
  HazardType hazard;
  SnappedLatLng location;
  String? image;

  NewHazardRequest(this.hazard, this.location, [this.image]);

  NewHazardRequest.fromJson(Map<String, dynamic> json)
      : hazard = HazardType.values.byName(json['hazard']),
        location = SnappedLatLng.fromJson(json['location']),
        image = json.containsKey('image') ? json['image'] : null;

  Map<String, dynamic> toJson() {
    return {
      'hazard': hazard.name,
      'location': location.toJson(),
      'image': image,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

// A way of representing a LatLng pair that exists on a path. Stores
// the path uuid, along with the index of the point, and a LatLng pair
class SnappedLatLng extends LatLng {
  String trail;
  int index;

  SnappedLatLng(this.trail, this.index, LatLng loc) : super(loc.latitude, loc.longitude);

  SnappedLatLng.fromJson(Map<String, dynamic> json)
      : trail = json['trail'],
        index = json['index'],
        super(json['lat'], json['long']);

  @override
  Map<String, dynamic> toJson() {
    return {
      'trail': trail,
      'index': index,
      'lat': latitude,
      'long': longitude,
    };
  }
  @override
  String toString() {
    return "${super.toString()} trailUuid:$trail, index:$index";
  }
}

enum HazardType {
  tree,
  flood,
  other,
}

extension HazardTypeInfo on HazardType {
  String get displayName {
    switch (this) {
      case HazardType.tree:
        return "Fallen Tree";
      case HazardType.flood:
        return "Flooded Trail";
      case HazardType.other:
        return "Other Hazard";
    }
  }
  IconData get icon {
    switch (this) {
      case HazardType.tree:
        return CupertinoIcons.tree;
      case HazardType.flood:
        return Icons.flood_rounded;
      case HazardType.other:
        return CupertinoIcons.question_diamond_fill;
    }
  }
}
