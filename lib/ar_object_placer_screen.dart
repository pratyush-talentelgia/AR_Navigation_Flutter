import 'dart:convert';

import 'package:ar_object_placer/objects.dart';
import 'package:ar_object_placer/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math_64.dart' hide Colors;

class ARObjectPlacerScreen extends StatefulWidget {
  const ARObjectPlacerScreen({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<ARObjectPlacerScreen> createState() => _ARObjectPlacerScreenState();
}

class _ARObjectPlacerScreenState extends State<ARObjectPlacerScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  List<PlacedObject> placedObjects = [];
  int locationIdCounter = 1;

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _startLocationStream();
    _checkLocationPermission();
  }
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _startLocationStream();
  }
  void _startLocationStream() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    });
  }
  @override
  void dispose() {
    super.dispose();
    arSessionManager!.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Anchors & Objects on Planes'),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'clear',
              onPressed: onRemoveEverything,
              child: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              ARView(
                onARViewCreated: onARViewCreated,
                planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(10),
                    height: 70,
                    child: Column(
                      children: [
                        Text(
                          "Lat: ${latitude?.toStringAsFixed(6) ?? 'Loading...'}",
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          "Long: ${longitude?.toStringAsFixed(6) ?? 'Loading...'}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.white70,
                  child: ListView.builder(
                    itemCount: placedObjects.length,
                    itemBuilder: (context, index) {
                      final obj = placedObjects[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                          'Object ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            'Lat: ${obj.latitude.toStringAsFixed(6)}\nLng: ${obj.longitude.toStringAsFixed(6)}'),
                      );
                    },
                  ),
                ),
              )
            ],
          ),
        ));
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
        showFeaturePoints: false,
        showPlanes: true,
        customPlaneTexturePath: "Images/triangle.png",
        showWorldOrigin: true,
        showAnimatedGuide: true,
        handleRotation: true
    );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;
    this.arObjectManager!.onNodeTap = onNodeTapped;
  }

  Future<void> onRemoveEverything() async {
    for (var anchor in anchors) {
      await arAnchorManager!.removeAnchor(anchor);
    }
    anchors.clear();
    nodes.clear();
    placedObjects.clear();
    setState(() {});
  }

  Future<void> onNodeTapped(List<String> nodeNames) async {
    if (nodeNames.isEmpty) return;

    String tappedNodeName = nodeNames.first;

    ARNode? tappedNode = nodes.where((node) => node.name == tappedNodeName).isNotEmpty
        ? nodes.firstWhere((node) => node.name == tappedNodeName)
        : null;

    if (tappedNode != null) {
      bool didRemoveNode = await arObjectManager!.removeNode(tappedNode);
      if (didRemoveNode) {
        nodes.remove(tappedNode);
        placedObjects.removeWhere((obj) => obj.node.name == tappedNode.name);

        setState(() {});
      } else {
        _showErrorDialog("Failed to remove node");
      }
    } else {
      _showErrorDialog("Tapped node not found");
    }
  }

  Future<void> sendLocationToServer(double lat, double long) async {
    try {
      final url = Uri.parse('http://192.168.0.81:3000/locations');
      final locationId = locationIdCounter++;
      final payload = {
        'id': locationId,
        'latitude': lat,
        'longitude': long,
        'timestamp': DateTime.now().toIso8601String(),
      };
      print('Sending data to $url: $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final responseData = jsonDecode(response.body);
      print('ID type: ${responseData['id'].runtimeType}');

      print("HTTP Response: ${response.statusCode}, body: ${response.body}");

      if (response.statusCode == 201) {
        print('Location sent successfully');
      } else {
        print('Failed to send location: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in sendLocationToServer: $e');
    }
  }


  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    print('onPlaneOrPointTapped clicked');

    var singleHitTestResult = hitTestResults.firstWhere(
          (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
    );

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    // Create anchor from hit test result
    var newAnchor = ARPlaneAnchor(
      transformation: singleHitTestResult.worldTransform,
    );

    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
    if (didAddAnchor!) {
      anchors.add(newAnchor);

      // Our model file
      String modelUrl = "https://github.com/pratyush-talentelgia/street-view-host/raw/refs/heads/main/direction_arrow.glb";

      // Create the AR object
      var newNode = ARNode(
        type: NodeType.webGLB,
        uri: modelUrl,
        scale: Vector3(8.0, 8.0, 8.0),
        position: Vector3(0.0, 0.0, 0.0),
        rotation: Vector4(1.0, 0.0, 0.0, 0.0),
      );

      bool? didAddNodeToAnchor = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );

      if (didAddNodeToAnchor!) {
        nodes.add(newNode);
        placedObjects.add(PlacedObject(
          node: newNode,
          latitude: position.latitude,
          longitude: position.longitude,
        ));
        setState(() {});

        // Prepare JSON payload for db.json
        final locationId = locationIdCounter++;
        final payload = {
          'id': locationId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'modelUrl': modelUrl,
          'scale': {
            'x': newNode.scale!.x,
            'y': newNode.scale!.y,
            'z': newNode.scale!.z
          },
          'position': {
            'x': newNode.position!.x,
            'y': newNode.position!.y,
            'z': newNode.position!.z
          },
          'rotation': (newNode.rotation is Vector4)
              ? (newNode.rotation as Vector4).toQuaternionMap()
              : (newNode.rotation).toQuaternionMap(),
          'anchorTransform': singleHitTestResult.worldTransform.toNestedList()
        };

        await sendObjectDataToServer(payload);

      } else {
        _showErrorDialog("Adding Node to Anchor failed");
      }
    } else {
      _showErrorDialog("Adding Anchor failed");
    }
  }

  Future<void> sendObjectDataToServer(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('http://192.168.0.81:3000/locations');
      print('Sending data to $url: $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        print('Object data saved successfully');
      } else {
        print('Failed to save object data: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in sendObjectDataToServer: $e');
    }
  }


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
      ),
    );
  }

}