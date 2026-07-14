import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'face_match_service.dart' show FaceMatchException;

const String _modelAsset = 'assets/models/mobilefacenet.tflite';
const int _inputSize = 112;
const int _embeddingSize = 128;

Interpreter? _interpreter;

Future<double> compareFaceImages(Object selfie, Object idPhoto) async {
  if (selfie is! File || idPhoto is! File) {
    throw const FaceMatchException('Face matching requires local image files.');
  }
  final embeddings = await Future.wait([
    _getEmbedding(selfie),
    _getEmbedding(idPhoto),
  ]);
  return _cosineSimilarity(embeddings[0], embeddings[1]);
}

Future<List<double>> _getEmbedding(File faceImage) async {
  final face = await _detectSingleFace(faceImage);
  final decoded = img.decodeImage(await faceImage.readAsBytes());
  if (decoded == null) {
    throw const FaceMatchException('The image could not be decoded.');
  }

  final oriented = img.bakeOrientation(decoded);
  final crop = _cropFace(oriented, face.boundingBox);
  final resized = img.copyResize(crop, width: _inputSize, height: _inputSize);
  final input = _toModelInput(resized);
  final output = [List<double>.filled(_embeddingSize, 0)];

  final interpreter = await _loadInterpreter();
  final outputShape = interpreter.getOutputTensor(0).shape;
  if (outputShape.length != 2 || outputShape.last != _embeddingSize) {
    throw const FaceMatchException(
      'The bundled MobileFaceNet model must output 128 values.',
    );
  }
  interpreter.run(input, output);
  return _l2Normalize(output.single);
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != _embeddingSize || b.length != _embeddingSize) {
    throw const FaceMatchException('Face embeddings must contain 128 values.');
  }
  var dot = 0.0;
  var aMagnitude = 0.0;
  var bMagnitude = 0.0;
  for (var index = 0; index < a.length; index++) {
    dot += a[index] * b[index];
    aMagnitude += a[index] * a[index];
    bMagnitude += b[index] * b[index];
  }
  if (aMagnitude == 0 || bMagnitude == 0) return 0;
  return (dot / math.sqrt(aMagnitude * bMagnitude)).clamp(0.0, 1.0);
}

Future<Interpreter> _loadInterpreter() async {
  return _interpreter ??= await Interpreter.fromAsset(_modelAsset);
}

Future<Face> _detectSingleFace(File image) async {
  final detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: false,
      enableLandmarks: false,
    ),
  );
  try {
    final faces = await detector.processImage(InputImage.fromFile(image));
    if (faces.isEmpty) {
      throw const FaceMatchException('No face was found in the image.');
    }
    if (faces.length != 1) {
      throw const FaceMatchException(
        'Use an image containing exactly one visible face.',
      );
    }
    return faces.single;
  } finally {
    await detector.close();
  }
}

img.Image _cropFace(img.Image image, Rect box) {
  const padding = 0.18;
  final paddingX = box.width * padding;
  final paddingY = box.height * padding;
  final left = math.max(0, (box.left - paddingX).floor());
  final top = math.max(0, (box.top - paddingY).floor());
  final right = math.min(image.width, (box.right + paddingX).ceil());
  final bottom = math.min(image.height, (box.bottom + paddingY).ceil());
  if (right <= left || bottom <= top) {
    throw const FaceMatchException('The detected face could not be cropped.');
  }
  return img.copyCrop(
    image,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
}

List<List<List<List<double>>>> _toModelInput(img.Image image) {
  return [
    List.generate(
      _inputSize,
      (y) => List.generate(_inputSize, (x) {
        final pixel = image.getPixel(x, y);
        return [
          (pixel.r - 127.5) / 128.0,
          (pixel.g - 127.5) / 128.0,
          (pixel.b - 127.5) / 128.0,
        ];
      }),
    ),
  ];
}

List<double> _l2Normalize(List<double> embedding) {
  final magnitude = math.sqrt(
    embedding.fold<double>(0, (sum, value) => sum + value * value),
  );
  if (magnitude == 0) {
    throw const FaceMatchException('Face embedding was empty.');
  }
  return embedding.map((value) => value / magnitude).toList(growable: false);
}
