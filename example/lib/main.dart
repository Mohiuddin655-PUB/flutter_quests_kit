import 'package:flutter/material.dart';
import 'package:flutter_quests_kit/flutter_quests_kit.dart';

import 'memory_delegates.dart';

String _today() => DateTime.now().toIso8601String().substring(0, 10);

final server = MemoryProgress(_today);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  QuestsKit.setup(
    catalogDelegate: MemoryCatalog(),
    progressDelegate: server,
    today: _today,
    metrics: const {'chats': CountMetric('chats'), 'likes': CountMetric('likes'), 'dailyDone': DoneMetric('daily')},
  );
  QuestsKit.start('demo');
  runApp(const MaterialApp(home: QuestsPage()));
}

class QuestsPage extends StatelessWidget {
  const QuestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: ListenableBuilder(
        listenable: Listenable.merge([QuestsKit.catalog, QuestsKit.progress]),
        builder: (context, _) {
          final p = QuestsKit.progress;
          return ListView(
            children: [
              ListTile(title: Text('Balance: ${server.balance}')),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(onPressed: () => server.count('chats'), child: const Text('Chat')),
                  FilledButton(onPressed: () => server.count('likes'), child: const Text('Like')),
                ],
              ),
              for (final q in QuestsKit.catalog.enabled)
                ListTile(
                  title: Text('${q.id} (${q.group})'),
                  subtitle: Text('${p.done(q)} / ${q.goal}, +${q.reward}'),
                  trailing: p.isClaimed(q)
                      ? const Icon(Icons.check)
                      : FilledButton(onPressed: p.isComplete(q) ? () => p.claim(q) : null, child: const Text('Claim')),
                ),
            ],
          );
        },
      ),
    );
  }
}
