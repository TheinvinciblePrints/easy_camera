import 'dart:io';

import 'package:easy_camera/easy_camera.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyCamera.initialize(printLogs: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? currentFile;

  void _incrementCounter() async {
    // Create a CameraConfig instance with custom settings.
    CameraConfig config = CameraConfig(
      imageResolution: ImageResolution.high,
      defaultCameraType: CameraType.rear,
      showCameraTypeControl: true,
      cameraPreviewSize: CameraPreviewSize.normal,
      showFlashControl: true,
    );

    var file = await EasyCamera.selfieCameraFile(context, config);
    if (file != null) {
      setState(() {
        currentFile = File(file.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Easy Camera"),
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          color: Colors.blueAccent,
          child:
              currentFile != null
                  ? Image.file(currentFile!, fit: BoxFit.fitWidth)
                  : null,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
