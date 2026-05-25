
void main() {
  Map<String, double> extra = {'a': 1.0};
  Object stateExtra = extra;
  
  try {
    final extraMap = stateExtra as Map<String, dynamic>?;
    print('SUCCESS: \');
  } catch (e) {
    print('FAILED CAST: \');
  }
}

