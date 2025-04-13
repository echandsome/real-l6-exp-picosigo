import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audio_session/audio_session.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Tools',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Audio Tools App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentFilePath;
  List<String> _foundFiles = [];
  double _playbackRate = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Search for audio files
  Future<void> _onSearchPressed() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _foundFiles = result.paths.map((path) => path!).toList();
        });
        _showFilesDialog();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files selected')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching files: $e')),
      );
    }
  }

  void _showFilesDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Found Audio Files'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _foundFiles.length,
            itemBuilder: (context, index) {
              final file = _foundFiles[index];
              return ListTile(
                title: Text(File(file).uri.pathSegments.last),
                onTap: () {
                  setState(() {
                    _currentFilePath = file;
                  });
                  Navigator.pop(context);
                  _playAudio(file);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Edit audio (simple playback rate and volume control)
  Future<void> _onEditPressed() {
    if (!mounted) return Future.value();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Playback Speed'),
            Slider(
              value: _playbackRate,
              min: 0.5,
              max: 2.0,
              divisions: 3,
              label: _playbackRate.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _playbackRate = value;
                });
                _audioPlayer.setPlaybackRate(value);
              },
            ),
            const SizedBox(height: 20),
            const Text('Volume'),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _volume.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
                _audioPlayer.setVolume(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Play audio
  Future<void> _onPlayPressed() async {
    if (_currentFilePath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio file selected')),
      );
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } else {
      await _playAudio(_currentFilePath!);
    }
  }

  Future<void> _playAudio(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  // Record audio
  Future<void> _onRecordPressed() async {
    if (_isRecording) {
      // Stop recording
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
      // In a real app, you would stop the recording here
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording stopped')),
      );
    } else {
      // Start recording
      final status = await Permission.microphone.request();
      if (!mounted) return;
      
      if (status.isGranted) {
        if (mounted) {
          setState(() {
            _isRecording = true;
          });
        }
        
        // In a real implementation, you would start recording here
        // This is a simplified version
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        _currentFilePath = '${dir.path}/$fileName';
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording started...')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Search button
                _buildButton(
                  icon: Icons.search,
                  label: 'Search',
                  onPressed: _onSearchPressed,
                  isActive: false,
                ),

                // Edit button
                _buildButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  onPressed: _onEditPressed,
                  isActive: false,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Second row of buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Play button
                _buildButton(
                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                  label: _isPlaying ? 'Pause' : 'Play',
                  onPressed: _onPlayPressed,
                  isActive: _isPlaying,
                ),

                // Record button
                _buildButton(
                  icon: _isRecording ? Icons.stop : Icons.mic,
                  label: _isRecording ? 'Stop' : 'Record',
                  onPressed: _onRecordPressed,
                  isActive: _isRecording,
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Current file info
            if (_currentFilePath != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Current file: ${File(_currentFilePath!).uri.pathSegments.last}',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isActive 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Icon(
              icon,
              size: 40,
              color: isActive
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}