import 'package:flutter/material.dart';

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(
            'assets/brand/sundar_tailor_icon.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
