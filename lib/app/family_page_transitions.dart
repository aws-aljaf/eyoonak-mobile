import 'package:flutter/material.dart';

class FamilyPageTransitionsBuilder extends PageTransitionsBuilder {
  const FamilyPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: curved,
        child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(.035, .02), end: Offset.zero).animate(curved), child: child));
  }
}
