import 'package:flutter/material.dart';

import '../tasks/screens/task_list_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TaskListPage();
  }
}
