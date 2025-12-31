import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nirman Voice Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VoiceAssistantPage(),
    );
  }
}

class VoiceAssistantPage extends StatefulWidget {
  const VoiceAssistantPage({super.key});

  @override
  State<VoiceAssistantPage> createState() => _VoiceAssistantPageState();
}

class _VoiceAssistantPageState extends State<VoiceAssistantPage> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  String _statusText = 'Initializing...';
  bool _isListening = false;
  bool _hasResponded = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _initializeAndStart();
  }

  Future<void> _initializeAndStart() async {
    await _requestPermissions();
    await _initializeSpeech();
    await _initializeTts();

    if (!_hasResponded) {
      await _startListening();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _statusText = 'Requesting microphone permission...';
    });

    final status = await Permission.microphone.request();
    if (status.isGranted) {
      setState(() {
        _statusText = 'Permission granted';
      });
    } else {
      setState(() {
        _statusText = 'Microphone permission denied';
      });
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          setState(() {
            _statusText = 'Error: ${error.errorMsg}';
            _isListening = false;
          });
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      if (!available) {
        setState(() {
          _statusText = 'Speech recognition not available';
        });
      }
    } catch (e) {
      setState(() {
        _statusText = 'Failed to initialize speech: $e';
      });
    }
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _startListening() async {
    if (_hasResponded) {
      return;
    }

    if (!_speechToText.isAvailable) {
      setState(() {
        _statusText = 'Speech recognition not available';
      });
      return;
    }

    setState(() {
      _statusText = 'Listening for "Hey Nirman"...';
      _isListening = true;
      _recognizedText = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        if (result.recognizedWords.toLowerCase().contains('hey nirman')) {
          _handleWakeWordDetected();
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );

    Future.delayed(const Duration(seconds: 8), () {
      if (_isListening && !_hasResponded) {
        _speechToText.stop();
        setState(() {
          _isListening = false;
          _statusText = 'Listening timeout - No wake word detected';
        });
      }
    });
  }

  Future<void> _handleWakeWordDetected() async {
    if (_hasResponded) {
      return;
    }

    await _speechToText.stop();

    setState(() {
      _hasResponded = true;
      _isListening = false;
      _statusText = 'Wake word detected! Responding...';
    });

    await Future.delayed(const Duration(milliseconds: 300));

    await _flutterTts.speak('Hello, how can I help you');

    setState(() {
      _statusText = 'Response completed';
    });
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  size: 100,
                  color: _isListening ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 40),
                Text(
                  'Nirman Voice Assistant',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Status:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (_recognizedText.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Recognized:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recognizedText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue[900],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Text(
                  'Say "Hey Nirman" to activate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
