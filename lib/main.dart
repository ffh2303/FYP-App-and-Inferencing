import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:drowsee/objectdetector.dart';

List<CameraDescription> cameras;
var labels, colors;

Future<void> main() async {
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }
  await _loadModel();
  runApp(ObjectDetectApp());
}

Future<Null> _loadModel() async {
  try {
    const platform = const MethodChannel('ffh.fyp/tensorflow');
    // post processing config like max result and confidence 
    // threshold to filter.

    var jsonString = await rootBundle.loadString('assets/model.meta');
    var metaData = json.decode(jsonString);
    labels = metaData["labels"];
    colors = metaData["colors"];
    metaData["blockSize"] = 32;
    metaData["threshold"] = 0.5;
    metaData["overlap_threshold"] = 0.7;
    metaData["max_result"] = 15;

    final String result = await platform.invokeMethod('loadModel',
        {"model_path": "assets/model.lite", "meta_data": metaData});
    print(result);
  } on PlatformException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }
}

class ObjectDetectApp extends StatefulWidget {
  @override
  _ObjectDetectAppState createState() => new _ObjectDetectAppState();
}

class _ObjectDetectAppState extends State<ObjectDetectApp>
    with WidgetsBindingObserver {
  final ObjectDetector detector = ObjectDetector.instance;
  CameraController controller;
  GlobalKey _keyCameraPreview = GlobalKey();
  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      detector.addListener(() {
        setState(() {});
      });
      detector.init(controller);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller?.dispose();
    detector.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    controller?.dispose();
    detector.dispose();
    super.dispose();
  }

/* Below is the widget for the UI of the app */
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        theme: ThemeData(primarySwatch: Colors.blue[900]),
        home: Scaffold(
            appBar: AppBar(
                title: Center(
              child: Text('Drowsee'),
            )),
            body: new Center(
              child: Column(children: [
                _cameraPreviewWidget(detector.value),
              ]),
            )));
  }

  Widget _cameraPreviewWidget(List value) {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Loading Camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {

      return new Stack(alignment: FractionalOffset.center, children: <Widget>[
        new AspectRatio(
            key: _keyCameraPreview,
            aspectRatio: controller.value.aspectRatio,
            child: new CameraPreview(controller)),
        new Positioned.fill(
            child: new CustomPaint(
          painter: new DrawObjects(value, _keyCameraPreview),
        )),
      ]);
    }

  }
}

class DrawObjects extends CustomPainter {
  List values;
  GlobalKey<State<StatefulWidget>> keyCameraPreview;
  DrawObjects(this.values, this.keyCameraPreview);

  @override
  void paint(Canvas canvas, Size size) {
    print(values);
    if (values==null && values.isNotEmpty && values[0] == null) return;
    final RenderBox renderPreview =
        keyCameraPreview.currentContext.findRenderObject();
    final sizeRed = renderPreview.size;

    var ratioW = sizeRed.width / 416;
    var ratioH = sizeRed.height / 416;
    for (var value in values) {
      var index = value["classIndex"];
      var rgb = colors[index];
      Paint paint = new Paint();
      paint.color =new Color.fromRGBO(rgb[0].toInt(), rgb[1].toInt(), rgb[2].toInt(), 1);
      paint.strokeWidth = 2;
      var rect = value["rect"];
      double x1 = rect["left"] * ratioW,
          x2 = rect["right"] * ratioW,
          y1 = rect["top"] * ratioH,
          y2 = rect["bottom"] * ratioH;
      TextSpan span = new TextSpan(
          style: new TextStyle(
              color: Colors.black,
              background: paint,
              fontWeight: FontWeight.bold,
              fontSize: 14),
          text: " " +labels[index] +" " +(value["confidence"] * 100).round().toString() +" % ");
      TextPainter tp = new TextPainter(text: span, textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, new Offset(x1 + 1, y1 + 1));
      canvas.drawLine(new Offset(x1, y1), new Offset(x2, y1), paint);
      canvas.drawLine(new Offset(x1, y1), new Offset(x1, y2), paint);
      canvas.drawLine(new Offset(x1, y2), new Offset(x2, y2), paint);
      canvas.drawLine(new Offset(x2, y1), new Offset(x2, y2), paint);
    }

  }

  @override
  bool shouldRepaint(DrawObjects oldDelegate) {
    return true;
  }
}