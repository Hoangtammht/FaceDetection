import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(camera: camera),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final CameraDescription camera;

  const MyHomePage({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection App'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CameraPage(camera: camera)),
            );
          },
          child: const Text('Open Camera'),
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({Key? key, required this.camera}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFaceDetected = false;
  File? _capturedImage;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    await _controller?.initialize();
    setState(() {
      _isCameraInitialized = true;
    });

    _controller?.startImageStream((CameraImage image) async {
      await _detectFaces(image);
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final InputImageFormat inputImageFormat = InputImageFormat.yuv_420_888;

    final planeData = image.planes.map(
          (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: InputImageRotation.rotation0deg,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );

    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty && !_isFaceDetected) {
      setState(() {
        _isFaceDetected = true;
      });
      await _takePicture();
    }
  }

  Future<void> _takePicture() async {
    if (_controller?.value.isInitialized ?? false) {
      final XFile image = await _controller!.takePicture();
      setState(() {
        _capturedImage = File(image.path);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Camera'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Go back to the previous screen
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: _isCameraInitialized
            ? Column(
          children: [
            if (_capturedImage != null) Image.file(_capturedImage!),
            Expanded(
              child: CameraPreview(_controller!),
            ),
            if (!_isFaceDetected)
              const Text('No face detected, keep trying...'),
          ],
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
