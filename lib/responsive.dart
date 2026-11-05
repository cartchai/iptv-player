// Responsive layout — one shell, same widgets, rearranged by available width.
//
// Fold 7 targets (the widths that matter):
//   cover screen (folded)  ~360-420dp wide  -> phone  (narrow, bottom nav)
//   unfolded main screen   ~700-800dp wide  -> tablet (rail + two-pane)
//   TV 16:9 landscape      >=1000dp wide    -> wide   (rail + wide two-pane)
//   Quest large panel      >=1000dp wide    -> wide
//
// Breakpoints are on *available width* (LayoutBuilder constraints), not on
// device type, so folding/unfolding just rebuilds the shell with the same
// widgets — no separate phone/TV code paths, no restart. The state that must
// survive a fold/unfold (player, selection, scroll) lives in AppState, which
// is provided *above* this widget, so a resize rebuild never recreates it.
import 'package:flutter/widgets.dart';

/// Width breakpoints (logical dp).
class AppBreakpoints {
  /// Below this: phone / Fold 7 cover screen.
  static const double phoneMaxWidth = 600;

  /// At/above this: TV / Quest large panel / large tablet.
  static const double wideMinWidth = 1000;
}

enum FormFactor { phone, tablet, wide }

FormFactor formFactorForWidth(double width) {
  if (width < AppBreakpoints.phoneMaxWidth) return FormFactor.phone;
  if (width < AppBreakpoints.wideMinWidth) return FormFactor.tablet;
  return FormFactor.wide;
}

/// Builds one of three branches from the *available* width. [tablet] and
/// [wide] fall back to each other when omitted, so callers can supply just
/// narrow + wide and still cover tablets.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.narrow,
    this.tablet,
    this.wide,
  });

  final WidgetBuilder narrow;
  final WidgetBuilder? tablet;
  final WidgetBuilder? wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = formFactorForWidth(constraints.maxWidth);
        switch (formFactor) {
          case FormFactor.phone:
            return narrow(context);
          case FormFactor.tablet:
            return (tablet ?? wide ?? narrow)(context);
          case FormFactor.wide:
            return (wide ?? tablet ?? narrow)(context);
        }
      },
    );
  }
}

/// Convenience reads off MediaQuery (for code that only needs a yes/no).
extension ResponsiveContext on BuildContext {
  FormFactor get formFactor => formFactorForWidth(MediaQuery.sizeOf(this).width);
  bool get isPhone => formFactor == FormFactor.phone;
  bool get isTablet => formFactor == FormFactor.tablet;
  bool get isWide => formFactor == FormFactor.wide;
  bool get isLandscape => MediaQuery.sizeOf(this).aspectRatio > 1;
}
