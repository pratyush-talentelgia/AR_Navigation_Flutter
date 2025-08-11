import 'dart:convert';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math_64.dart';

class RetrieveObjectsScreen extends StatefulWidget {
  const RetrieveObjectsScreen({super.key});

  @override
  State<RetrieveObjectsScreen> createState() => _RetrieveObjectsScreenState();
}

class _RetrieveObjectsScreenState extends State<RetrieveObjectsScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  List<ARAnchor> anchors = [];

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager,
      ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    arSessionManager.onInitialize(
      showPlanes: true,
      handleRotation: true,
      showAnimatedGuide: true,
    );
    arObjectManager.onInitialize();

    _loadNearbyObjects();
  }

  Future<void> _loadNearbyObjects() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);

      final url = Uri.parse('http://192.168.0.81:3000/locations');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        print("Failed to load objects: ${res.statusCode}");
        return;
      }

      List<dynamic> allObjects = jsonDecode(res.body);
      for (var obj in allObjects) {
        double lat = (obj['latitude'] as num).toDouble();
        double lng = (obj['longitude'] as num).toDouble();
        double distance = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, lat, lng);

        // Show only within 50 meters
        if (distance <= 50) {
          await _placeObjectFromData(obj);
        }
      }
    } catch (e) {
      print("Error loading objects: $e");
    }
  }

  Future<void> _placeObjectFromData(Map<String, dynamic> obj) async {
    var anchorTransform = Matrix4.fromList(
      obj['anchorTransform']
          .expand((row) => (row as List).map((e) => (e as num).toDouble()))
          .toList()
      .cast<double>(),
    );

    var anchor = ARPlaneAnchor(transformation: anchorTransform);
    bool? addedAnchor = await arAnchorManager!.addAnchor(anchor);

    if (addedAnchor == true) {
      anchors.add(anchor);

      var node = ARNode(
        type: NodeType.webGLB,
        uri: obj['modelUrl'],
        scale: Vector3(
          (obj['scale']['x'] as num).toDouble(),
          (obj['scale']['y'] as num).toDouble(),
          (obj['scale']['z'] as num).toDouble(),
        ),
        position: Vector3(
          (obj['position']['x'] as num).toDouble(),
          (obj['position']['y'] as num).toDouble(),
          (obj['position']['z'] as num).toDouble(),
        ),
        rotation: Vector4(
          (obj['rotation']['x'] as num).toDouble(),
          (obj['rotation']['y'] as num).toDouble(),
          (obj['rotation']['z'] as num).toDouble(),
          (obj['rotation']['w'] as num).toDouble(),
        ),
      );

      await arObjectManager!.addNode(node, planeAnchor: anchor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Retrieve AR Objects")),
      body: ARView(
        onARViewCreated: onARViewCreated,
        planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
      ),
    );
  }
}
