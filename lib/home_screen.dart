import 'package:ar_object_placer/objects.dart';
import 'package:ar_object_placer/retrive_object_screen.dart';
import 'package:flutter/material.dart';
import 'ar_object_placer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlacedObject? placedObject;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AR Object App')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ARObjectPlacerScreen()),
                );
              },
              child: Text("Place Object"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RetrieveObjectsScreen()),
                );
              },
              child: const Text("Retrieve Objects"),
            ),
          ],
        ),
      ),
    );
  }
}
