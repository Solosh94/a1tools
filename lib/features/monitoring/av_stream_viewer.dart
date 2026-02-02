import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'av_stream_service.dart';

/// Full-screen viewer for remote audio+video streaming
class AVStreamViewer extends StatefulWidget {
 final String targetIp;
 final String targetName;
 final int port;
 
 const AVStreamViewer({
 super.key,
 required this.targetIp,
 required this.targetName,
 this.port = 5902, // Different port from video-only
 });

 @override
 State<AVStreamViewer> createState() => _AVStreamViewerState();
}

class _AVStreamViewerState extends State<AVStreamViewer> {
 late AVStreamClient _client;
 Uint8List? _currentFrame;
 String _status = 'Initializing...';
 String? _error;
 bool _isFullscreen = false;
 int _fps = 10;
 
 // Audio state
 bool _audioAvailable = false;
 bool _audioMuted = false;
 int _audioChunks = 0;
 VideoPlayerController? _audioPlayer;
 String? _audioTempPath;
 
 @override
 void initState() {
 super.initState();
 _initTempPath();
 _client = AVStreamClient(
 onFrame: (frameData) {
 if (mounted) {
 setState(() {
 _currentFrame = frameData;
 _error = null;
 });
 }
 },
 onAudio: _handleAudioData,
 onStatusChanged: (status) {
 if (mounted) {
 setState(() => _status = status);
 }
 },
 onError: (error) {
 if (mounted) {
 setState(() => _error = error);
 }
 },
 onAudioAvailable: (available) {
 if (mounted) {
 setState(() => _audioAvailable = available);
 }
 },
 );
 _connect();
 }
 
 Future<void> _initTempPath() async {
 final tempDir = await getTemporaryDirectory();
 _audioTempPath = '${tempDir.path}/av_stream_audio.wav';
 }
 
 void _handleAudioData(Uint8List audioData) async {
 if (_audioMuted || _audioTempPath == null) return;
 
 setState(() => _audioChunks++);
 
 try {
 // Write WAV data to temp file
 final file = File(_audioTempPath!);
 await file.writeAsBytes(audioData);
 
 // Play the audio
 await _playAudioFile(_audioTempPath!);
 } catch (e) {
 debugPrint('[AVStreamViewer] Audio play error: $e');
 }
 }
 
 Future<void> _playAudioFile(String path) async {
 try {
 // Dispose previous player
 await _audioPlayer?.dispose();
 
 // Create new player
 _audioPlayer = VideoPlayerController.file(File(path));
 await _audioPlayer!.initialize();
 await _audioPlayer!.setVolume(_audioMuted ? 0 : 1);
 await _audioPlayer!.play();
 } catch (e) {
 debugPrint('[AVStreamViewer] Audio player error: $e');
 }
 }
 
 Future<void> _connect() async {
 setState(() {
 _status = 'Connecting...';
 _error = null;
 });
 
 final success = await _client.connect(widget.targetIp, port: widget.port);
 if (!success && mounted) {
 setState(() {
 _error = 'Failed to connect to ${widget.targetIp}:${widget.port}';
 });
 }
 }
 
 @override
 void dispose() {
 _client.disconnect();
 _audioPlayer?.dispose();
 // Clean up temp file
 if (_audioTempPath != null) {
 try { File(_audioTempPath!).deleteSync(); } catch (e) {
  debugPrint('[AvStreamViewer] Error: $e');
}
 }
 super.dispose();
 }
 
 void _changeFps(int fps) {
 setState(() => _fps = fps);
 _client.setFps(fps);
 }
 
