import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainPage({super.key, required this.cameras});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  CameraController? cameraController;
  late Future<void> cameraValue;
  List<XFile> imagesList = [];
  bool isRearCamera = true;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      startCamera(0);
    } else {
      debugPrint("Not Cameras.");
    }
  }

  void startCamera(int cameraIndex) {
    if (widget.cameras.isEmpty) return;
    cameraController?.dispose();
    cameraController = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    cameraValue = cameraController!.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint("Camera initialization error: $e");
    });
  }

  Future<void> takePicture() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint("Camera is not initialized.");
      return;
    }
    try {
      XFile image = await cameraController!.takePicture();
      await Gal.putImage(image.path);
      debugPrint("✅ Image saved to gallery: ${image.path}");
      setState(() {
        imagesList.add(image);
      });
    } catch (e) {
      debugPrint("Error capturing image: $e");
    }
  }

  void switchCamera() {
    if (widget.cameras.length < 2) return;
    isRearCamera = !isRearCamera;
    startCamera(isRearCamera ? 0 : 1);
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && cameraController != null) {
                return SizedBox(
                  height: size.height,
                  width: size.width,
                  child: CameraPreview(cameraController!),
                );
              } else {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(),
                  GestureDetector(
                    onTap: switchCamera,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.switch_camera, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: takePicture,
                    child: const Icon(Icons.camera_alt, size: 30, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 75),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagesList.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imagesList[index].path),
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
