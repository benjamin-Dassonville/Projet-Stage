import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkerCheckPage extends StatelessWidget {
  final String workerId;

  const WorkerCheckPage({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WCP')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // TODO: WCP ici
            context.go('/');
          },
          child: Text('WCP $workerId'),
        ),
      ),
    );
  }
}