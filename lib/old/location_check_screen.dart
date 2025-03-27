import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationCheckScreen extends StatefulWidget {
  const LocationCheckScreen({super.key});

  @override
  LocationCheckScreenState createState() => LocationCheckScreenState();
}

class LocationCheckScreenState extends State<LocationCheckScreen> {
  String _locationStatus = "Belum dicek";
  double? _latitude;
  double? _longitude;
  double? _altitude;
  final List<String> _warnings = []; // Tetep gini, abaikan warning
  LatLng? _currentLocation;
  bool _isChecking = false;

  Future<void> _checkLocation() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _warnings.clear(); // Diubah isinya
      _locationStatus = "Sedang memeriksa...";
    });

    print("Debug: Mulai cek lokasi");

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationStatus = "Layanan lokasi dimatikan.";
        _isChecking = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print("Debug: Izin lokasi ditolak, minta izin");
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = "Izin lokasi ditolak.";
          _isChecking = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationStatus = "Izin lokasi ditolak permanen.";
        _isChecking = false;
      });
      return;
    }

    try {
      print("Debug: Ambil posisi");
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception("Waktu habis, GPS tidak merespon.");
      });

      print("Debug: Cek SafeDevice");
      bool isMocked = position.isMocked;
      bool canMockLocation = await SafeDevice.isMockLocation;
      bool isRooted = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isOnExternalStorage = await SafeDevice.isOnExternalStorage;
      bool isSafeDevice = await SafeDevice.isSafeDevice;

      if (isMocked) _warnings.add("Lokasi dari mock provider."); // Diubah isinya
      if (canMockLocation) _warnings.add("Perangkat mendukung mock location.");
      if (isRooted) _warnings.add("Perangkat rooted atau jailbroken.");
      if (!isRealDevice) _warnings.add("Bukan perangkat asli (emulator).");
      if (isOnExternalStorage) _warnings.add("Aplikasi di storage eksternal.");
      if (!isSafeDevice) _warnings.add("Perangkat tidak aman secara keseluruhan.");

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_warnings.isEmpty) {
          _locationStatus = "Lokasi valid.";
        } else {
          _locationStatus = "Lokasi mencurigakan!";
        }
        _isChecking = false;
      });
      print("Debug: Lokasi selesai diperiksa");
    } catch (e) {
      setState(() {
        _locationStatus = "Gagal mengambil lokasi: $e";
        _isChecking = false;
      });
      print("Debug: Error - $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cek Lokasi")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Status: $_locationStatus",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_latitude != null && _longitude != null)
                Column(
                  children: [
                    Text(
                      "Koordinat: ($_latitude, $_longitude)",
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      "Ketinggian: ${_altitude?.toStringAsFixed(2)} m",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (_warnings.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Peringatan:",
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    ..._warnings.map((warning) => Text(
                      "- $warning",
                      style: const TextStyle(fontSize: 14, color: Colors.red),
                    )),
                  ],
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: _currentLocation == null
                    ? const Center(child: Text("Peta belum tersedia, cek lokasi dulu"))
                    : FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: 17.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: _currentLocation!,
                          child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkLocation,
                child: _isChecking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Cek Lokasi Sekarang"),
              ),
              if (!_isChecking && _locationStatus.contains("Gagal"))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton(
                    onPressed: _checkLocation,
                    child: const Text("Coba Lagi"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}