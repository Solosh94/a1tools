import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SummaryScreen extends StatefulWidget {
  final String n8nWebhookUrl;

  const SummaryScreen({
    super.key,
    required this.n8nWebhookUrl,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final List<String> _dispatchers = [
    'Luna Perez',
    'Sara Persad',
    'Victor Cruz',
    'Jeff Rich',
    'Christina Paul',
    'Chevel Richards',
    'Bianca Petiote',
    'Natalie Escobar',
    'Justin Weinberg',
    'Betty Shaterria Whyte',
    'Trey Brannan',
    'Belle Potente',
    'Melissa Oca',
    'Ashley Plummer',
    'Jared Prescott',
    'Kai Sarfaty',
    'Mateo Salamanca',
    'Jonathan Torres',
    'Eli Deblinger',
    'Maria Aljolyn',
  ];

  bool _loading = false;
  String? _error;
  String? _summaryResult;
  String? _currentDispatcher;

  Future<void> _requestSummary(String dispatcherName) async {
    setState(() {
      _loading = true;
      _error = null;
      _summaryResult = null;
      _currentDispatcher = dispatcherName;
    });

    try {
      final client = HttpClient();
      final uri = Uri.parse(widget.n8nWebhookUrl);

      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(jsonEncode({'dispatcherName': dispatcherName})));

      final res = await req.close();
      final txt = await utf8.decodeStream(res);

      if (res.statusCode == 200) {
        String? summaryText;

        try {
          final decoded = jsonDecode(txt);

          if (decoded is Map<String, dynamic>) {
            summaryText = decoded['summary'] as String?;
            final apiDispatcher = decoded['dispatcherName'] as String?;
            if (apiDispatcher != null && apiDispatcher.isNotEmpty) {
              _currentDispatcher = apiDispatcher;
            }
          } else if (decoded is List && decoded.isNotEmpty) {
            final first = decoded.first;
            if (first is Map<String, dynamic>) {
              summaryText = first['summary'] as String?;
              final apiDispatcher = first['dispatcherName'] as String?;
              if (apiDispatcher != null && apiDispatcher.isNotEmpty) {
                _currentDispatcher = apiDispatcher;
              }
            }
          }
        } catch (e) {
          debugPrint('[SummaryScreen] JSON parse error: $e');
          summaryText = txt;
        }

        if (mounted) setState(() => _summaryResult = summaryText ?? txt);
      } else {
        if (mounted) setState(() => _error = 'HTTP ${res.statusCode}: $txt');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to reach summary server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copySummary() {
    final text = _summaryResult ?? '';
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Response copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final codeBoxColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    final borderColor = isDark ? const Color(0xFF3A3A3A) : Colors.black12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatcher Daily Summary'),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // LEFT SIDE - Dispatcher List
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: cardColor,
                elevation: 2,
                child: ListView.separated(
                  itemCount: _dispatchers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final name = _dispatchers[i];
                    return ListTile(
                      title: Text(name),
                      onTap: () => _requestSummary(name),
                    );
                  },
                ),
              ),
            ),
          ),

          // RIGHT SIDE - Summary Output
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: cardColor,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? SingleChildScrollView(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : _summaryResult != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _currentDispatcher != null
                                              ? 'Response for ${_currentDispatcher!}'
                                              : 'Response',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Copy summary',
                                          icon: const Icon(Icons.copy),
                                          onPressed: _copySummary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: codeBoxColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: SingleChildScrollView(
                                          child: SelectableText(
                                            _summaryResult!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: Text('Select a dispatcher to generate summary'),
                                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}