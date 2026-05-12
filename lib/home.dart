import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'logic.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  StreamSubscription<UserAccelerometerEvent>? accSub;
  StreamSubscription<GyroscopeEvent>? gyroSub;
  StreamSubscription<Position>? posSub;

  double speed = 0.0;
  double oldSpeed = 0.0;
  
  double acc = 0.0;
  double oldAcc = 0.0;
  
  double rotate = 0.0;
  double oldRotate = 0.0;

  String status = "Normal";
  Color color = Colors.green;
  
  int count = 10;
  int cooldown = 0;
  bool checking = false;

  Timer? timer;
  Timer? cooldownTimer;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    bool on = await Geolocator.isLocationServiceEnabled();
    if (!on) return;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }

    accSub = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double value = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() {
        oldAcc = acc;
        acc = value;
      });
      testAccident();
    });

    gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
      double value = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      setState(() {
        oldRotate = rotate;
        rotate = value;
      });
      testAccident();
    });

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
    posSub = Geolocator.getPositionStream(locationSettings: settings).listen((Position position) {
      setState(() {
        oldSpeed = speed;
        speed = position.speed * 3.6;
      });
      testAccident();
    });
  }

  void testAccident() {
    if (checking || status != "Normal" || cooldown > 0) return;

    bool isAccident = Logic.checkAccident(acc, oldAcc, rotate, oldRotate, speed, oldSpeed);

    if (isAccident) {
      trigger();
    }
  }

  void trigger() {
    setState(() {
      checking = true;
      status = "Checking Accident...";
      color = Colors.orange;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!checking) return;

      setState(() {
        checking = false;
        status = "Accident Detected!";
        color = Colors.red;
        count = 10;
      });

      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          if (count > 0) {
            count--;
          } else {
            status = "Emergency Sent";
            timer?.cancel();
          }
        });
      });
    });
  }

  void ok() {
    setState(() {
      status = "Normal";
      color = Colors.green;
      count = 10;
      checking = false;
      timer?.cancel();
      
      cooldown = 10;
      cooldownTimer?.cancel();
      cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          if (cooldown > 0) {
            cooldown--;
          } else {
            cooldownTimer?.cancel();
          }
        });
      });
    });
  }

  void sendSOS() {
    setState(() {
      checking = false;
      status = "Emergency Sent";
      color = Colors.red;
      timer?.cancel();
    });
  }

  void testBtn() {
    if (status == "Normal" && cooldown == 0) {
      trigger();
    }
  }

  @override
  void dispose() {
    accSub?.cancel();
    gyroSub?.cancel();
    posSub?.cancel();
    timer?.cancel();
    cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accident Detection"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: color,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            if (status == "Accident Detected!")
              Text(
                "Calling for help in: $count s",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            const SizedBox(height: 30),
            Text("Speed: ${speed.toStringAsFixed(2)} km/h", style: const TextStyle(fontSize: 18)),
            Text("Acc: ${acc.toStringAsFixed(2)} m/s²", style: const TextStyle(fontSize: 18)),
            Text("Rotate: ${rotate.toStringAsFixed(2)} rad/s", style: const TextStyle(fontSize: 18)),
            if (cooldown > 0)
              Text("Cooldown: $cooldown s", style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 40),
            
            if (status != "Normal") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(20)),
                    onPressed: ok,
                    child: const Text("I'M OK", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  if (status != "Emergency Sent")
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(20)),
                      onPressed: sendSOS,
                      child: const Text("SOS", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                ],
              ),
            ],
            
            const Spacer(),
            ElevatedButton(
              onPressed: testBtn,
              child: const Text("Simulate Accident (Demo)"),
            ),
          ],
        ),
      ),
    );
  }
}
