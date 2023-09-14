import 'dart:async';
import 'dart:io';

import 'package:electricsql/drivers/drift.dart';
import 'package:electricsql/electricsql.dart';
import 'package:satellite_dart_client/client_commands.dart';
import 'package:satellite_dart_client/cli/reader.dart';
import 'package:satellite_dart_client/cli/tokens.dart';
import 'package:satellite_dart_client/util/generic_db.dart';
import 'package:satellite_dart_client/cli/state.dart';

Future<void> start() async {
  final reader = createReader();

  final state = AppState();
  for (final input in reader()) {
    try {
      final command = await parseCommand(input, state);

      if (command == null) {
        break;
      }

      print(command);

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
      } else {
        throw Exception("Unknown command: $name");
      }
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
