import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:video_upscaler_app/widgets/video_info_table.dart';
import 'package:video_upscaler_app/utils/video_processing_logic.dart';

class VideoUpscalerHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const VideoUpscalerHomePage({super.key, required this.onToggleTheme});

  @override
  State<VideoUpscalerHomePage> createState() => _VideoUpscalerHomePageState();
}

class _VideoUpscalerHomePageState extends State<VideoUpscalerHomePage> {
  String? _inputPath;
  String? _outputPath;
  Map<String, dynamic>? _videoInfo;
  bool _isAnalyzing = false;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = 'Pronto para processar';
  final List<String> _logOutput = [];
  Process? _ffmpegProcess;
  double? _videoDuration;

  bool _applyUpscaling = false;
  int _targetWidth = 1920;
  int _targetHeight = 1080;
  bool _maintainAspectRatio = true;

  bool _applyInterpolation = false;
  double _targetFps = 60.0;
  String _timeRemaining = '';

  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _fpsController;

  final VideoProcessingLogic _processingLogic = VideoProcessingLogic();

  @override
  void initState() {
    super.initState();
    _targetWidth = 1920;
    _targetHeight = 1080;

    _widthController = TextEditingController(text: _targetWidth.toString())
      ..addListener(_updateHeightFromWidth);
    _heightController = TextEditingController(text: _targetHeight.toString())
      ..addListener(_updateWidthFromHeight);
    _fpsController = TextEditingController(text: _targetFps.toString());
  }

  void _updateHeightFromWidth() {
    if (_maintainAspectRatio && _videoInfo != null) {
      final newWidth = int.tryParse(_widthController.text);
      if (newWidth != null && newWidth != _targetWidth) {
        setState(() {
          _targetWidth = newWidth;
          _targetHeight =
              (newWidth * _videoInfo!['height'] / _videoInfo!['width']).round();
          if (_heightController.text != _targetHeight.toString()) {
            _heightController.text = _targetHeight.toString();
          }
        });
      }
    } else {
      setState(() {
        _targetWidth = int.tryParse(_widthController.text) ?? _targetWidth;
      });
    }
  }

