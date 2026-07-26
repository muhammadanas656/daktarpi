import 'package:flutter/material.dart';
import '../theme/app_styles.dart'; 

class VolumetricScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;
  final VolumetricTier tier; // PRO FIX: Inject the tier

  const VolumetricScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true, 
    this.extendBody = true,             
    this.resizeToAvoidBottomInset,
    this.tier = VolumetricTier.elevated, // Defaults to the rich spotlight glow
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppStyles.pageGradient(context),
      ),
      child: Container(
        decoration: AppStyles.ambientVolumetricTheme(context, tier: tier),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          extendBody: extendBody,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        ),
      ),
    );
  }
}
