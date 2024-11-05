import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectToEsp32 {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? device;
  String data = "No data";
  StreamSubscription<List<ScanResult>>? subscription;
  void scanForDevices(Function action) async {
    await requestPermissions();

    if (await flutterBlue.isOn) {
      log("Bluetooth is on");
      try {
        flutterBlue.startScan(timeout: const Duration(seconds: 4));

        subscription = flutterBlue.scanResults.listen((results) async {
          for (ScanResult r in results) {
            print('###### ${r.device.name} found! rssi: ${r.rssi}');
            if (r.device.name == 'ESP32_Data_Bridge') {
              await connectToDevice(r.device);
              flutterBlue.stopScan();
              await readData();
              action.call();
            }
          }
        });
      } catch (e) {
        log("scanForDevices: $e");
      }
    }
  }

  Future<void> requestPermissions() async {
    // Request the permissions if not already granted
    PermissionStatus status = await Permission.bluetooth.request();
    if (status.isGranted) {
      // Proceed with scanning or Bluetooth actions
      print('Bluetooth permission granted');
    } else {
      print('Bluetooth permission denied');
    }
  }

  Future connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      this.device = device;
      print('Connected to ${device.name}');
    } catch (e) {
      log("connectToDevice: $e");
    }
  }

  Future<String?> readData() async {
    if (device == null) {
      return null;
    }
    List<BluetoothService> services = await device!.discoverServices();
    services.forEach((service) async {
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        if (c.properties.read) {
          var value = await c.read();
          data = data + utf8.decode(value);
          print('Read value: $value');
        }
      }
    });
    return data;
  }

  void writeData(BluetoothDevice device, String data) async {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) async {
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        if (c.properties.write) {
          await c.write(utf8.encode(data));
          print('Data written: $data');
        }
      }
    });
  }
}
