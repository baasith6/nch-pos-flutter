
import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Abdul Baasith\.gemini\antigravity-ide\brain\f7400033-5d5b-4031-b2e9-e88d9abfb1ce\.system_generated\logs\transcript.jsonl');
  final lines = await file.readAsLines();
  
  for (final line in lines) {
    if (line.contains('checkout_screen.dart')) {
      final obj = jsonDecode(line);
      if (obj['step_index'] == 2864) {
         File('s_2864.txt').writeAsStringSync(obj['content']);
      }
      if (obj['step_index'] == 2867) {
         File('s_2867.txt').writeAsStringSync(obj['content']);
      }
      if (obj['step_index'] == 2870) {
         File('s_2870.txt').writeAsStringSync(obj['content']);
      }
    }
  }
}

