import 'dart:async';
import 'package:flutter/material.dart';

/// Published CMS rows only: no hard-coded advertising or private family data.
class ManagedBannerCarousel extends StatefulWidget {
  const ManagedBannerCarousel(
      {super.key, required this.rows, required this.onOpen});
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic>) onOpen;
  @override
  State<ManagedBannerCarousel> createState() => _ManagedBannerCarouselState();
}

class _ManagedBannerCarouselState extends State<ManagedBannerCarousel>
    with WidgetsBindingObserver {
  final pages = PageController();
  Timer? autoplay;
  int index = 0;
  bool paused = false, resumed = true, reducedMotion = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncAutoplay();
  }

  @override
  void didUpdateWidget(ManagedBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (index >= widget.rows.length) {
      index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients) pages.jumpToPage(0);
      });
    }
    syncAutoplay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    syncAutoplay();
  }

  void syncAutoplay() {
    autoplay?.cancel();
    autoplay = null;
    if (!mounted) return;
    final media = MediaQuery.of(context);
    reducedMotion = media.disableAnimations || media.accessibleNavigation;
    if (paused ||
        !resumed ||
        reducedMotion ||
        !TickerMode.valuesOf(context).enabled ||
        media.viewInsets.bottom > 0 ||
        widget.rows.length < 2) {
      return;
    }
    autoplay = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted ||
          !pages.hasClients ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      move((index + 1) % widget.rows.length);
    });
  }

  void move(int target) {
    if (!pages.hasClients || widget.rows.isEmpty) return;
    if (reducedMotion) {
      pages.jumpToPage(target);
    } else {
      pages.animateToPage(target,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic);
    }
  }

  void pause() {
    if (!paused) setState(() => paused = true);
    syncAutoplay();
  }

  @override
  void dispose() {
    autoplay?.cancel();
    pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();
    final extra =
        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0) * 100;
    final dotStart = (index - 3)
        .clamp(0, (widget.rows.length - 7).clamp(0, widget.rows.length))
        .toInt();
    final dotEnd = (dotStart + 7).clamp(0, widget.rows.length).toInt();
    return Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        color: const Color(0xFF0A2438),
        child: Column(children: [
          SizedBox(
              height: 248 + extra,
              child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) pause();
                    return false;
                  },
                  child: PageView.builder(
                      controller: pages,
                      itemCount: widget.rows.length,
                      onPageChanged: (value) => setState(() => index = value),
                      itemBuilder: (context, i) {
                        final row = widget.rows[i];
                        final linked = row['page_id'] is num || row['local_route'] is String;
                        return Semantics(
                            label: 'شريحة ${i + 1} من ${widget.rows.length}',
                            child: Stack(fit: StackFit.expand, children: [
                              const DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                          colors: [
                                    Color(0xFF083C57),
                                    Color(0xFF086C76),
                                    Color(0xFF061528)
                                  ]))),
                              if (row['image_url'] != null)
                                Image.network(row['image_url'] as String,
                                    fit: BoxFit.cover,
                                    excludeFromSemantics: true,
                                    errorBuilder: (_, error, stack) =>
                                        const Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.white38,
                                                    size: 36)))),
                              const DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                    Color(0x19051020),
                                    Color(0xF2051422)
                                  ]))),
                              InkWell(
                                  onTap:
                                      linked ? () => widget.onOpen(row) : null,
                                  child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(22),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Align(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  child: Icon(
                                                      Icons
                                                          .auto_awesome_outlined,
                                                      color: Color(0xFF8DEEDC),
                                                      size: 24)),
                                              const SizedBox(height: 10),
                                              Text(
                                                  row['title'] as String? ?? '',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 23,
                                                      height: 1.4)),
                                              if ((row['subtitle'] ??
                                                      row['body'] ??
                                                      '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                    (row['subtitle'] ??
                                                        row['body']) as String,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFE1F3F5),
                                                        fontSize: 14,
                                                        height: 1.6)),
                                              ],
                                              if (linked)
                                                Align(
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerStart,
                                                    child: TextButton.icon(
                                                        onPressed: () =>
                                                            widget.onOpen(row),
                                                        style: TextButton.styleFrom(
                                                            foregroundColor:
                                                                const Color(
                                                                    0xFF9DF4DE)),
                                                        icon: const Icon(
                                                            Icons
                                                                .arrow_forward_rounded,
                                                            size: 18),
                                                        label: const Text(
                                                            'اعرف أكثر'))),
                                            ]),
                                      ))),
                            ]));
                      }))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                if (widget.rows.length > 1)
                  IconButton(
                      tooltip: 'الشريحة السابقة',
                      color: Colors.white,
                      onPressed: () {
                        pause();
                        move((index - 1 + widget.rows.length) %
                            widget.rows.length);
                      },
                      icon: const Icon(Icons.chevron_right)),
                Expanded(
                    child: Semantics(
                        liveRegion: false,
                        label: 'الشريحة ${index + 1} من ${widget.rows.length}',
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = dotStart; i < dotEnd; i++)
                                Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: AnimatedContainer(
                                        duration: Duration(
                                            milliseconds:
                                                reducedMotion ? 0 : 250),
                                        width: i == index ? 20 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                            color: i == index
                                                ? const Color(0xFF8DEEDC)
                                                : Colors.white38,
                                            borderRadius:
                                                BorderRadius.circular(10)))),
                            ]))),
                if (widget.rows.length > 1) ...[
                  if (!reducedMotion)
                    IconButton(
                        tooltip: paused
                            ? 'تشغيل التقليب التلقائي'
                            : 'إيقاف التقليب التلقائي',
                        color: Colors.white,
                        onPressed: () {
                          setState(() => paused = !paused);
                          syncAutoplay();
                        },
                        icon: Icon(paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded)),
                  IconButton(
                      tooltip: 'الشريحة التالية',
                      color: Colors.white,
                      onPressed: () {
                        pause();
                        move((index + 1) % widget.rows.length);
                      },
                      icon: const Icon(Icons.chevron_left)),
                ],
              ])),
        ]));
  }
}