 void _toggleMute() {
 setState(() => _audioMuted = !_audioMuted);
 _audioPlayer?.setVolume(_audioMuted ? 0 : 1);
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 backgroundColor: Colors.black,
 appBar: _isFullscreen ? null : AppBar(
 backgroundColor: Colors.black,
 foregroundColor: Colors.white,
 title: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Text(widget.targetName, style: const TextStyle(fontSize: 16)),
 const SizedBox(width: 8),
 // Audio indicator badge
 if (_audioAvailable)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: _audioMuted ? Colors.red : Colors.green,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _audioMuted ? Icons.volume_off : Icons.volume_up,
 size: 12,
 color: Colors.white,
 ),
 const SizedBox(width: 4),
 Text(
 _audioMuted ? 'MUTED' : 'AUDIO',
 style: const TextStyle(fontSize: 10, color: Colors.white),
 ),
 ],
 ),
 ),
 ],
 ),
 Text(
 '${widget.targetIp}:${widget.port}',
 style: const TextStyle(fontSize: 12, color: Colors.white60),
 ),
 ],
 ),
 actions: [
 // Audio toggle
 if (_audioAvailable)
 IconButton(
 icon: Icon(_audioMuted ? Icons.volume_off : Icons.volume_up),
 onPressed: _toggleMute,
 tooltip: _audioMuted ? 'Unmute' : 'Mute',
 color: _audioMuted ? Colors.red : Colors.white,
 ),
 // FPS selector
 PopupMenuButton<int>(
 icon: const Icon(Icons.speed),
 tooltip: 'Frame Rate',
 onSelected: _changeFps,
 itemBuilder: (context) => [
 PopupMenuItem(value: 5, child: Text('5 FPS${_fps == 5 ? ' ✓' : ''}')),
 PopupMenuItem(value: 10, child: Text('10 FPS${_fps == 10 ? ' ✓' : ''}')),
 PopupMenuItem(value: 15, child: Text('15 FPS${_fps == 15 ? ' ✓' : ''}')),
 PopupMenuItem(value: 20, child: Text('20 FPS${_fps == 20 ? ' ✓' : ''}')),
 PopupMenuItem(value: 30, child: Text('30 FPS${_fps == 30 ? ' ✓' : ''}')),
 ],
 ),
 // Fullscreen toggle
 IconButton(
 icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
 onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
 tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
 ),
 // Reconnect button
 IconButton(
 icon: const Icon(Icons.refresh),
 onPressed: () {
 _client.disconnect();
 _connect();
 },
 tooltip: 'Reconnect',
 ),
 ],
 ),
 body: GestureDetector(
 onDoubleTap: () => setState(() => _isFullscreen = !_isFullscreen),
 child: Stack(
 children: [
 // Main content
 Center(
 child: _error != null
 ? _buildErrorWidget()
 : _currentFrame != null
 ? Image.memory(
 _currentFrame!,
 fit: BoxFit.contain,
 gaplessPlayback: true,
 filterQuality: FilterQuality.medium,
 )
 : _buildConnectingWidget(),
 ),
 
 // Status bar at bottom
 if (!_isFullscreen)
 Positioned(
 left: 0,
 right: 0,
 bottom: 0,
 child: Container(
 color: Colors.black87,
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 child: Row(
 children: [
 // Connection status indicator
 Container(
 width: 10,
 height: 10,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 color: _client.isConnected ? Colors.green : Colors.red,
 boxShadow: [
 BoxShadow(
 color: (_client.isConnected ? Colors.green : Colors.red).withValues(alpha: 0.5),
 blurRadius: 6,
 spreadRadius: 2,
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 Text(
 _status,
 style: const TextStyle(color: Colors.white70, fontSize: 12),
 ),
 // Audio status
 if (_audioAvailable) ...[
 const SizedBox(width: 12),
 Icon(
 _audioMuted ? Icons.volume_off : Icons.volume_up,
 size: 16,
 color: _audioMuted ? Colors.red : Colors.green,
 ),
 const SizedBox(width: 4),
 Text(
 '$_audioChunks chunks',
 style: TextStyle(
 color: _audioMuted ? Colors.red : Colors.green,
 fontSize: 12,
 ),
 ),
 ],
 const Spacer(),
 // Stats
 if (_client.isConnected) ...[
 Text(
 '${_client.fps.toStringAsFixed(1)} FPS',
 style: const TextStyle(color: Colors.white70, fontSize: 12),
 ),
 const SizedBox(width: 16),
 Text(
 '${_client.framesReceived} frames',
 style: const TextStyle(color: Colors.white70, fontSize: 12),
 ),
 ],
 ],
 ),
 ),
 ),
 
 // Audio indicator overlay in fullscreen
 if (_isFullscreen && _audioAvailable)
 Positioned(
 top: 16,
 left: 16,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.black54,
 borderRadius: BorderRadius.circular(16),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 _audioMuted ? Icons.volume_off : Icons.volume_up,
 color: _audioMuted ? Colors.red : Colors.green,
 size: 16,
 ),
 const SizedBox(width: 6),
 Text(
 _audioMuted ? 'Audio Muted' : 'Audio Playing',
 style: TextStyle(
 color: _audioMuted ? Colors.red : Colors.green,
 fontSize: 11,
 ),
 ),
 ],
 ),
 ),
 ),
 
 // Exit fullscreen hint
 if (_isFullscreen)
 Positioned(
 top: 16,
 right: 16,
 child: Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.black54,
 borderRadius: BorderRadius.circular(16),
 ),
 child: const Text(
 'Double-tap to exit fullscreen',
 style: TextStyle(color: Colors.white70, fontSize: 11),
 ),
 ),
 ),
 ],
 ),
 ),
 );
 }
 
 Widget _buildConnectingWidget() {
 return Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const CircularProgressIndicator(color: Colors.white),
 const SizedBox(height: 24),
 Text(
 _status,
 style: const TextStyle(color: Colors.white70, fontSize: 16),
 ),
 const SizedBox(height: 8),
 Text(
 'Connecting to ${widget.targetName}...',
 style: const TextStyle(color: Colors.white38, fontSize: 14),
 ),
 const SizedBox(height: 8),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.blue.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(16),
 ),
 child: const Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.surround_sound, color: Colors.blue, size: 16),
 SizedBox(width: 6),
 Text(
 'Audio + Video Mode',
 style: TextStyle(color: Colors.blue, fontSize: 12),
 ),
 ],
 ),
 ),
 ],
 );
 }
 
 Widget _buildErrorWidget() {
 return Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 const Icon(Icons.error_outline, color: Colors.red, size: 64),
 const SizedBox(height: 24),
 const Text(
 'Connection Failed',
 style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 Padding(
 padding: const EdgeInsets.symmetric(horizontal: 32),
 child: Text(
 _error ?? 'Unknown error',
 style: const TextStyle(color: Colors.white60, fontSize: 14),
 textAlign: TextAlign.center,
 ),
 ),
 const SizedBox(height: 24),
 ElevatedButton.icon(
 onPressed: () {
 _client.disconnect();
 _connect();
 },
 icon: const Icon(Icons.refresh),
 label: const Text('Retry'),
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.white24,
 foregroundColor: Colors.white,
 ),
 ),
 const SizedBox(height: 48),
 Container(
 margin: const EdgeInsets.symmetric(horizontal: 32),
 padding: const EdgeInsets.all(16),
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(8),
 ),
 child: const Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'Troubleshooting:',
 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
 ),
 SizedBox(height: 8),
 Text(
 '• Make sure A1 Tools is running on the target PC\n'
 '• Check that both computers are on the same network\n'
 '• Verify Windows Firewall allows port 5902\n'
 '• Audio requires Windows with system audio enabled',
 style: TextStyle(color: Colors.white60, fontSize: 13),
 ),
 ],
 ),
 ),
 ],
 );
 }
}
