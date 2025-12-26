import 'package:flutter/material.dart';

/// Responsive wrapper that constrains content width on larger screens
/// Makes the UI look better on web/desktop
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool centerOnWeb;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = EdgeInsets.zero,
    this.centerOnWeb = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If screen is wider than maxWidth, constrain the content
        if (constraints.maxWidth > maxWidth) {
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: padding,
              child: child,
            ),
          );
        }
        // On smaller screens, use full width
        return Padding(
          padding: padding,
          child: child,
        );
      },
    );
  }
}

/// Responsive scaffold that applies consistent max-width on web
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final double maxContentWidth;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.maxContentWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: body,
        ),
      ),
    );
  }
}

/// Returns appropriate button padding based on screen size
EdgeInsets responsiveButtonPadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width > 600) {
    return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
  }
  return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}

/// Returns appropriate font size based on screen width
double responsiveFontSize(BuildContext context, double baseSizeMobile, double baseSizeDesktop) {
  final width = MediaQuery.of(context).size.width;
  if (width > 600) {
    return baseSizeDesktop;
  }
  return baseSizeMobile;
}
