import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:gradeflow/nav.dart';
import 'package:gradeflow/services/class_service.dart';

/// Class navigation in the approved teaching shell; no duplicate class records.
class ClassDirectorySurface extends StatelessWidget {
  const ClassDirectorySurface({super.key});
  @override
  Widget build(BuildContext context) {
    final service = context.watch<ClassService>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        backgroundColor:
            dark ? const Color(0xff07131f) : const Color(0xfff0f5fa),
        body: SafeArea(
            child: CustomScrollView(slivers: [
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              sliver: SliverToBoxAdapter(
                  child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xff173b63), Color(0xff187f79)]),
                          borderRadius: BorderRadius.circular(24)),
                      child: Row(children: [
                        IconButton(
                            tooltip: 'Back to Home',
                            onPressed: () => context.go(AppRoutes.osHome),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Your classes',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                              Text('${service.classes.length} active classes',
                                  style: const TextStyle(color: Colors.white70))
                            ])),
                        IconButton(
                          tooltip: 'Manage class records and imports',
                          onPressed: () => context.go(AppRoutes.classes),
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                        ),
                      ])))),
          if (service.isLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (!service.isLoading && service.classes.isEmpty)
            const SliverFillRemaining(
                child: Center(child: Text('No active classes yet.'))),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverList.builder(
                  itemCount: service.classes.length,
                  itemBuilder: (context, index) {
                    final item = service.classes[index];
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 20,
                                    runSpacing: 12,
                                    children: [
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.className,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(
                                                '${item.subject} · ${item.schoolYear} ${item.term}')
                                          ]),
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                                onPressed: () => context.go(
                                                    AppRoutes.osClassGradebook(
                                                        item.classId)),
                                                icon: const Icon(
                                                    Icons.grid_on_outlined),
                                                label: const Text('Gradebook')),
                                            FilledButton.icon(
                                                onPressed: () => context.go(
                                                    AppRoutes.osClassroom(
                                                        item.classId)),
                                                icon: const Icon(Icons
                                                    .meeting_room_outlined),
                                                label: const Text(
                                                    'Open classroom'))
                                          ])
                                    ]))));
                  })),
        ])));
  }
}
