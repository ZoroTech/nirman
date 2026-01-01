import 'package:flutter/material.dart';
import 'services/wake_word_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final detector = WakeWordDetector();
  String status = "Initializing...";

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    await detector.init();
    detector.listen((detected) {
      setState(() {
        status = detected ? "🟢 HEY NIRMAN DETECTED" : "🎧 Listening...";
      });

      if (detected) {
        print("🔥 WAKEWORD TRIGGERED: HEY NIRMAN!");
      }
    });

    setState(() => status = "🎧 Listening...");
  }

  @override
  void dispose() {
    detector.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          status,
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
