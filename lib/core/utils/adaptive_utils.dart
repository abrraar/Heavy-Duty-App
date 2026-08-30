import 'package:flutter/material.dart';
import '../constants/dimensions.dart';

class AdaptiveUtils {
  AdaptiveUtils._();

  static Future<T?> showAdaptiveSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, bool isSideSheet) sheetBuilder,
    bool isScrollControlled = true,
  }) async {
    final bool isLargeScreen = MediaQuery.of(context).size.width >= kTabletBreakpoint;
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bool isFoldableUnfolded = MediaQuery.of(context).size.width > 600 && 
        (MediaQuery.of(context).size.width / MediaQuery.of(context).size.height < 1.3);

    if ((isLargeScreen && isLandscape) || isFoldableUnfolded) {
      return await _showSideSheet<T>(context, (sheetContext) => sheetBuilder(sheetContext, true));
    } else {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        useRootNavigator: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => sheetBuilder(sheetContext, false),
      );
    }
  }

  static Future<T?> _showSideSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Side Sheet",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: kMaxFormWidth,
              height: double.infinity,
              child: builder(context),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}
