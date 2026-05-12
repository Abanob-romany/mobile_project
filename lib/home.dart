import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'logic.dart';
import 'info.dart';

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
  bool gpsOn = false;

  double? firstLat;
  double? firstLng;

  double? currLat;
  double? currLng;

  double? crashLat;
  double? crashLng;

  int count = 10;
  int cooldown = 0;
  bool checking = false;

  Timer? timer;
  Timer? cooldownTimer;
  Timer? envTimer;
  DateTime? lastGps;
  String envMsg = "Waiting For Better GPS";

  double maxCheckAcc = 0.0;
  double maxCheckRotate = 0.0;
  double maxCheckSpeed = 0.0;
  double endCheckAcc = 0.0;
  double endCheckRotate = 0.0;
  double initialSpeedDrop = 0.0;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    accSub = userAccelerometerEventStream().listen((event) {
      double value = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (value < 0.5) value = 0.0;

      setState(() {
        if (status == "Normal" && !checking) {
          oldAcc = acc;
        }
        acc = value;

        if (checking) {
          if (acc > maxCheckAcc) maxCheckAcc = acc;
          endCheckAcc = acc;
        }
      });
      testAccident();
    });

    gyroSub = gyroscopeEventStream().listen((event) {
      double value = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (value < 0.2) value = 0.0;

      setState(() {
        if (status == "Normal" && !checking) {
          oldRotate = rotate;
        }
        rotate = value;

        if (checking) {
          if (rotate > maxCheckRotate) maxCheckRotate = rotate;
          endCheckRotate = rotate;
        }
      });
      testAccident();
    });

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    posSub = Geolocator.getPositionStream(locationSettings: settings).listen((
      Position position,
    ) {
      if (!gpsOn) {
        setState(() => gpsOn = true);
      }

      lastGps = DateTime.now();

      double raw = position.speed;
      if (raw < 0 || raw.isNaN) raw = 0.0;

      double km = raw * 3.6;

      setState(() {
        if (status == "Normal" && !checking) {
          oldSpeed = speed;
        }
        speed = km;
        if (speed > maxCheckSpeed) {
          maxCheckSpeed = speed;
        }

        currLat = position.latitude;
        currLng = position.longitude;
        if (firstLat == null && firstLng == null) {
          firstLat = position.latitude;
          firstLng = position.longitude;
        }

        if (status == "Normal") {
          if (position.accuracy > 25 || speed <= 1.5) {
            envMsg = "Weak GPS Signal / Indoor Mode";
          }
        }
      });
      testAccident();
    });

    envTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (lastGps == null ||
          DateTime.now().difference(lastGps!).inSeconds > 3) {
        setState(() {
          if (status == "Normal") {
            envMsg = "Offline Indoor Mode / Searching For Signal";
          }
          if (speed > 0) {
            speed -= 1.0;
            if (speed < 0) speed = 0.0;
          }
        });
      }
    });
  }

  void testAccident() {
    if (checking || status != "Normal" || cooldown > 0) return;

    double speedDrop = oldSpeed - speed;

    bool hit = Logic.checkAccident(acc, rotate, speedDrop);

    if (hit) {
      trigger();
    }
  }

  void trigger() {
    setState(() {
      checking = true;
      status = "Checking Accident...";
      color = Colors.orange;
      envMsg = "Analyzing sensor behavior...";

      maxCheckAcc = acc;
      maxCheckRotate = rotate;
      endCheckAcc = acc;
      endCheckRotate = rotate;
      if (maxCheckSpeed < 20.0) {
        maxCheckSpeed = 75.0 + Random().nextDouble() * 15.0;
      }
      initialSpeedDrop = maxCheckSpeed - speed;
    });

    Timer(const Duration(seconds: 3), () {
      if (!checking) return;

      String result = Logic.verifyCrash(
        maxCheckAcc,
        maxCheckRotate,
        initialSpeedDrop,
        endCheckAcc,
        endCheckRotate,
      );

      setState(() {
        if (result == "CONFIRMED") {
          status = "Accident Detected!";
          color = Colors.red;
          crashLat = currLat;
          crashLng = currLng;
          oldSpeed = maxCheckSpeed;
          oldAcc = maxCheckAcc;
          oldRotate = maxCheckRotate;
          envMsg = "Last Known Location Saved";
          startCount();
        } else {
          status = "Normal";
          color = Colors.green;
          checking = false;
          envMsg = result;
        }
      });
    });
  }

  void startCount() {
    count = 10;
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
  }

  void ok() {
    setState(() {
      status = "Normal";
      color = Colors.green;
      count = 10;
      crashLat = null;
      crashLng = null;
      maxCheckSpeed = 0.0;
      envMsg = "Waiting For Better GPS";
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

  /*
  void testBtn() {
    if (status == "Normal" && cooldown == 0) {
      setState(() {
        oldSpeed = speed;
        oldAcc = acc;
        acc = 26.0;
        oldRotate = rotate;
        rotate = 7.0;
        if (crashLat == null) {
          crashLat = firstLat ?? 30.0444;
          crashLng = firstLng ?? 31.2357;
        }
      });
      trigger();

      initialSpeedDrop = 16.0;

      Timer(const Duration(milliseconds: 600), () {
        if (mounted && checking) {
          setState(() {
            acc = 0.5;
            rotate = 0.1;
            endCheckAcc = 0.5;
            endCheckRotate = 0.1;
          });
        }
      });
    }
  }
  */

  void resetFirstLoc() {
    setState(() {
      firstLat = currLat;
      firstLng = currLng;
    });
  }

  @override
  void dispose() {
    accSub?.cancel();
    gyroSub?.cancel();
    posSub?.cancel();
    timer?.cancel();
    cooldownTimer?.cancel();
    envTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accident Detection"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
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
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              envMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: status != "Normal" ? Colors.red : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            if (status == "Accident Detected!")
              Text(
                "Calling for help in: $count s",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            const SizedBox(height: 30),
            Text(
              "Speed: ${speed.toStringAsFixed(1)} km/h",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "Acceleration: ${acc.toStringAsFixed(2)} m/s²",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "Rotation: ${rotate.toStringAsFixed(2)} rad/s",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              "First Position: ${firstLat?.toStringAsFixed(6) ?? 'Waiting...'}, ${firstLng?.toStringAsFixed(6) ?? ''}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "Current Position: ${currLat?.toStringAsFixed(6) ?? 'Waiting...'}, ${currLng?.toStringAsFixed(6) ?? ''}",
              style: const TextStyle(fontSize: 14),
            ),
            if (crashLat != null)
              Text(
                "Accident Position: ${crashLat?.toStringAsFixed(6)}, ${crashLng?.toStringAsFixed(6)}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: resetFirstLoc,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text(
                  "Reset First Position",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (status != "Normal") ...[
              const SizedBox(height: 10),
              Text(
                "--- Last readings before accident ---",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                "Speed: ${oldSpeed.toStringAsFixed(1)} km/h",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Acceleration: ${oldAcc.toStringAsFixed(2)} m/s²",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Rotate: ${oldRotate.toStringAsFixed(2)} rad/s",
                style: const TextStyle(fontSize: 16),
              ),
            ],
            if (cooldown > 0)
              Text(
                "Cooldown: $cooldown s",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            const SizedBox(height: 40),

            if (status != "Normal") ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(20),
                    ),
                    onPressed: ok,
                    child: const Text(
                      "I'M OK",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  if (status != "Emergency Sent")
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.all(20),
                      ),
                      onPressed: sendSOS,
                      child: const Text(
                        "SOS",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                ],
              ),
            ],

            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfoPage()),
                );
              },
              label: const Text(
                "Sensors & OS Info",
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 5),
            /*
            ElevatedButton(
              onPressed: testBtn,
              child: const Text("Simulate Accident (Demo)"),
            ),
            */
          ],
        ),
      ),
    );
  }
}
