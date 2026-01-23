import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() {
  runApp(const ShorebirdTrackerApp());
}

class ShorebirdTrackerApp extends StatelessWidget {
  const ShorebirdTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Using a standard blue seed for Material 3
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const ShorebirdStatusPage(),
    );
  }
}

class ShorebirdStatusPage extends StatefulWidget {
  const ShorebirdStatusPage({super.key});

  @override
  State<ShorebirdStatusPage> createState() => _ShorebirdStatusPageState();
}

class _ShorebirdStatusPageState extends State<ShorebirdStatusPage> {
  final ShorebirdUpdater _shorebirdUpdater = ShorebirdUpdater();

  String _status = "Initializing...";
  String _patchInfo = "None";
  bool _isShorebirdAvailable = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _status = "Checking for patches...";
    });

    try {
      // 1. Check if engine is active
      final bool available = _shorebirdUpdater.isAvailable;

      // 2. Read current patch info
      final Patch? currentPatch = await _shorebirdUpdater.readCurrentPatch();

      // 3. Check for updates (Handling the UpdateStatus enum)
      final UpdateStatus updateStatus = await _shorebirdUpdater
          .checkForUpdate();

      setState(() {
        _isShorebirdAvailable = available;
        _patchInfo = currentPatch != null
            ? "Patch #${currentPatch.number}"
            : "No Patch Applied (Original Build)";

        // Handle enum values: upToDate, outdated, or restartRequired
        if (updateStatus == UpdateStatus.outdated) {
          _status = "Update Found! Downloading...";
        } else if (updateStatus == UpdateStatus.restartRequired) {
          _status = "Update downloaded. Restart app to apply.";
        } else {
          _status = "App is up to date.";
        }
      });

      // 4. If an update is available, download it
      if (updateStatus == UpdateStatus.outdated) {
        await _shorebirdUpdater.update();
        setState(() {
          _status = "Update downloaded. Force quit and restart the app twice.";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shorebird Diagnostic Tool"),
        // Changed from blueContainer to a standard color
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(
                    "Engine Active:",
                    _isShorebirdAvailable ? "YES" : "NO",
                    _isShorebirdAvailable ? Colors.green : Colors.red,
                  ),
                  const Divider(height: 32),
                  _buildStatusRow("Current Patch:", _patchInfo, Colors.blue),
                  const Divider(height: 32),
                  const Text(
                    "System Status:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      color: _status.contains("Error")
                          ? Colors.red
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkStatus,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text("Check for Patch Now"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
