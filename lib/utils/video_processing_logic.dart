import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:process_run/process_run.dart';

class VideoProcessingLogic {
  Future<Map<String, dynamic>> analyzeVideo(String inputPath) async {
    final shell = Shell();
    final ProcessResult result = await shell.runExecutableArguments('ffprobe', [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      inputPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('Erro ao executar ffprobe: ${result.stderr}');
    }

    final String output = result.stdout.toString().trim();

    if (output.isEmpty) {
      throw Exception(
        'A saída do ffprobe está vazia ou não é um texto válido.',
      );
    }

    final data = json.decode(output);
    return _extractVideoInfo(data);
  }

  Map<String, dynamic> _extractVideoInfo(Map<String, dynamic> data) {
    final videoStream = data['streams']?.firstWhere(
      (stream) => stream['codec_type'] == 'video',
      orElse: () => null,
    );
    final audioStream = data['streams']?.firstWhere(
      (stream) => stream['codec_type'] == 'audio',
      orElse: () => null,
    );

    if (videoStream == null) {
      throw Exception('Nenhum stream de vídeo encontrado');
    }

    double parseFps(dynamic fps) {
      try {
        if (fps == null) return 0.0;
        if (fps is num) return fps.toDouble();
        String fpsString = fps.toString();
        if (fpsString.contains('/')) {
          final parts = fpsString.split('/');
          if (parts.length == 2) {
            double numerator = double.parse(parts[0]);
            double denominator = double.parse(parts[1]);
            if (denominator != 0) return numerator / denominator;
          }
        }
        return double.parse(fpsString);
      } catch (e) {
        return 0.0;
      }
    }

    String safeStringConvert(
      dynamic value, [
      String defaultValue = 'Desconhecido',
    ]) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    int safeIntConvert(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    double safeDoubleConvert(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return {
      'duration': safeDoubleConvert(data['format']?['duration']),
      'file_size': safeIntConvert(data['format']?['size']),
      'bitrate': safeIntConvert(data['format']?['bit_rate']),
      'width': safeIntConvert(videoStream['width']),
      'height': safeIntConvert(videoStream['height']),
      'fps': parseFps(videoStream['r_frame_rate']),
      'video_codec': safeStringConvert(videoStream['codec_name']),
      'pixel_format': safeStringConvert(videoStream['pix_fmt']),
      'video_bitrate': videoStream['bit_rate'] != null
          ? safeIntConvert(videoStream['bit_rate'])
          : null,
      'audio_codec': audioStream != null
          ? safeStringConvert(audioStream['codec_name'], 'Sem áudio')
          : 'Sem áudio',
      'audio_bitrate': audioStream != null && audioStream['bit_rate'] != null
          ? safeIntConvert(audioStream['bit_rate'])
          : null,
      'sample_rate': audioStream != null && audioStream['sample_rate'] != null
          ? safeIntConvert(audioStream['sample_rate'])
          : null,
      'channels': audioStream != null && audioStream['channels'] != null
          ? safeIntConvert(audioStream['channels'])
          : null,
    };
  }

  List<String> buildFfmpegCommand(
    String inputPath,
    String outputPath,
    Map<String, dynamic> videoInfo,
    bool applyUpscaling,
    int targetWidth,
    int targetHeight,
    bool maintainAspectRatio,
    bool applyInterpolation,
    double targetFps,
  ) {
    final cmd = <String>[];
    cmd.addAll(['-i', inputPath]);
    final videoFilters = <String>[];
    const pixFmtFilter = 'format=yuv420p';
    videoFilters.add(pixFmtFilter);
    if (applyUpscaling) {
      if (maintainAspectRatio) {
        final originalWidth = videoInfo['width'];
        final originalHeight = videoInfo['height'];
        final newHeight = (targetWidth * originalHeight / originalWidth)
            .round();
        videoFilters.add(
          'scale=w=$targetWidth:h=$newHeight:force_original_aspect_ratio=decrease',
        );
      } else {
        videoFilters.add('scale=w=$targetWidth:h=$targetHeight');
      }
    }
    if (applyInterpolation) {
      videoFilters.add(
        'minterpolate=mi_mode=mci:mc_mode=obmc:vsbmc=1:fps=${targetFps.toStringAsFixed(1)}',
      );
    }
    if (videoFilters.isNotEmpty) {
      cmd.addAll(['-vf', videoFilters.join(',')]);
    }
    cmd.addAll(['-c:v', 'libx264', '-preset', 'medium']);
    if (videoInfo['video_bitrate'] != null) {
      final bitrate = (videoInfo['video_bitrate'] * 1.5).round();
      if (bitrate >= 1000000) {
        cmd.addAll(['-b:v', '${(bitrate / 1000000).toStringAsFixed(0)}M']);
      } else {
        cmd.addAll(['-b:v', '${(bitrate / 1000).toStringAsFixed(0)}k']);
      }
    } else {
      cmd.addAll(['-b:v', '2M']);
    }
    if (videoInfo['audio_codec'] != 'Sem áudio') {
      cmd.addAll(['-c:a', 'aac', '-b:a', '128k']);
    } else {
      cmd.add('-an');
    }
    cmd.addAll(['-y', outputPath]);
    return cmd;
  }
}