  void _updateWidthFromHeight() {
    if (_maintainAspectRatio && _videoInfo != null) {
      final newHeight = int.tryParse(_heightController.text);
      if (newHeight != null && newHeight != _targetHeight) {
        setState(() {
          _targetHeight = newHeight;
          _targetWidth =
              (newHeight * _videoInfo!['width'] / _videoInfo!['height'])
                  .round();
          if (_widthController.text != _targetWidth.toString()) {
            _widthController.text = _targetWidth.toString();
          }
        });
      }
    } else {
      setState(() {
        _targetHeight = int.tryParse(_heightController.text) ?? _targetHeight;
      });
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _fpsController.dispose();
    super.dispose();
  }

  Future<void> _selectVideoFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _inputPath = result.files.single.path;
        _videoInfo = null;
        _processingStatus = 'Analisando vídeo...';
        _isAnalyzing = true;
        _logOutput.clear();
      });
      _analyzeVideo();
    }
  }

  Future<void> _analyzeVideo() async {
    if (_inputPath == null) return;
    setState(() {
      _isAnalyzing = true;
      _processingStatus = 'Analisando vídeo...';
      _logOutput.clear();
    });

    try {
      final info = await _processingLogic.analyzeVideo(_inputPath!);
      setState(() {
        _videoInfo = info;
        _isAnalyzing = false;
        _processingStatus = 'Análise concluída com sucesso!';
        _targetWidth = _videoInfo!['width'] * 2 > 7680
            ? 7680
            : _videoInfo!['width'] * 2;
        _targetHeight = _videoInfo!['height'] * 2 > 4320
            ? 4320
            : _videoInfo!['height'] * 2;
        _videoDuration = _videoInfo!['duration'];
        _targetFps = _videoInfo!['fps'] * 2 > 120
            ? 120
            : _videoInfo!['fps'] * 2;

        _widthController.text = _targetWidth.toString();
        _heightController.text = _targetHeight.toString();
        _fpsController.text = _targetFps.toStringAsFixed(0);
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _processingStatus = 'Erro na análise: $e';
        _videoInfo = null;
      });
      _showErrorDialog('Erro na Análise do Vídeo', e.toString());
    }
  }

  Future<void> _selectOutputFile() async {
    if (_inputPath == null) {
      _showErrorDialog('Erro', 'Selecione um arquivo de vídeo primeiro.');
      return;
    }

    final inputFileName = p.basenameWithoutExtension(_inputPath!);
    final sanitizedFileName = _sanitizeFileName(inputFileName);
    final defaultFileName = '${sanitizedFileName}_processed.mp4';

    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar vídeo processado',
      fileName: defaultFileName,
    );

    if (filePath != null) {
      String finalPath = filePath;
      if (!finalPath.toLowerCase().endsWith('.mp4')) {
        finalPath = '$finalPath.mp4';
      }
      setState(() {
        _outputPath = finalPath;
      });
    }
  }

  Future<void> _startProcessing() async {
    if (_inputPath == null || _outputPath == null || _videoInfo == null) {
      _showErrorDialog('Erro', 'Selecione os arquivos de entrada e saída.');
      return;
    }

    try {
      if (_outputPath != null) {
        final outputDir = Directory(
          _outputPath!.substring(
            0,
            _outputPath!.lastIndexOf(Platform.pathSeparator),
          ),
        );
        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
          _logOutput.add('Diretório de saída criado: ${outputDir.path}');
        }
      }
    } catch (e) {
      _showErrorDialog(
        'Erro de Acesso',
        'Não foi possível criar o diretório de saída. Verifique as permissões. Erro: $e',
      );
      return;
    }

    final args = _processingLogic.buildFfmpegCommand(
      _inputPath!,
      _outputPath!,
      _videoInfo!,
      _applyUpscaling,
      _targetWidth,
      _targetHeight,
      _maintainAspectRatio,
      _applyInterpolation,
      _targetFps,
    );

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Processando vídeo...';
      _timeRemaining = 'Calculando tempo restante...';
      _logOutput.clear();
    });

    try {
      _ffmpegProcess = await Process.start('ffmpeg', args);
      final startTime = DateTime.now();

      _ffmpegProcess!.stdout.transform(utf8.decoder).listen((data) {
        setState(() {
          _logOutput.add(data);
        });
      });

      _ffmpegProcess!.stderr.transform(utf8.decoder).listen((data) {
        setState(() {
          _logOutput.add(data);
        });
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.contains('time=')) {
            final timeMatch = RegExp(
              r'time=(\d{2}):(\d{2}):(\d{2}).(\d{2})',
            ).firstMatch(line);
            if (timeMatch != null) {
              final h = int.parse(timeMatch.group(1)!);
              final m = int.parse(timeMatch.group(2)!);
              final s = int.parse(timeMatch.group(3)!);
              final currentSeconds = (h * 3600 + m * 60 + s).toDouble();

              if (_videoDuration != null && _videoDuration! > 0) {
                final newProgress = currentSeconds / _videoDuration!;
                setState(() {
                  _processingProgress = newProgress;
                  final elapsedSeconds = DateTime.now()
                      .difference(startTime)
                      .inSeconds
                      .toDouble();
                  if (elapsedSeconds > 0) {
                    final speed = currentSeconds / elapsedSeconds;
                    final remainingSeconds =
                        (_videoDuration! - currentSeconds) / speed;
                    _timeRemaining = _formatTime(remainingSeconds);
                  }
                });
              } else {
                final newProgress =
                    (DateTime.now().difference(startTime).inSeconds / 60).clamp(
                      0.0,
                      0.95,
                    );
                setState(() {
                  _processingProgress = newProgress;
                });
              }
            }
          }
        }
      });

      final exitCode = await _ffmpegProcess!.exitCode;

      setState(() {
        _isProcessing = false;
        _ffmpegProcess = null;
        if (exitCode == 0) {
          _processingProgress = 1.0;
          _processingStatus = '✅ Processamento concluído!';
          _timeRemaining = '';
          _showSuccessDialog(
            'Processamento Concluído',
            'O vídeo foi salvo em: $_outputPath',
          );
        } else {
          _processingStatus = '❌ Processamento cancelado ou falhou.';
          _timeRemaining = '';
          _showErrorDialog(
            'Erro no Processamento',
            'FFmpeg retornou código de erro: $exitCode',
          );
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = '❌ Erro no processamento: $e';
        _ffmpegProcess = null;
      });
      _showErrorDialog('Erro no Processamento', e.toString());
    }
  }

  void _cancelProcessing() {
    if (_ffmpegProcess != null) {
      _ffmpegProcess!.kill();
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Processamento cancelado.';
        _ffmpegProcess = null;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.red)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.green)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _sanitizeFileName(String fileName) {
    final invalidChars = RegExp(r'[<>:"/\\|?*]');
    return fileName.replaceAll(invalidChars, '_');
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return 'Calculando...';
    int hours = (seconds / 3600).truncate();
    int minutes = ((seconds % 3600) / 60).truncate();
    int secs = (seconds % 60).truncate();
    if (hours > 0) {
      return '⏱️ ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '⏱️ ${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final icon = brightness == Brightness.dark
        ? Icons.light_mode
        : Icons.dark_mode;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(onPressed: widget.onToggleTheme, icon: Icon(icon)),
              ],
            ),
            const SizedBox(height: 16.0),
            // Seção de seleção de arquivo
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📁 Seleção de Vídeo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _selectVideoFile,
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                        _inputPath == null
                            ? 'Selecionar Arquivo de Vídeo'
                            : 'Alterar Arquivo de Vídeo',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_inputPath != null)
                      Text(
                        _inputPath!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Seção de informações do vídeo
            if (_inputPath != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Propriedades do Vídeo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isAnalyzing)
                        Center(
                          child: Column(
                            children: [
                              const SpinKitFoldingCube(
                                color: Colors.blue,
                                size: 50.0,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _processingStatus,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_videoInfo != null)
                        VideoInfoTable(videoInfo: _videoInfo!),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Seção de configuração de processamento
            if (_videoInfo != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚙️ Configurações de Processamento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Upscaling
                      Row(
                        children: [
                          Checkbox(
                            value: _applyUpscaling,
                            onChanged: (bool? value) {
                              setState(() {
                                _applyUpscaling = value!;
                              });
                            },
                          ),
                          const Text(
                            'Aplicar Upscaling (Aumentar Resolução)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_applyUpscaling) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resolução:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _widthController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Largura (px)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Altura (px)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _maintainAspectRatio,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _maintainAspectRatio = value!;
                                      });
                                    },
                                  ),
                                  const Text('Manter Proporção'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildPresetButton('HD', 1280, 720),
                                  _buildPresetButton('Full HD', 1920, 1080),
                                  _buildPresetButton('2K', 2560, 1440),
                                  _buildPresetButton('4K', 3840, 2160),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      // Interpolação de frames
                      Row(
                        children: [
                          Checkbox(
                            value: _applyInterpolation,
                            onChanged: (bool? value) {
                              setState(() {
                                _applyInterpolation = value!;
                              });
                            },
                          ),
                          const Text(
                            'Aplicar Interpolação de Frames (Aumentar FPS)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_applyInterpolation) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FPS de Destino:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _fpsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'FPS de Destino',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _targetFps =
                                        double.tryParse(value) ?? _targetFps;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFpsPresetButton('30 fps', 30.0),
                                  _buildFpsPresetButton('60 fps', 60.0),
                                  _buildFpsPresetButton('120 fps', 120.0),
                                  _buildFpsPresetButton('240 fps', 240.0),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Seção de execução
            if (_videoInfo != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🚀 Processamento do Vídeo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _selectOutputFile,
                        icon: const Icon(Icons.save_as),
                        label: Text(
                          _outputPath == null
                              ? 'Selecionar Arquivo de Saída'
                              : 'Alterar Arquivo de Saída',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_outputPath != null)
                        Text(
                          _outputPath!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  (_applyUpscaling || _applyInterpolation) &&
                                      _outputPath != null &&
                                      !_isProcessing
                                  ? _startProcessing
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Processar Vídeo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing
                                  ? _cancelProcessing
                                  : null,
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancelar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _processingProgress,
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_processingProgress * 100).toStringAsFixed(0)}% - $_processingStatus',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_isProcessing)
                        Text(
                          'Tempo Restante: $_timeRemaining',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Log de Processamento',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _logOutput.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logOutput[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String text, int width, int height) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _targetWidth = width;
          _targetHeight = height;
          _widthController.text = _targetWidth.toString();
          _heightController.text = _targetHeight.toString();
        });
      },
      child: Text(text),
    );
  }

  Widget _buildFpsPresetButton(String text, double fps) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _targetFps = fps;
          _fpsController.text = _targetFps.toStringAsFixed(0);
        });
      },
      child: Text(text),
    );
  }
}
