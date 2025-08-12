import 'dart:async';
import 'dart:convert';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vector_math/vector_math_64.dart' as vector;
import 'location_data.dart';

class ArObjectViewScreen extends StatefulWidget {
  const ArObjectViewScreen({super.key});

  @override
  ArObjectViewScreenState createState() => ArObjectViewScreenState();
}

class ArObjectViewScreenState extends State<ArObjectViewScreen> {
  late ARKitController arkitController;
  final List<Timer> rotationTimers = [];
  bool anchorWasFound = false;
  List<LocationData> locations = [];

  @override
  void initState() {
    super.initState();
    loadLocations();
  }

  @override
  void dispose() {
    for (final timer in rotationTimers) {
      timer.cancel();
    }
    arkitController.dispose();
    super.dispose();
  }

  Future<void> loadLocations() async {
    try {
      final fetchedLocations = await fetchLocations();
      setState(() {
        locations = fetchedLocations;
      });
    } catch (e) {
      debugPrint('Error fetching locations: $e');
    }
  }

  Future<List<LocationData>> fetchLocations() async {
    final url = Uri.parse('http://192.168.0.81:3000/locations');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => LocationData.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image Detection Sample')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        ARKitSceneView(
          detectionImages: const [
            ARKitReferenceImage(
              name:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/OSIRIS_Mars_true_color.jpg/800px-OSIRIS_Mars_true_color.jpg',
              physicalWidth: 0.2,
            ),
          ],
          onARKitViewCreated: onARKitViewCreated,
        ),
        anchorWasFound
            ? Container()
            : Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Point the camera at Mars photo from the article about Mars on Wikipedia.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    this.arkitController.onAddNodeForAnchor = onAnchorWasFound;
  }

  void onAnchorWasFound(ARKitAnchor anchor) {
    if (anchor is ARKitImageAnchor) {
      setState(() => anchorWasFound = true);

      final basePosition = anchor.transform.getColumn(3);

      for (int i = 0; i < locations.length; i++) {
        final loc = locations[i];

        if (loc.modelUrl.isEmpty) {
          debugPrint('Skipping location id ${loc.id} due to empty modelUrl');
          continue;
        }

        final material = ARKitMaterial(
          lightingModelName: ARKitLightingModel.lambert,
          diffuse: ARKitMaterialProperty.image("https://github.com/pratyush-talentelgia/street-view-host/raw/refs/heads/main/direction_arrow.glb"),
        );

        final sphere = ARKitSphere(
          materials: [material],
          radius: 0.01,
        );

        final offset = 0.12 * i;

        final nodePosition = vector.Vector3(
          basePosition.x + offset,
          basePosition.y,
          basePosition.z,
        );

        final node = ARKitNode(
          geometry: sphere,
          position: nodePosition,
          eulerAngles: vector.Vector3.zero(),
        );

        arkitController.add(node);

        // Rotating animation for each sphere
        final timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          final old = node.eulerAngles;
          final eulerAngles = vector.Vector3(old.x + 0.01, old.y, old.z);
          node.eulerAngles = eulerAngles;
        });

        rotationTimers.add(timer);
      }
    }
  }
}
