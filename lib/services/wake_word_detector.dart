import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

const int SAMPLE_RATE = 16000;
const int FRAME_SIZE = 512;
const int N_MFCC = 13;
const int N_FFT = 512;
const int N_MELS = 40;
const double PI = 3.141592653589793;

final List<double> MODEL_COEF = [
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

final double MODEL_INTERCEPT = -7.567937031834553;

class WakeWordDetector {
  final recorder = FlutterSoundRecorder();
  bool _isListening = false;
  Function(bool)? _onDetected;
  
  List<double> audioBuffer = [];
  int lastDetectionTime = 0;

  Future<void> init() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission denied');
    }
    
    await recorder.openRecorder();
    print("🧠 Wake word detector initialized!");
  }

  Future<void> listen(Function(bool detected) onDetected) async {
    _onDetected = onDetected;
    _isListening = true;

    print("🎧 Listening for wake word...");

    StreamController<Uint8List> audioStream = StreamController();

    audioStream.stream.listen((Uint8List data) {
      _processAudio(data);
    });

    await recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: audioStream.sink,
      sampleRate: SAMPLE_RATE,
      numChannels: 1,
    );
  }

  Future<void> stop() async {
    if (_isListening) {
      await recorder.stopRecorder();
      _isListening = false;
      print("🛑 Stopped listening");
    }
  }

  void _processAudio(Uint8List buffer) {
    // Convert PCM16 bytes to samples
    var intData = Int16List.view(buffer.buffer);
    List<double> samples = intData.map((e) => e.toDouble() / 32768.0).toList();
    
    // Add to buffer
    audioBuffer.addAll(samples);

    // When we have enough samples for MFCC extraction
    if (audioBuffer.length >= FRAME_SIZE) {
      List<double> frame = audioBuffer.sublist(0, FRAME_SIZE).toList();
      audioBuffer.removeRange(0, min(FRAME_SIZE ~/ 2, audioBuffer.length ~/ 2));

      // Extract MFCC features
      List<double> mfcc = _extractMFCC(frame);

      // Print for debugging
      print("🔊 MFCC Features: ${mfcc.map((v) => v.toStringAsFixed(4)).join(', ')}");

      // Predict
      bool detected = _predictScore(mfcc) > 0.0;
      print("   Predicted: $detected");

      if (detected) {
        int now = DateTime.now().millisecondsSinceEpoch;
        // Debounce: only trigger once per 2 seconds
        if (now - lastDetectionTime > 2000) {
          lastDetectionTime = now;
          _onDetected?.call(true);
        }
      }
    }
  }

  List<double> _extractMFCC(List<double> frame) {
    // Apply Hamming window
    List<double> windowed = _applyWindow(frame);

    // Compute FFT
    List<Complex> fft = _computeFFT(windowed);

    // Get magnitude spectrum
    List<double> magnitude = fft.map((c) => c.magnitude()).toList();

    // Apply mel-scale filterbank
    List<double> melSpec = _melFilterbank(magnitude);

    // Log compression
    List<double> logMel = melSpec.map((v) => log(max(v, 1e-10))).toList();

    // DCT to get MFCC
    List<double> mfcc = _dct(logMel);

    return mfcc.take(N_MFCC).toList();
  }

  List<double> _applyWindow(List<double> frame) {
    List<double> windowed = [];
    int n = frame.length;
    for (int i = 0; i < n; i++) {
      double window = 0.54 - 0.46 * cos(2 * PI * i / (n - 1));
      windowed.add(frame[i] * window);
    }
    return windowed;
  }

  List<Complex> _computeFFT(List<double> input) {
    List<Complex> x = input.map((v) => Complex(v, 0)).toList();
    int n = x.length;

    if (n == 1) return x;

    // Bit-reversal
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;

      if (i < j) {
        Complex temp = x[i];
        x[i] = x[j];
        x[j] = temp;
      }
    }

    // Cooley-Tukey FFT
    for (int len = 2; len <= n; len <<= 1) {
      double angle = -2 * PI / len;
      Complex wlen = Complex(cos(angle), sin(angle));

      for (int i = 0; i < n; i += len) {
        Complex w = Complex(1, 0);
        for (int j = 0; j < len / 2; j++) {
          Complex t = w * x[i + j + len ~/ 2];
          x[i + j + len ~/ 2] = x[i + j] - t;
          x[i + j] = x[i + j] + t;
          w = w * wlen;
        }
      }
    }

    return x;
  }

  List<double> _melFilterbank(List<double> magnitude) {
    List<double> melBins = [];

    for (int m = 0; m < N_MELS; m++) {
      double melFreq = 2595 * (log(1 + m * (SAMPLE_RATE / 2) / (2595 * 700)) / log(10));
      double binFreq = (melFreq / SAMPLE_RATE) * N_FFT;

      double energy = 0.0;
      int centerBin = binFreq.round();

      if (centerBin > 0 && centerBin < magnitude.length) {
        energy = magnitude[centerBin];
      }

      melBins.add(max(energy, 1e-10));
    }

    return melBins;
  }

  List<double> _dct(List<double> signal) {
    int n = signal.length;
    List<double> dct = List.filled(n, 0.0);

    for (int k = 0; k < n; k++) {
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        sum += signal[i] * cos((PI / n) * (i + 0.5) * k);
      }
      dct[k] = sum;
    }

    return dct;
  }

  double _predictScore(List<double> mfcc) {
    double score = 0.0;

    // Dot product: score = sum(mfcc[i] * coef[i]) + intercept
    for (int i = 0; i < min(mfcc.length, MODEL_COEF.length); i++) {
      score += mfcc[i] * MODEL_COEF[i];
    }

    score += MODEL_INTERCEPT;
    return score;
  }

  void dispose() {
    stop();
  }
}

class Complex {
  double real;
  double imag;

  Complex(this.real, this.imag);

  Complex operator +(Complex other) => Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) => Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(
    real * other.real - imag * other.imag,
    real * other.imag + imag * other.real
  );

  double magnitude() => sqrt(real * real + imag * imag);
}
