import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  String os = "";
  String ver = "";
  String model = "";
  String vendor = "";
  String board = "";
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    DeviceInfoPlugin dev = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo info = await dev.androidInfo;
      setState(() {
        os = "Android";
        ver = "Release ${info.version.release} (SDK ${info.version.sdkInt})";
        model = info.model;
        vendor = info.manufacturer;
        board = info.hardware;
        loading = false;
      });
    } else if (Platform.isIOS) {
      IosDeviceInfo info = await dev.iosInfo;
      setState(() {
        os = info.systemName;
        ver = info.systemVersion;
        model = info.name;
        vendor = "Apple";
        board = info.utsname.machine;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sensors & OS Info"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  "OS Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    title: Text("$vendor $model"),
                    subtitle: Text("Platform: $os\nVersion: $ver"),
                    isThreeLine: true,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Sensors Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                rowInfo(
                  "Accelerometer",
                  "sensors_plus",
                  "motherboard: $board\nDriver IC: Linear Acceleration",
                ),
                rowInfo(
                  "Gyroscope",
                  "sensors_plus",
                  "motherboard: $board\nDriver IC: Angular Velocity",
                ),
                rowInfo(
                  "GPS",
                  "geolocator",
                  "motherboard: $board\nEngine: Location Services Engine",
                ),
              ],
            ),
    );
  }

  Widget rowInfo(String name, String pkg, String model) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Package: $pkg\n$model"),
        isThreeLine: true,
      ),
    );
  }
}
