import 'dart:async';
import 'dart:io';

import 'package:electricsql/drivers/drift.dart';
import 'package:satellite_dart_client/client_commands.dart';
import 'package:satellite_dart_client/cli/reader.dart';
import 'package:satellite_dart_client/cli/tokens.dart';
import 'package:satellite_dart_client/util/generic_db.dart';
import 'package:satellite_dart_client/cli/state.dart';

Future<void> start() async {
  final reader = createReader();

  stdout.write(">>> ");

  final state = AppState();
  await for (final input in reader()) {
    try {
      final command = await parseCommand(input, state);

      if (command == null) {
        break;
      }

      //print(command);

      final name = command.name;

      if (name == "exit") {
        break;
      } else if (name == "get_shell_db_path") {
        final luxShellName = command.arguments[0] as String;

        final dbPath =
            "${Platform.environment["SATELLITE_DB_PATH"]!}/$luxShellName";
        await processCommand<String>(state, command, () {
          return dbPath;
        });
      } else if (name == "make_db") {
        final dbPath = command.arguments[0] as String;
        await processCommand<GenericDb>(state, command, () async {
          return await makeDb(dbPath);
        });
      } else if (name == "assignVar") {
        await processCommand<dynamic>(state, command, () async {
          final value = command.arguments[0];
          return value;
        });
      } else if (name == "showVar") {
        await processCommand<dynamic>(state, command, () async {
          final value = command.arguments[0];
          return value;
        });
      } else if (name == "electrify_db") {
        await processCommand<DriftElectricClient>(state, command, () async {
          final db = command.arguments[0] as GenericDb;
          final dbName = "db_${db.hashCode.toString()}";
          final host = command.arguments[1] as String;
          final port = command.arguments[2] as int;
          final migrationsJ = command.arguments[3] as List<dynamic>;

          return await electrifyDb(
            db,
            dbName,
            host,
            port,
            migrationsJ,
          );
        });
      } else if (name == "sync_table") {
        final electric = command.arguments[0] as DriftElectricClient;
        final table = command.arguments[1] as String;
        await processCommand<void>(state, command, () async {
          return await syncTable(electric, table);
        });
      } else if (name == "get_tables") {
        final electric = command.arguments[0] as DriftElectricClient;
        await processCommand<List<Row>>(state, command, () async {
          return await getTables(electric);
        });
      } else if (name == "get_columns") {
        final electric = command.arguments[0] as DriftElectricClient;
        final table = command.arguments[1] as String;
        await processCommand<List<Row>>(state, command, () async {
          return await getColumns(electric, table);
        });
      } else if (name == "get_items") {
        final electric = command.arguments[0] as DriftElectricClient;
        await processCommand<List<Row>>(state, command, () async {
          return await getItems(electric);
        });
      } else if (name == "get_item_ids") {
        final electric = command.arguments[0] as DriftElectricClient;
        await processCommand<List<Row>>(state, command, () async {
          return await getItemIds(electric);
        });
      } else if (name == "get_item_columns") {
        final electric = command.arguments[0] as DriftElectricClient;
        final table = command.arguments[1] as String;
        final column = command.arguments[2] as String;
        await processCommand<List<Row>>(state, command, () async {
          return await getItemColumns(electric, table, column);
        });
      } else if (name == "insert_item") {
        final electric = command.arguments[0] as DriftElectricClient;
        final keys = (command.arguments[1] as List<dynamic>).cast<String>();
        await processCommand<void>(state, command, () async {
          return await insertItem(electric, keys);
        });
      } else if (name == "insert_extended_item") {
        final electric = command.arguments[0] as DriftElectricClient;
        final values = (command.arguments[1] as Map<String, dynamic>)
            .cast<String, String>();
        await processCommand<void>(state, command, () async {
          return await insertExtendedItem(electric, values);
        });
      } else if (name == "delete_item") {
        final electric = command.arguments[0] as DriftElectricClient;
        final keys = (command.arguments[1] as List<dynamic>).cast<String>();
        await processCommand<void>(state, command, () async {
          return await deleteItem(electric, keys);
        });
      } else if (name == "get_other_items") {
        final electric = command.arguments[0] as DriftElectricClient;
        await processCommand<List<Row>>(state, command, () async {
          return await getOtherItems(electric);
        });
      } else if (name == "insert_other_item") {
        final electric = command.arguments[0] as DriftElectricClient;
        final keys = (command.arguments[1] as List<dynamic>).cast<String>();
        await processCommand<void>(state, command, () async {
          return await insertOtherItem(electric, keys);
        });
      } else if (name == "stop") {
        final electric = command.arguments[0] as DriftElectricClient;
        await processCommand<void>(state, command, () async {
          return await stop(electric);
        });
      } else if (name == "raw_statement") {
        final electric = command.arguments[0] as DriftElectricClient;
        final sql = command.arguments[1] as String;
        await processCommand<void>(state, command, () async {
          return await rawStatement(electric, sql);
        });
      } else if (name == "change_connectivity") {
        final electric = command.arguments[0] as DriftElectricClient;
        final connectivityName = command.arguments[1] as String;
        await processCommand<void>(state, command, () {
          return changeConnectivity(electric, connectivityName);
        });
      } else {
        throw Exception("Unknown command: $name");
      }

      stdout.write(">>> ");
    } catch (e, st) {
      print("ERROR: $e\n$st");

      exit(1);
    }
  }
}

Future<void> processCommand<T>(
  AppState state,
  Command command,
  FutureOr<T> Function() handler,
) async {
  final res = await handler();

  if (command.variable != null) {
    state.variables[command.variable!] = res;
  }

  // Log output of the command
  print(res);
}

Future<Command?> parseCommand(String input, AppState appState) async {
  input = input.trim();

  if (input.isEmpty) return null;

  var tokens = await extractTokens(appState, input);

  String? variable;
  if (tokens.length >= 3) {
    if (tokens[1].text == "=") {
      variable = tokens[0].text;
      tokens = tokens.sublist(2);
    }
  }

  final String name;
  final List<Token> effectiveArgs;
  if (tokens.length == 1 && variable != null) {
    name = "assignVar";
    effectiveArgs = tokens;
  } else if (tokens.length == 1 && tokens.first.dartValue is! ArgIdentifier) {
    name = "showVar";
    effectiveArgs = [tokens.first];
  } else if (tokens.isEmpty) {
    throw Exception("Empty command");
  } else {
    name = (tokens.removeAt(0).dartValue as ArgIdentifier).name;
    effectiveArgs = tokens;
  }

  for (final arg in effectiveArgs) {
    if (arg.isVariable) {
      throw Exception("Variable unknown: ${arg.text}");
    }
  }

  final dartValues = effectiveArgs.map((e) => e.dartValue).toList();

  return Command(
    name,
    dartValues,
    variable: variable,
  );
}

class Command {
  final String name;
  final List<Object?> arguments;
  final String? variable;

  Command(this.name, this.arguments, {this.variable});

  @override
  String toString() {
    return 'Command{name: $name, arguments: $arguments, variable: $variable}';
  }
}