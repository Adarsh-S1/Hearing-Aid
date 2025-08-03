import 'dart:math';

class LeakyBucket {
  final int capacity; // Maximum tokens the bucket can hold
  final double leakRatePerSecond; // Tokens leaked per second
  double _currentTokens = 0.0; // Current tokens in the bucket
  int _lastLeakTime; // Timestamp of the last leak check (milliseconds)

  LeakyBucket({required this.capacity, required this.leakRatePerSecond})
    : _lastLeakTime = DateTime.now().millisecondsSinceEpoch;

  /// Checks if a request of [requestSize] can be allowed.
  bool allowRequest([int requestSize = 1]) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final double elapsedSeconds = (now - _lastLeakTime) / 1000;
    final double tokensToLeak = elapsedSeconds * leakRatePerSecond;

    // Update current tokens by leaking tokens based on elapsed time
    _currentTokens = max(_currentTokens - tokensToLeak, 0.0);
    print("this is the current token : " + _currentTokens.toString());

    // Check if adding the request exceeds the bucket's capacity
    if (_currentTokens + requestSize <= capacity) {
      _currentTokens += requestSize;
      _lastLeakTime = now;
      return true;
    } else {
      _lastLeakTime = now;
      return false;
    }
  }
}
