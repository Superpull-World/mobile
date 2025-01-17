import 'dart:async';

mixin RefreshManager<T> {
  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;
  T? _cachedData;
  Duration _refreshInterval = const Duration(seconds: 10);
  final _controller = StreamController<T>.broadcast();

  Stream<T> get dataStream => _controller.stream;

  bool get hasValidCache {
    if (_lastRefreshTime == null || _cachedData == null) return false;
    final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
    return timeSinceLastRefresh < _refreshInterval;
  }

  void startPeriodicRefresh(
    Future<T> Function() fetchData, {
    Duration? interval,
  }) {
    if (interval != null) {
      _refreshInterval = interval;
    }
    
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) async {
      await _refreshData(fetchData);
    });
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<T> getDataWithRefresh(Future<T> Function() fetchData) async {
    if (hasValidCache) {
      return _cachedData!;
    }
    return _refreshData(fetchData);
  }

  Future<T> forceRefresh(Future<T> Function() fetchData) async {
    return _refreshData(fetchData);
  }

  Future<T> _refreshData(Future<T> Function() fetchData) async {
    try {
      final freshData = await fetchData();
      _cachedData = freshData;
      _lastRefreshTime = DateTime.now();
      _controller.add(freshData);
      return freshData;
    } catch (e) {
      if (_cachedData != null) {
        return _cachedData!;
      }
      rethrow;
    }
  }

  void dispose() {
    stopPeriodicRefresh();
    _controller.close();
  }
} 