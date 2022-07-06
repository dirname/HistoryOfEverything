import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:timeline/bloc_provider.dart';
import 'package:timeline/timeline/timeline.dart';
import 'package:timeline/timeline/timeline_entry.dart';

/// This widget renders a Flare/Nima [FlutterActor]. It relies on a [LeafRenderObjectWidget]
/// so it can implement a custom [RenderObject] and update it accordingly.
class MenuVignette extends LeafRenderObjectWidget {
  /// A flag is used to animate the widget only when needed.
  final bool isActive;

  /// The id of the [FlutterActor] that will be rendered.
  final String assetId;

  /// A gradient color to give the section background a faded look.
  /// Also makes the sub-section more readable.
  final Color gradientColor;

  MenuVignette({Key key, this.gradientColor, this.isActive, this.assetId})
      : super(key: key);

  @override
  RenderObject createRenderObject(BuildContext context) {
    /// The [BlocProvider] widgets down the tree to access its components
    /// optimizing memory consumption and simplifying the code-base.
    Timeline t = BlocProvider.getTimeline(context);
    return MenuVignetteRenderObject()
      ..timeline = t
      ..assetId = assetId
      ..gradientColor = gradientColor
      ..isActive = isActive;
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant MenuVignetteRenderObject renderObject) {
    /// The [BlocProvider] widgets down the tree to access its components
    /// optimizing memory consumption and simplifying the code-base.
    Timeline t = BlocProvider.getTimeline(context);
    renderObject
      ..timeline = t
      ..assetId = assetId
      ..gradientColor = gradientColor
      ..isActive = isActive;
  }

  @override
  didUnmountRenderObject(covariant MenuVignetteRenderObject renderObject) {
    renderObject.isActive = false;
  }
}

/// When extending a [RenderBox] we provide a custom set of instructions for the widget being rendered.
///
/// In particular this means overriding the [paint()] and [hitTestSelf()] methods to render the loaded
/// Flare/Nima [FlutterActor] where the widget is being placed.
class MenuVignetteRenderObject extends RenderBox {
  /// The [_timeline] object is used here to retrieve the asset through [getById()].
  Timeline _timeline;
  String _assetId;

  /// If this object is not active, stop playing. This optimizes resource consumption
  /// and makes sure that each [FlutterActor] remains coherent throughout its animation.
  bool _isActive = false;
  bool _firstUpdate = true;
  double _lastFrameTime = 0.0;
  Color gradientColor;
  bool _isFrameScheduled = false;
  double opacity = 0.0;

  Timeline get timeline => _timeline;
  set timeline(Timeline value) {
    if (_timeline == value) {
      return;
    }
    _timeline = value;
    _firstUpdate = true;
    updateRendering();
  }

  set assetId(String id) {
    if (_assetId != id) {
      _assetId = id;
      updateRendering();
    }
  }

  bool get isActive => _isActive;
  set isActive(bool value) {
    if (_isActive == value) {
      return;
    }

    /// When this [RenderBox] becomes active, start advancing it again.
    _isActive = value;
    updateRendering();
  }

  TimelineEntry get timelineEntry {
    if (_timeline == null) {
      return null;
    }
    return _timeline.getById(_assetId);
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTestSelf(Offset screenOffset) => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  /// Uses the [SchedulerBinding] to trigger a new paint for this widget.
  void updateRendering() {
    if (_isActive) {
      markNeedsPaint();
      if (!_isFrameScheduled) {
        _isFrameScheduled = true;
        SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
      }
    }
    markNeedsLayout();
  }

  /// This overridden method is where we can implement our custom drawing logic, for
  /// laying out the [FlutterActor], and drawing it to [canvas].
  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    TimelineAsset asset = timelineEntry?.asset;

    /// Don't paint if not needed.
    if (asset == null) {
      opacity = 0.0;
      return;
    }

    canvas.save();

    double w = asset.width;
    double h = asset.height;

    /// If the asset is just a static image, draw the image directly to [canvas].
    if (asset is TimelineImage) {
      canvas.drawImageRect(
          asset.image,
          Rect.fromLTWH(0.0, 0.0, asset.width, asset.height),
          Rect.fromLTWH(offset.dx + size.width - w, asset.y, w, h),
          Paint()
            ..isAntiAlias = true
            ..filterQuality = ui.FilterQuality.low
            ..color = Colors.white.withOpacity(asset.opacity));
    }
    canvas.restore();
  }

  /// This callback is used by the [SchedulerBinding] in order to advance the Flare/Nima
  /// animations properly, and update the corresponding [FlutterActor]s.
  /// It is also responsible for advancing any attached components to said Actors,
  /// such as [_nimaController] or [_flareController].
  void beginFrame(Duration timeStamp) {
    _isFrameScheduled = false;
    final double t =
        timeStamp.inMicroseconds / Duration.microsecondsPerMillisecond / 1000.0;
    if (_lastFrameTime == 0) {
      _isFrameScheduled = true;
      _lastFrameTime = t;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
      return;
    }

    /// Calculate the elapsed time to [advance()] the animations.
    double elapsed = t - _lastFrameTime;
    _lastFrameTime = t;
    TimelineEntry entry = timelineEntry;
    if (entry != null) {
      TimelineAsset asset = entry.asset;
    }

    /// Invalidate the current widget visual state and let Flutter paint it again.
    markNeedsPaint();

    /// Schedule a new frame to update again - but only if needed.
    if (isActive && !_isFrameScheduled) {
      _isFrameScheduled = true;
      SchedulerBinding.instance.scheduleFrameCallback(beginFrame);
    }
  }
}
