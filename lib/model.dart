import 'package:ar_flutter_plugin_2/models/ar_node.dart';

class PlacedObject {
  final ARNode node;
  final double latitude;
  final double longitude;

  PlacedObject({
    required this.node,
    required this.latitude,
    required this.longitude,
  });
}
//npx json-server --watch db.json --port 3000
