import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

// ===== Model Parameters (From wakeword.json) =====
final List<double> coef = [
  -0.02946827256365031,
  -0.006721349937844595,
  0.007676884461046702,
  0.0019390733158194152,
  0.002940298585363293,
  -0.00035460413178971424,
  0.004847766107488487,
  -0.01694796123569196,
  0.008129066813983912,
  -0.016456740103747723,
  -0.0021599734108277654,
  -0.0203771957915497,
  0.0007093770777296563
];

final double intercept = -7.567937031834553;

class WakeWordDetector {
  /// JSON model fields
  late List<double> weights;
  late double bias;

  /// Recorder
  final recorder = FlutterSoundRecorder();
  bool _isListening = false;

  /// callback when detection happens
  Function(bool)? _onDetected;

  /// Initialize
  Future<void> init() async {
    await Permission.microphone.request();
    await recorder.openRecorder();

    await loadModel();
    print("🧠 Wake word model loaded!");
  }

  /// Load JSON model
  Future<void> loadModel() async {
    final data = await rootBundle.loadString("assets/models/wakeword.json");
    final json = jsonDecode(data);

    weights = List<double>.from(json["coef"][0]);
    bias = double.parse(json["intercept"][0].toString());
  }

  /// Start listening
  Future<void> listen(Function(bool detected) onDetected) async {
    _onDetected = onDetected;
    _isListening = true;

    print("🎧 Listening for wake word...");

    // Create a stream to handle audio chunks
    StreamController<Uint8List> audioStream = StreamController();

    audioStream.stream.listen((Uint8List data) {
      _processAudio(data);
    });

    await recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: audioStream.sink, // 👈 FIXED
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  /// Stop listening
  Future<void> stop() async {
    if (_isListening) {
      await recorder.stopRecorder();
      _isListening = false;
      print("🛑 Recorder stopped");
    }
  }

  /// Extract features (simple energy for now)
  double _extractFeature(List<int> audio) {
    double energy = 0;
    for (var i = 0; i < audio.length; i += 2) {
      int sample = (audio[i] | (audio[i + 1] << 8));
      energy += sample * sample;
    }
    return energy / audio.length;
  }

  /// Convert raw byte stream to samples
  List<int> _toInt16List(dynamic buffer) {
    final List<int> bytes = List<int>.from(buffer);
    return bytes;
  }

  /// Prediction using logistic regression
  bool _predict(double feature) {
    // Using average coefficient since we only extracted 1 feature (energy)
    double avgCoef = coef.reduce((a, b) => a + b) / coef.length;
    double score = (avgCoef * feature) + intercept;

    return score > 0;
  }



  /// Handle incoming audio frames
  void _processAudio(Uint8List buffer) {
    // Convert PCM16 buffer ➜ List of samples (-32768 to 32767)
    var intData = Int16List.view(buffer.buffer);
    List<double> samples = intData.map((e) => e.toDouble()).toList();

    // Same style feature as python librosa.energy
    double energy = 0;
    for (var s in samples) {
      energy += s * s;
    }
    energy = energy / samples.length; // normalize

    bool detected = _predict(energy);

    print("🔊 Energy = $energy → Detected: $detected");

    if (detected && _onDetected != null) {
      _onDetected!(true);
    }
  }


}
