import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/command_runner.dart';
import 'package:electricsql/electricsql.dart';
import 'package:electricsql/migrations_builder.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// {@template sample_command}
///
/// `electricsql_cli generate_migrations`
/// A [Command] to exemplify a sub command
/// {@endtemplate}
class GenerateMigrationsCommand extends Command<int> {
  GenerateMigrationsCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        'service',
        help: '''
Optional argument providing the url to connect to Electric.
If not provided, it uses the url set in the `ELECTRIC_URL`
environment variable. If that variable is not set, it
resorts to the default url which is `http://127.0.0.1:5133''',
        valueHelp: 'url',
      )
      ..addOption(
        'out',
        help: '''
Optional argument to specify where to write the migrations file.
If this argument is not provided they are written to
`lib/generated/electric_migrations.dart`''',
        valueHelp: 'file_path',
      );
  }

  @override
  String get description =>
      'Fetches the migrations from Electric and generates '
      'the migrations file';

  @override
  String get name => 'generate_migrations';

  final Logger _logger;

  static const String defaultMigrationsFileName = 'electric_migrations.dart';

  @override
  Future<int> run() async {
    String service =
        (argResults?['service'] as String?) ?? 'http://127.0.0.1:5133';
    if (service.endsWith('/')) {
      service = service.substring(0, service.length - 1);
    }

    final out = (argResults?['out'] as String?) ??
        'lib/generated/electric_migrations.dart';

    final valid = await _prechecks(service: service, out: out);
    if (!valid) {
      return ExitCode.config.code;
    }

    await _runGenerator(service: service, out: out);

    return ExitCode.success.code;
  }

  Future<bool> _prechecks({
    required String service,
    required String out,
  }) async {
    if (!(await _isDartProject())) {
      _logger.err('ERROR: This command must be run inside a Dart project');
      return false;
    }

    if (!(await _isElectricServiceReachable(service))) {
      _logger.err('ERROR: Could not reach Electric service at $service');
      return false;
    }

    return true;
  }

  Future<bool> _isDartProject() async {
    final pubspecFile = File('pubspec.yaml');
    return pubspecFile.exists();
  }

  Future<bool> _isElectricServiceReachable(String service) async {
    final url = '$service/api';

    try {
      await http.get(Uri.parse(url));
      // If we get here, the service is reachable
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _runGenerator({
    required String service,
    required String out,
  }) async {
    _logger.info('Generating migrations file...');

    final currentDir = Directory.current;

    // Create a unique temporary folder in which to save
    // intermediate files without risking collisions
    final tmpDir = await currentDir.createTemp('.electric_migrations_tmp_');

    try {
      final migrationsPath = path.join(tmpDir.path, 'migrations');
      final migrationsDir = await Directory(migrationsPath).create();

      final migrationEndpoint = '$service/api/migrations?dialect=sqlite';

      // Fetch the migrations from Electric endpoint and write them into tmpDir
      await fetchMigrations(migrationEndpoint, migrationsDir, tmpDir);

      _logger.info('Building migrations...');
      final migrationsFile = resolveMigrationsFile(out);
      await buildMigrations(migrationsDir, migrationsFile);
    } finally {
      // Delete the temporary folder
      await tmpDir.delete(recursive: true);
    }
  }

  /// Fetches the migrations from the provided endpoint,
  /// unzips them and writes them to the `writeTo` location.
  Future<bool> fetchMigrations(
    String endpoint,
    Directory writeTo,
    Directory tmpFolder,
  ) async {
    final zipFile = File(path.join(tmpFolder.path, 'migrations.zip'));

    Future<bool> gotNewMigrationsFun() async {
      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode >= 400) {
        throw Exception(
          'Error while fetching migrations from $endpoint: '
          '${response.statusCode} ${response.reasonPhrase}',
        );
      }

      if (response.statusCode == 204) {
        // No new migrations
        return false;
      } else {
        await zipFile.writeAsBytes(response.bodyBytes);
        return true;
      }
    }

    final gotNewMigrations = await gotNewMigrationsFun();

    // Unzip the migrations
    if (gotNewMigrations) {
      await extractFileToDisk(zipFile.path, writeTo.path);
    }

    return gotNewMigrations;
  }

  Future<void> buildMigrations(
    Directory migrationsFolder,
    File migrationsFile,
  ) async {
    final migrations = await loadMigrations(migrationsFolder);

    final outParent = migrationsFile.parent;
    if (!outParent.existsSync()) {
      await outParent.create(recursive: true);
    }

    final contents = generateMigrationsDartCode(migrations);

    // Update the configuration file
    await migrationsFile.writeAsString(contents);
  }

  File resolveMigrationsFile(String out) {
    final ext = path.extension(out);
    if (ext.isEmpty) {
      return File(
        path.join(Directory.current.path, out, defaultMigrationsFileName),
      );
    } else {
      return File(out);
    }
  }

  Future<List<Migration>> loadMigrations(Directory migrationsFolder) async {
    final migrationDirNames = await getMigrationNames(migrationsFolder);
    final migrationFiles = migrationDirNames.map(
      (dirName) =>
          File(path.join(migrationsFolder.path, dirName, 'metadata.json')),
    );
    final migrationsMetadatas = await Future.wait(
      migrationFiles.map(readMetadataFile),
    );
    return migrationsMetadatas.map(makeMigration).toList();
  }

  /// Reads the specified metadata file.
  /// @param path Path to the metadata file.
  /// @returns A promise that resolves with the metadata.
  Future<MetaData> readMetadataFile(File file) async {
    try {
      final data = await file.readAsString();
      final jsonData = json.decode(data);

      if (jsonData is! Map<String, Object?>) {
        throw Exception(
            'Migration file ${file.path} has wrong format, expected JSON object '
            'but found something else.');
      }

      return parseMetadata(jsonData);
    } catch (e, st) {
      throw Exception(
        'Error while parsing migration file ${file.path}. $e\n$st',
      );
    }
  }

  /// Reads the provided `migrationsFolder` and returns an array
  /// of all the migrations that are present in that folder.
  /// Each of those migrations are in their respective folder.
  /// @param migrationsFolder
  Future<List<String>> getMigrationNames(Directory migrationsFolder) async {
    final dirs = migrationsFolder.listSync().whereType<Directory>();
    // the directory names encode the order of the migrations
    // therefore we sort them by name to get them in chronological order
    final dirNames = dirs.map((dir) => dir.path).toList()..sort();
    return dirNames;
  }
}

const _kTab = '  ';

String generateMigrationsDartCode(List<Migration> migrations) {
  final migrationLines =
      migrations.map((m) => '${generateSingleMigrationDartCode(m, _kTab)},');
  final migrationsStr = migrationLines.join('\n');
  return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars, avoid_escaping_inner_quotes, depend_on_referenced_packages
import 'package:electricsql/electricsql.dart';

final kElectricMigrations = [
$migrationsStr
];
''';
}

String generateSingleMigrationDartCode(
  Migration migration,
  String indent,
) {
  final stmtIndent = '$indent$_kTab$_kTab';
  final statments = migration.statements.map((stmt) {
    final singleLineStmt = stmt
        .replaceAll('\n', r'\n')
        .replaceAll('"', r'\"')
        .replaceAll('\t', r'\t');
    return '$stmtIndent"$singleLineStmt",';
  });
  final statementsString = statments.join('\n');
  return '''
${indent}Migration(
$indent${_kTab}statements: [
$statementsString
$indent$_kTab],
$indent${_kTab}version: "${migration.version}",
$indent)''';
}
