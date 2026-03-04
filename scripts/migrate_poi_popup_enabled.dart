import 'dart:io';

Future<int> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Migration POIs: metadata.popupEnabled');
    stdout.writeln('');
    stdout.writeln('Usage (depuis le dossier app/):');
    stdout.writeln('  dart run ../scripts/migrate_poi_popup_enabled.dart --dry-run');
    stdout.writeln('  dart run ../scripts/migrate_poi_popup_enabled.dart --country=GP --event=... --circuit=...');
    stdout.writeln('');
    stdout.writeln('Options:');
    stdout.writeln('  --dry-run         Ne modifie rien, affiche le volume.');
    stdout.writeln('  --country=ID      Filtre pays (marketMap/{countryId}).');
    stdout.writeln('  --event=ID        Filtre event (events/{eventId}).');
    stdout.writeln('  --circuit=ID      Filtre circuit (circuits/{circuitId}).');
    stdout.writeln('  --limit=N         Stoppe après N updates (utile pour tests).');
    return 0;
  }

  // On appelle le script Node (firebase-admin) déjà utilisé dans ce repo.
  final node = Platform.isWindows ? 'node.exe' : 'node';
  final result = await Process.start(
    node,
    ['../scripts/migrate_poi_popup_enabled.js', ...args],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  return await result.exitCode;
}
