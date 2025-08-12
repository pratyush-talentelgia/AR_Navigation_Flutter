class LocationData {
  final int id;
  final double latitude;
  final double longitude;
  final String modelUrl;

  LocationData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.modelUrl,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      modelUrl: json['modelUrl'] ?? '',
    );
  }
}
