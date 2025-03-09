import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart'; // เพิ่มการนำเข้า gal
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
  bool isRearCamera = true; // ใช้ตัวแปรนี้เพื่อสลับระหว่างกล้องหน้าและกล้องหลัง

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      // เริ่มต้นจากกล้องหลัง (กล้องที่ index 0)
      startCamera(0);
    } else {
      debugPrint("No cameras found.");
    }
  }

  // ฟังก์ชันขออนุญาตการเข้าถึง storage
  Future<void> requestPermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      debugPrint("Permission granted");
    } else {
      debugPrint("Permission denied");
    }
  }

  // ฟังก์ชันในการเริ่มต้นกล้อง
  void startCamera(int cameraIndex) {
    if (widget.cameras.isEmpty) return;

    cameraController?.dispose();
    cameraController = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    cameraValue = cameraController!
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((e) {
          debugPrint("Camera initialization error: $e");
        });
  }

  // ฟังก์ชันในการถ่ายรูป
  Future<void> takePicture() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint("Camera is not initialized.");
      return;
    }
    try {
      XFile image = await cameraController!.takePicture();

      // ลองบันทึกรูปในแกลเลอรี่
      await Gal.putImage(image.path); // ใช้ Gal ในการบันทึกรูป

      debugPrint("✅ Image saved to gallery: ${image.path}");
      setState(() {
        imagesList.add(image); // เพิ่มรูปในรายการภาพที่ถ่าย
      });
    } catch (e) {
      debugPrint("Error capturing image: $e");
    }
  }

  // ฟังก์ชันในการสลับกล้องหน้าและกล้องหลัง
  void switchCamera() {
    if (widget.cameras.length < 2) return; // ถ้ามีกล้องแค่ตัวเดียวไม่ให้สลับ
    isRearCamera = !isRearCamera; // เปลี่ยนสถานะกล้อง
    startCamera(
      isRearCamera ? 0 : 1,
    ); // เรียกใช้ฟังก์ชันเริ่มต้นกล้องใหม่ตามสถานะ
  }

  @override
  void dispose() {
    cameraController?.dispose(); // ปล่อยทรัพยากรก่อนออกจากหน้าจอ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white.withOpacity(0.7),
        shape: const CircleBorder(),
        onPressed: takePicture, // เมื่อกดปุ่มถ่ายภาพ
        child: const Icon(Icons.camera_alt, size: 40, color: Colors.black87),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  cameraController != null) {
                return SizedBox(
                  height: size.height,
                  width: size.width,
                  child: CameraPreview(cameraController!), // แสดงภาพจากกล้อง
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 10),
                child: GestureDetector(
                  onTap: switchCamera, // เมื่อกดเปลี่ยนกล้อง
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.switch_camera,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 7, bottom: 75),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagesList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(imagesList[index].path),
                          height: 100,
                          width: 100,
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