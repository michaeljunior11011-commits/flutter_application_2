import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CounterScreen(),
    );
  }
}

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int counter = 0;

  void increaseCounter() {
    // اهتزاز خفيف من Taptic Engine في الآيفون
    HapticFeedback.lightImpact();

    setState(() {
      counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$counter',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: increaseCounter,
                child: const Text('+1'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}