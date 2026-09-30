import 'dart:async';

import 'package:materium/flutter.dart';

mixin CustomPullToRefreshStates implements PullToRefreshStates {
  double get layoutFraction;

  double get layoutHeight;
}

class CustomPullToRefreshController extends PullToRefreshSpringController
    implements CustomPullToRefreshStates {
  CustomPullToRefreshController({
    super.onRefresh,
    super.enabled,
    super.threshold,
    super.isRefreshing,
    required super.vsync,
    super.spring,
    super.debugLabel,
  });

  Simulation? _simulation;

  double get _velocity {
    if (_simulation case final simulation? when isAnimating) {
      return simulation.dx(
        lastElapsedDuration.inMicroseconds / Duration.microsecondsPerSecond,
      );
    }
    return 0.0;
  }

  double _layoutFraction = 0.0;

  @override
  double get layoutFraction => _layoutFraction;

  @override
  double get layoutHeight => layoutFraction * threshold;

  Simulation _createSimulation(double targetValue) => SpringSimulation(
    spring,
    _layoutFraction,
    targetValue,
    _velocity,
    snapToEnd: true,
  );

  @override
  void tick() {
    super.tick();
    if (_simulation case final simulation?) {
      _layoutFraction = simulation.x(lastElapsedInSeconds);
      if (simulation.isDone(lastElapsedInSeconds)) {
        _simulation = null;
      }
    }
  }

  @override
  void animateToThreshold() {
    final simulation = _createSimulation(0.0);
    super.animateToThreshold();
    _simulation = simulation;
    _layoutFraction = simulation.x(0.0);
  }

  @override
  void animateToHidden() {
    final simulation = _createSimulation(0.0);
    super.animateToHidden();
    _simulation = simulation;
    _layoutFraction = simulation.x(0.0);
  }

  @override
  void snapTo(double targetValue) {
    super.snapTo(targetValue);
    if (!isRefreshing) {
      _simulation = null;
      _layoutFraction = targetValue;
    }
  }

  @mustCallSuper
  @override
  void stop({bool canceled = true}) {
    super.stop(canceled: canceled);
    _simulation = null;
  }
}

typedef CustomPullToRefreshBuilder =
    Widget Function(
      BuildContext context,
      CustomPullToRefreshController controller,
    );

class CustomPullToRefresh extends StatefulWidget {
  const CustomPullToRefresh({
    super.key,
    required this.onRefresh,
    this.enabled = true,
    this.spring,
    this.threshold = PullToRefreshController.defaultThreshold,
    required this.builder,
  });

  final RefreshCallback onRefresh;

  final bool enabled;

  final SpringDescription? spring;

  final double threshold;

  final CustomPullToRefreshBuilder builder;

  @override
  CustomPullToRefreshState createState() => CustomPullToRefreshState();
}

class CustomPullToRefreshState extends State<CustomPullToRefresh>
    with SingleTickerProviderStateMixin {
  late CustomPullToRefreshController _controller;

  Future<void>? _refreshFuture;

  void _onRefresh() {
    if (!mounted) return;

    final completer = Completer<void>();
    _refreshFuture = completer.future;

    _controller.isRefreshing = true;

    unawaited(
      widget.onRefresh().whenComplete(() {
        if (!mounted) return;

        _controller.isRefreshing = false;

        if (!completer.isCompleted) {
          completer.complete();
        }

        _refreshFuture = null;
      }),
    );
  }

  // ValueListenable<PullToRefreshStates> get states => _controller;

  Future<void> show() {
    if (!mounted) return Future.value();
    if (_refreshFuture case final refreshFuture?) {
      return refreshFuture;
    }
    _onRefresh();
    return _refreshFuture ?? Future.value();
  }

  // TODO: implement?
  // bool dismiss() {}

  @override
  void initState() {
    super.initState();
    _controller = CustomPullToRefreshController(
      onRefresh: _onRefresh,
      enabled: widget.enabled,
      threshold: widget.threshold,
      vsync: this,
      spring: widget.spring ?? PullToRefreshSpringController.defaultSpring,
    );
  }

  @override
  void didUpdateWidget(covariant CustomPullToRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spring != oldWidget.spring) {
      _controller.spring =
          widget.spring ?? PullToRefreshSpringController.defaultSpring;
    }
    _controller.enabled = widget.enabled;
    _controller.threshold = widget.threshold;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
