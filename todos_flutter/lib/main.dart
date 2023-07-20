import 'dart:async';

import 'package:electric_client/electric_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:todos_electrified/database/database.dart';
import 'package:todos_electrified/database/drift/connection/connection.dart'
    as impl;
import 'package:todos_electrified/database/drift/database.dart' hide Todo;
import 'package:todos_electrified/electric.dart';
import 'package:todos_electrified/todos.dart';
import 'package:todos_electrified/util.dart';
import 'package:animated_emoji/animated_emoji.dart';

const kClientId = "FAKE-CLIENT-ID";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(_Entrypoint());
}

typedef _InitData = ({
  TodosDatabase todosDb,
  ElectricClient electricClient,
  ConnectivityStateController connectivityStateController,
});

class _Entrypoint extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final initDataVN = useState<_InitData?>(null);
    useEffect(() {
      () async {
        final driftRepo = await initDriftTodosDatabase();
        final todosDb = TodosDatabase(driftRepo);
        // final sqliteRepo = initSqliteRepository(dbPath);
        // final todosDb = TodosDatabase(sqliteRepo);
        // final adapter = SqliteAdapter(sqliteRepo.db);

        const dbName = "todos_db";
        final electricClient = await startElectricDrift(dbName, driftRepo.db);

        final connectivityStateController =
            ConnectivityStateController(electricClient)..init();

        initDataVN.value = (
          todosDb: todosDb,
          electricClient: electricClient,
          connectivityStateController: connectivityStateController,
        );
      }();
      return null;
    }, []);

    final initData = initDataVN.value;
    if (initData == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ProviderScope(
      overrides: [
        todosDatabaseProvider.overrideWithValue(initData.todosDb),
        electricClientProvider.overrideWithValue(initData.electricClient),
        connectivityStateControllerProvider
            .overrideWith(((ref) => initData.connectivityStateController)),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends HookConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAV = ref.watch(todosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Center(
            child: FlutterLogo(
          size: 35,
        )),
        title: Row(
          children: [
            const Text("todos", style: TextStyle(fontSize: 30)),
            const SizedBox(width: 20),
            Icon(getIconForPlatform()),
            const SizedBox(width: 5),
            Text(getPlatformName()),
            const SizedBox(width: 10),
            const AnimatedEmoji(
              AnimatedEmojis.electricity,
              size: 24,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const _ConnectivityStatusText(),
          const SizedBox(height: 10),
          const ConnectivityButton(),
          const SizedBox(height: 10),
          Expanded(
            child: todosAV.when(
              data: (todos) {
                return _TodosLoaded(todos: todos);
              },
              error: (e, st) {
                return Center(child: Text(e.toString()));
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          if (!kIsWeb)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: _DeleteDbButton(),
              ),
            )
        ],
      ),
    );
  }
}

class _ConnectivityStatusText extends ConsumerWidget {
  const _ConnectivityStatusText();

  @override
  Widget build(BuildContext context, ref) {
    final connectivity = ref.watch(connectivityStateControllerProvider
        .select((value) => value.connectivityState));

    Color? textColor = Theme.of(context).textTheme.bodySmall!.color;
    if (connectivity == ConnectivityState.disconnected) {
      textColor = Theme.of(context).colorScheme.error;
    }

    return Text(
      connectivity.name,
      style: TextStyle(color: textColor),
    );
  }
}

class _DeleteDbButton extends StatelessWidget {
  const _DeleteDbButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Colors.red),
      onPressed: () async {
        await impl.deleteTodosDbFile();

        // TODO: False positive remove in Dart 3.1.0
        // ignore: use_build_context_synchronously
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Database deleted, restart the app")),
        );
      },
      icon: const Icon(Icons.delete),
      label: const Text("Delete local database"),
    );
  }
}

class ConnectivityButton extends HookConsumerWidget {
  const ConnectivityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(
      connectivityStateControllerProvider
          .select((value) => value.connectivityState),
    );

    return ElevatedButton(
      onPressed: () async {
        final connectivityStateController =
            ref.read(connectivityStateControllerProvider);
        connectivityStateController.toggleConnectivityState();
      },
      child: Text(
        connectivityState == ConnectivityState.connected
            ? "Disconnect"
            : "Connect",
      ),
    );
  }
}

class _TodosLoaded extends HookConsumerWidget {
  const _TodosLoaded({required this.todos});

  final List<Todo> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();

    return Align(
      alignment: Alignment.topCenter,
      child: Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: "What needs to be done?",
                  ),
                  onEditingComplete: () async {
                    print("done");
                    final db = ref.read(todosDatabaseProvider);
                    await db.insertTodo(
                      Todo(
                        id: newUUID(),
                        listId: kClientId,
                        text: textController.text,
                        completed: false,
                      ),
                    );

                    textController.clear();

                    // final satellite = ref.read(satelliteProvider);
                    // satellite.notifier.potentiallyChanged();
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    separatorBuilder: (context, i) => const Divider(
                      height: 0,
                    ),
                    itemBuilder: (context, i) {
                      return TodoTile(todo: todos[i]);
                    },
                    itemCount: todos.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodoTile extends ConsumerWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: IconButton(
        onPressed: () async {
          final db = ref.read(todosDatabaseProvider);
          await db.updateTodo(todo.copyWith(completed: !todo.completed));

          // final satellite = ref.read(satelliteProvider);
          // satellite.notifier.potentiallyChanged();
        },
        icon: todo.completed
            ? const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              )
            : const Icon(Icons.circle_outlined),
      ),
      title: Text(
        todo.text ?? "",
        style: TextStyle(
          decoration: todo.completed ? TextDecoration.lineThrough : null,
          color: todo.completed ? Colors.grey : null,
        ),
      ),
      trailing: IconButton(
        onPressed: () async {
          final db = ref.read(todosDatabaseProvider);
          await db.removeTodo(todo.id);

          // final satellite = ref.read(satelliteProvider);
          // satellite.notifier.potentiallyChanged();
        },
        icon: const Icon(Icons.delete),
      ),
    );
  }
}

IconData getIconForPlatform() {
  if (kIsWeb) {
    return MdiIcons.web;
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return MdiIcons.android;
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return MdiIcons.appleIos;
  } else if (defaultTargetPlatform == TargetPlatform.fuchsia) {
    return MdiIcons.google;
  } else if (defaultTargetPlatform == TargetPlatform.linux) {
    return MdiIcons.linux;
  } else if (defaultTargetPlatform == TargetPlatform.windows) {
    return MdiIcons.microsoftWindows;
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    return MdiIcons.apple;
  } else {
    return Icons.help_outline;
  }
}

String getPlatformName() {
  if (kIsWeb) {
    return "Web";
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    return "Android";
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return "iOS";
  } else if (defaultTargetPlatform == TargetPlatform.fuchsia) {
    return "Fuchsia";
  } else if (defaultTargetPlatform == TargetPlatform.linux) {
    return "Linux";
  } else if (defaultTargetPlatform == TargetPlatform.windows) {
    return "Windows";
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    return "macOS";
  } else {
    return "Unknown";
  }
}
