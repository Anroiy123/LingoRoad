import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.height = 88,
    super.key,
  });

  static const assetPath = 'assets/images/logo_black.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Logo LingoRoad',
      child: ExcludeSemantics(
        child: Align(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: height * 1.9),
            child: SizedBox(
              height: height,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
