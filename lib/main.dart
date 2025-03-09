import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gal/gal.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get available cameras
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing camera: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Store a list of images instead of just the last one
  final List<File> _capturedImages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _capturedImages.isEmpty
          ? const Center(
              child: Text('Tap the button to take a picture!'),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _capturedImages.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      // Show full-screen image when tapped
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            imagePath: _capturedImages[index].path,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _capturedImages[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final XFile? capturedImage = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(cameras: cameras),
            ),
          );

          if (capturedImage != null) {
            setState(() {
              _capturedImages.add(File(capturedImage.path));
            });
          }
        },
        tooltip: 'Take a Picture',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// Add a new screen to view images in full screen
class FullScreenImageView extends StatelessWidget {
  final String imagePath;

  const FullScreenImageView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo View'),
      ),
      body: Center(
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRearCameraSelected = true;

  @override
  void initState() {
    super.initState();
    // Initialize the camera controller
    _initCamera(widget.cameras[0]);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Picture'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview
            return Column(
              children: [
                Expanded(
                  child: CameraPreview(_controller),
                ),
              ],
            );
          } else {
            // Otherwise, display a loading indicator
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Switch camera button
          FloatingActionButton(
            heroTag: 'switchCamera',
            onPressed: () {
              setState(() {
                _isRearCameraSelected = !_isRearCameraSelected;
                int cameraIndex = _isRearCameraSelected ? 0 : 1;
                if (widget.cameras.length > cameraIndex) {
                  _initCamera(widget.cameras[cameraIndex]);
                }
              });
            },
            child: const Icon(Icons.flip_camera_ios),
          ),
          // Take picture button
          FloatingActionButton(
            heroTag: 'takePicture',
            onPressed: () async {
              try {
                // Ensure that the camera is initialized
                await _initializeControllerFuture;

                // Take the picture
                final image = await _controller.takePicture();

                // Save the image to the gallery using gal package
                await Gal.putImage(image.path);

                if (!mounted) return;

                // Show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Picture saved to gallery!'),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Return to home screen with the image
                Navigator.pop(context, image);
              } catch (e) {
                // If an error occurs, log the error to the console
                print('Error taking picture: $e');
              }
            },
            child: const Icon(Icons.camera),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}