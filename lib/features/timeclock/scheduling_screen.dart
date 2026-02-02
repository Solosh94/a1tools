import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  final _zipCtrl = TextEditingController(text: '10001');
  final _radiusCtrl = TextEditingController(text: '60');
  final _maxStopsCtrl = TextEditingController(text: '5');

  bool _useGps = true;
  bool _loading = false;
  String _rawOut = '';
  Map<String, dynamic>? _json;

  static const _endpoint = ApiConfig.n8nRouteSuggest;
  static const Color accentOrange = Color(0xFFF49320);

  int _parseInt(String text, int fallback) {
    final s = text.trim();
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d.round();
    return fallback;
  }

  Future<Position?> _getLocationIfNeeded() async {
    if (!_useGps) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _rawOut = 'Location services are disabled.');
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _rawOut = 'Location permission denied.');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _rawOut = 'Location permission permanently denied.');
      return null;
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _rawOut = '';
      _json = null;
    });

    try {
      final zip = _zipCtrl.text.trim();
      final radiusMiles = _parseInt(_radiusCtrl.text, 60);
      final maxStops = _parseInt(_maxStopsCtrl.text, 5);

      Position? pos;
      if (_useGps) {
        pos = await _getLocationIfNeeded();
      }

      final body = <String, dynamic>{
        'zip': zip,
        'radiusMiles': radiusMiles,
        'maxStops': maxStops,
        'maxLegMiles': 60,
      };

      if (pos != null) {
        body['currentLat'] = pos.latitude;
        body['currentLng'] = pos.longitude;
      }

      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final text = resp.body;
      setState(() {
        _rawOut = '${resp.statusCode} - $text';
        try {
          _json = jsonDecode(text) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('[SchedulingScreen] JSON parse error: \$e');
          _json = null;
        }
      });
    } catch (e) {
      setState(() {
        _rawOut = 'ERR: $e';
        _json = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMaps() async {
    final link = _json?['mapsLink'] as String?;
    if (link == null || link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeBoxColor = isDark ? const Color(0xFF1E1E1E) : Colors.black12;
    
    final stops = (_json?['stops'] as List?) ?? const [];
    final totalDist = _json?['totalDistanceMiles'];
    final originSource = _json?['originSource'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routing Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter ZIP Code (search center)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _zipCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 10001',
                      labelText: 'ZIP',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _radiusCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Radius (mi)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxStopsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max Stops',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _useGps,
              onChanged: (v) => setState(() => _useGps = v),
              title: const Text('Use my current location as the starting point'),
              subtitle: const Text('If OFF, route will start from first stop in the list'),
              activeTrackColor: accentOrange.withValues(alpha: 0.5),
              activeThumbColor: accentOrange,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _send,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Build Route', style: TextStyle(fontSize: 16)),
            ),
            if (_json != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stops: ${stops.length}  -  Total: ${totalDist ?? '-'} mi',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_json?['mapsLink'] != null)
                    TextButton.icon(
                      onPressed: _openMaps,
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Google Maps'),
                    ),
                ],
              ),
              if (originSource != null)
                Text(
                  'Origin source: $originSource',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            const Text('Raw Response:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: codeBoxColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _rawOut,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}