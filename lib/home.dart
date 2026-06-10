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

  String status = "normal";
  Color color = Colors.green;

  double? firstLat;
  double? firstLng;

  double? currLat;
  double? currLng;

  double? crashLat;
  double? crashLng;
  String? crashTime;

  int count = 10;
  int cooldown = 0;
  bool checking = false;

  Timer? timer;
  Timer? cooldownTimer;
  Timer? envTimer;
  Timer? checkTimer;
  DateTime? lastGps;
  String envMsg = "";

  double maxCheckAcc = 0.0;
  double maxCheckRotate = 0.0;
  double maxCheckSpeed = 0.0;
  double endCheckAcc = 0.0;
  double endCheckRotate = 0.0;
  double initialSpeedDrop = 0.0;

  double? lastReliableLat;
  double? lastReliableLng;

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
        if (status == "normal" && !checking) {
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
        if (status == "normal" && !checking) {
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
    }

    posSub =
        Geolocator.getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        ).listen((Position position) {
          lastGps = DateTime.now();
          double ms = position.speed;
          double kmh = ms * 3.6;
          bool isReliable = position.accuracy > 0 && position.accuracy <= 25.0;

          setState(() {
            if (isReliable) {
              if (firstLat == null && firstLng == null) {
                firstLat = position.latitude;
                firstLng = position.longitude;
              }
              currLat = position.latitude;
              currLng = position.longitude;
              lastReliableLat = position.latitude;
              lastReliableLng = position.longitude;
            }

            if (status == "normal" && !checking) {
              oldSpeed = speed;
            }
            speed = kmh;
            if (speed > maxCheckSpeed) {
              maxCheckSpeed = speed;
            }

            if (status == "normal") {
              if (!isReliable) {
                envMsg = "weak GPS signal / indoor mode";
              } else {
                envMsg = "GPS signal ok";
              }
            }
          });
        });

    envTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (lastGps == null ||
          DateTime.now().difference(lastGps!).inSeconds > 3) {
        setState(() {
          if (status == "normal") {
            envMsg = "weak GPS signal / indoor mode";
          }
        });
      }
    });
  }

  void testAccident() {
    if (checking || status != "normal" || cooldown > 0) return;

    bool hit = Logic.checkAccident(acc, rotate);

    if (hit) {
      trigger();
    }
  }

  void trigger() {
    setState(() {
      checking = true;
      status = "checking accedant";
      color = Colors.orange;

      maxCheckAcc = acc;
      maxCheckRotate = rotate;
      endCheckAcc = acc;
      endCheckRotate = rotate;

      maxCheckSpeed = max(speed, oldSpeed);
      initialSpeedDrop = maxCheckSpeed - speed;
    });

    checkTimer?.cancel();
    checkTimer = Timer(const Duration(seconds: 3), () {
      if (!checking) return;

      double speedDrop = maxCheckSpeed - speed;

      String result = Logic.verifyCrash(maxCheckAcc, maxCheckRotate, speedDrop);

      setState(() {
        if (result == "confirmed") {
          status = "accedant detected!";
          color = Colors.red;
          crashLat = lastReliableLat ?? currLat;
          crashLng = lastReliableLng ?? currLng;
          crashTime =
              "${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
          oldSpeed = maxCheckSpeed;
          oldAcc = maxCheckAcc;
          oldRotate = maxCheckRotate;

          count = 10;
          timer?.cancel();
          timer = Timer.periodic(const Duration(seconds: 1), (t) {
            setState(() {
              count--;
              if (count <= 0) {
                status = "emergency sent";
                timer?.cancel();
              }
            });
          });
        } else {
          status = "normal";
          color = Colors.green;
          checking = false;
          envMsg = result;
        }
      });
    });
  }

  void ok() {
    setState(() {
      status = "normal";
      color = Colors.green;
      count = 10;
      crashLat = null;
      crashLng = null;
      crashTime = null;
      maxCheckSpeed = 0.0;
      envMsg = "waiting for better GPS";
      checking = false;
      timer?.cancel();
      checkTimer?.cancel();

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
      status = "emergency sent";
      color = Colors.red;
      timer?.cancel();
      checkTimer?.cancel();
    });
  }

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
    checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("accedent detection"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                color: status != "normal" ? Colors.red : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            if (status == "accedent detected!")
              Text(
                "calling help in: $count s",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            const SizedBox(height: 30),
            Text(
              "speed: ${speed.toStringAsFixed(1)} km/h",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "accelaration: ${acc.toStringAsFixed(2)} m/s²",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "rotation: ${rotate.toStringAsFixed(2)} rad/s",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 15),
            Text(
              "first position: ${firstLat?.toStringAsFixed(6) ?? 'waiting...'}, ${firstLng?.toStringAsFixed(6) ?? ''}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "current position: ${currLat?.toStringAsFixed(6) ?? 'waiting...'}, ${currLng?.toStringAsFixed(6) ?? ''}",
              style: const TextStyle(fontSize: 14),
            ),
            if (crashLat != null)
              Text(
                "accedant position: ${crashLat?.toStringAsFixed(6)}, ${crashLng?.toStringAsFixed(6)}",
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
                  "reset first position",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            if (status != "normal") ...[
              const SizedBox(height: 10),
              Text(
                "last readings before accedant",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (crashTime != null)
                Text("time: $crashTime", style: const TextStyle(fontSize: 16)),
              Text(
                "speed: ${oldSpeed.toStringAsFixed(1)} km/h",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "accelaration: ${oldAcc.toStringAsFixed(2)} m/s²",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "rotation: ${oldRotate.toStringAsFixed(2)} rad/s",
                style: const TextStyle(fontSize: 16),
              ),
            ],
            if (cooldown > 0)
              Text(
                "cooldown: $cooldown s",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            const SizedBox(height: 40),

            if (status != "normal") ...[
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
                      "I'm ok",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  if (status != "emergency sent")
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

            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfoPage()),
                );
              },
              label: const Text(
                "sensors & info",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
