/// Wraps watermark text without breaking normal words when possible.
List<String> wrapWatermarkText(
  String value,
  int maxChars, {
  int maxLines = 2,
}) {
  if (maxChars <= 0 || maxLines <= 0 || value.trim().isEmpty) {
    return const <String>[];
  }

  final words = value.trim().split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  var truncated = false;

  for (final word in words) {
    if (word.length > maxChars) {
      if (current.isNotEmpty) {
        if (lines.length >= maxLines) {
          truncated = true;
          break;
        }
        lines.add(current);
        current = '';
      }

      var offset = 0;
      while (word.length - offset > maxChars) {
        if (lines.length >= maxLines) {
          truncated = true;
          break;
        }
        lines.add(word.substring(offset, offset + maxChars));
        offset += maxChars;
      }
      if (truncated) break;
      current = word.substring(offset);
      continue;
    }

    final candidate = current.isEmpty ? word : '$current $word';
    if (candidate.length > maxChars && current.isNotEmpty) {
      if (lines.length >= maxLines) {
        truncated = true;
        break;
      }
      lines.add(current);
      current = word;
    } else {
      current = candidate;
    }
  }

  if (current.isNotEmpty) {
    if (lines.length < maxLines) {
      lines.add(current);
    } else {
      truncated = true;
    }
  }

  if (truncated && lines.isNotEmpty) {
    final last = lines.last;
    lines[lines.length - 1] = maxChars == 1
        ? '…'
        : '${last.substring(0, last.length.clamp(0, maxChars - 1))}…';
  }
  return lines;
}
