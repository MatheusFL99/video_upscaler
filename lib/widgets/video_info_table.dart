import 'package:flutter/material.dart';
import 'dart:math';

class VideoInfoTable extends StatelessWidget {
  final Map<String, dynamic> videoInfo;

  const VideoInfoTable({super.key, required this.videoInfo});

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'N/A';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatBitrate(int? bps) {
    if (bps == null || bps <= 0) return 'N/A';
    if (bps < 1000) return '$bps bps';
    if (bps < 1000000) return '${(bps / 1000).toStringAsFixed(0)} Kbps';
    return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN) return 'N/A';
    int hours = (seconds / 3600).truncate();
    int minutes = ((seconds % 3600) / 60).truncate();
    int secs = (seconds % 60).truncate();
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  TableRow _buildInfoRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Text(value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = videoInfo;
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: [
        _buildInfoRow('Resolução', '${info['width']}x${info['height']}'),
        _buildInfoRow(
          'Taxa de Quadros',
          '${info['fps'].toStringAsFixed(2)} fps',
        ),
        _buildInfoRow('Duração', _formatDuration(info['duration'])),
        _buildInfoRow('Tamanho do Arquivo', _formatFileSize(info['file_size'])),
        _buildInfoRow('Bitrate Total', _formatBitrate(info['bitrate'])),
        _buildInfoRow(
          'Codec de Vídeo',
          (info['video_codec'] as String).toUpperCase(),
        ),
        _buildInfoRow(
          'Bitrate de Vídeo',
          _formatBitrate(info['video_bitrate']),
        ),
        _buildInfoRow(
          'Codec de Áudio',
          (info['audio_codec'] as String).toUpperCase(),
        ),
        _buildInfoRow(
          'Bitrate de Áudio',
          _formatBitrate(info['audio_bitrate']),
        ),
        _buildInfoRow('Formato de Pixel', info['pixel_format']),
      ],
    );
  }
}
