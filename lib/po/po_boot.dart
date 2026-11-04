import 'dart:async';

import 'package:flutter/material.dart';

import 'po_design.dart';

class PoBoot extends StatefulWidget {
  const PoBoot({super.key, required this.application});
  final Widget application;
  @override
  State<PoBoot> createState() => _PoBootState();
}

class _PoBootState extends State<PoBoot> {
  bool ready = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ready
      ? widget.application
      : MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: poTheme(),
          home: const Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MimiBee(size: 180),
                    Text(
                      'MimiGo',
                      style: TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        color: PoPalette.plum,
                      ),
                    ),
                    Text('Cùng con mở ra một thế giới mới'),
                    SizedBox(height: 24),
                    SizedBox(width: 100, child: LinearProgressIndicator()),
                  ],
                ),
              ),
            ),
          ),
        );
}
