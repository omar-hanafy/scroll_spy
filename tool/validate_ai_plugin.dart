// Validates the repository's AI coding-assistant plugin distribution
// (Claude Code + OpenAI Codex) without requiring either CLI or any network
// access. Run from the repository root:
//
//   dart run tool/validate_ai_plugin.dart
//
// Exits 0 when everything is consistent, 1 with a list of errors otherwise.
// CI runs this on every PR; keep it dependency-free (dart:core only).
import 'dart:convert';
import 'dart:io';

const pluginDir = 'plugins/scroll-spy';
const claudeManifestPath = '$pluginDir/.claude-plugin/plugin.json';
const codexManifestPath = '$pluginDir/.codex-plugin/plugin.json';
const claudeMarketplacePath = '.claude-plugin/marketplace.json';
const codexMarketplacePath = '.agents/plugins/marketplace.json';
const skillsDir = '$pluginDir/skills';

final errors = <String>[];
final warnings = <String>[];

void fail(String message) => errors.add(message);
void warn(String message) => warnings.add(message);

final kebabCase = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final absolutePathPattern = RegExp(r'(/Users/|/home/|[A-Z]:\\)');
final secretPattern = RegExp(
  r'(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
  r'|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,})',
);

Map<String, Object?>? readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path is missing.');
    return null;
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      fail('$path must contain a JSON object.');
      return null;
    }
    return decoded;
  } on FormatException catch (e) {
    fail('$path is not valid JSON: ${e.message}');
    return null;
  }
}

String? pubspecVersion() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    fail('pubspec.yaml is missing (run from the repository root).');
    return null;
  }
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^version:\s*(\S+)\s*$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  fail('pubspec.yaml has no version field.');
  return null;
}

/// Parses the simple `key: value` YAML frontmatter block used by SKILL.md.
Map<String, String>? readFrontmatter(String path) {
  final lines = File(path).readAsLinesSync();
  if (lines.isEmpty || lines.first.trim() != '---') {
    fail('$path must start with a `---` frontmatter block.');
    return null;
  }
  final result = <String, String>{};
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim() == '---') return result;
    if (line.trim().isEmpty) continue;
    final separator = line.indexOf(':');
    if (separator <= 0 || line.startsWith(' ')) {
      // Nested/multi-line YAML is deliberately unsupported here; skill
      // frontmatter in this repository must stay flat and single-line.
      fail('$path frontmatter line ${i + 1} is not a flat `key: value` pair.');
      return null;
    }
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    } else if (value.contains(': ')) {
      // Unquoted scalars containing ": " are invalid YAML; real parsers
      // (Claude Code, Codex) drop the whole frontmatter block on this.
      fail(
        '$path frontmatter "$key" contains an unquoted ": "; wrap the value '
        'in double quotes.',
      );
    }
    result[key] = value;
  }
  fail('$path frontmatter block is never closed with `---`.');
  return null;
}

void checkManifests(String? packageVersion) {
  final claude = readJson(claudeManifestPath);
  final codex = readJson(codexManifestPath);
  final claudeMarket = readJson(claudeMarketplacePath);
  final codexMarket = readJson(codexMarketplacePath);

  for (final (path, manifest) in [
    (claudeManifestPath, claude),
    (codexManifestPath, codex),
  ]) {
    if (manifest == null) continue;
    final name = manifest['name'];
    if (name != 'scroll-spy') {
      fail('$path name must be "scroll-spy", found: $name');
    }
    final version = manifest['version'];
    if (packageVersion != null && version != packageVersion) {
      fail('$path version ($version) != pubspec version ($packageVersion).');
    }
    final skills = manifest['skills'];
    if (skills != './skills/') {
      fail('$path skills must be "./skills/", found: $skills');
    }
  }

  if (claudeMarket != null) {
    final name = claudeMarket['name'];
    if (name is! String || !kebabCase.hasMatch(name)) {
      fail('$claudeMarketplacePath name must be kebab-case, found: $name');
    }
    final owner = claudeMarket['owner'];
    if (owner is! Map || owner['name'] is! String) {
      fail('$claudeMarketplacePath owner.name is required.');
    }
    final plugins = claudeMarket['plugins'];
    if (plugins is! List || plugins.isEmpty) {
      fail('$claudeMarketplacePath plugins must be a non-empty array.');
    } else {
      final entry = plugins.whereType<Map<String, Object?>>().firstWhere(
            (p) => p['name'] == 'scroll-spy',
            orElse: () => <String, Object?>{},
          );
      if (entry.isEmpty) {
        fail('$claudeMarketplacePath has no "scroll-spy" plugin entry.');
      } else {
        final source = entry['source'];
        if (source != './$pluginDir') {
          fail(
            '$claudeMarketplacePath scroll-spy source must be "./$pluginDir", '
            'found: $source',
          );
        }
        final version = entry['version'];
        if (packageVersion != null && version != packageVersion) {
          fail(
            '$claudeMarketplacePath scroll-spy version ($version) != '
            'pubspec version ($packageVersion).',
          );
        }
      }
    }
  }

  if (codexMarket != null) {
    final plugins = codexMarket['plugins'];
    if (plugins is! List || plugins.isEmpty) {
      fail('$codexMarketplacePath plugins must be a non-empty array.');
    } else {
      final entry = plugins.whereType<Map<String, Object?>>().firstWhere(
            (p) => p['name'] == 'scroll-spy',
            orElse: () => <String, Object?>{},
          );
      if (entry.isEmpty) {
        fail('$codexMarketplacePath has no "scroll-spy" plugin entry.');
      } else {
        final source = entry['source'];
        final path = source is Map ? source['path'] : source;
        if (path != './$pluginDir') {
          fail(
            '$codexMarketplacePath scroll-spy source path must be '
            '"./$pluginDir", found: $path',
          );
        }
      }
    }
  }
}

void checkSkills() {
  final dir = Directory(skillsDir);
  if (!dir.existsSync()) {
    fail('$skillsDir is missing.');
    return;
  }
  final seenNames = <String>{};
  final skillDirs = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (skillDirs.isEmpty) {
    fail('$skillsDir contains no skill directories.');
  }
  for (final skillDir in skillDirs) {
    final dirName = skillDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!kebabCase.hasMatch(dirName)) {
      fail('Skill directory "$dirName" must be kebab-case.');
    }
    final skillFile = File('${skillDir.path}/SKILL.md');
    if (!skillFile.existsSync()) {
      fail('${skillDir.path} has no SKILL.md.');
      continue;
    }
    final frontmatter = readFrontmatter(skillFile.path);
    if (frontmatter == null) continue;

    final name = frontmatter['name'];
    if (name == null || name.isEmpty) {
      fail('${skillFile.path} frontmatter must set name.');
    } else {
      if (name != dirName) {
        fail(
          '${skillFile.path} name ("$name") must match its directory '
          '("$dirName").',
        );
      }
      if (name.length > 64) {
        fail('${skillFile.path} name exceeds 64 characters.');
      }
      if (!seenNames.add(name)) {
        fail('Duplicate skill name: $name');
      }
    }

    final description = frontmatter['description'];
    if (description == null || description.isEmpty) {
      fail('${skillFile.path} frontmatter must set description.');
    } else if (description.length > 1024) {
      fail('${skillFile.path} description exceeds 1024 characters.');
    }

    for (final file in skillDir.listSync(recursive: true).whereType<File>()) {
      checkContentFile(file, skillDir.path);
    }
  }
}

void checkContentFile(File file, String skillRoot) {
  final path = file.path;
  if (!path.endsWith('.md') && !path.endsWith('.dart')) return;
  final content = file.readAsStringSync();

  if (absolutePathPattern.hasMatch(content)) {
    fail('$path contains an absolute local path.');
  }
  if (content.contains('../')) {
    fail(
      '$path references a parent directory (`../`); skills must be '
      'self-contained so single-skill installs keep working.',
    );
  }
  if (secretPattern.hasMatch(content)) {
    fail('$path contains a secret-like token.');
  }

  // Every relative markdown link must resolve inside the skill directory.
  for (final match in RegExp(r'\]\((?!https?://|#|mailto:)([^)\s]+)\)')
      .allMatches(content)) {
    final target = match.group(1)!;
    final resolved = File(
      '${File(path).parent.path}/$target',
    );
    if (!resolved.existsSync()) {
      fail('$path links to missing file: $target');
    }
  }
}

/// Files that exist in more than one skill (self-containment requires copies)
/// must stay byte-identical; edit one, re-copy to the others.
const duplicatedReferences = [
  [
    '$skillsDir/migrate-scroll-spy-v0-to-v1/references/test-harness.md',
    '$skillsDir/integrate-scroll-spy/references/test-harness.md',
  ],
];

void checkDuplicatedReferencesInSync() {
  for (final group in duplicatedReferences) {
    final canonical = File(group.first);
    if (!canonical.existsSync()) {
      fail('${group.first} is missing.');
      continue;
    }
    final canonicalContent = canonical.readAsStringSync();
    for (final other in group.skip(1)) {
      final file = File(other);
      if (!file.existsSync()) {
        fail('$other is missing.');
        continue;
      }
      if (file.readAsStringSync() != canonicalContent) {
        fail(
          '$other has drifted from ${group.first}; skills are self-contained '
          'so shared references are duplicated and must stay identical.',
        );
      }
    }
  }
}

void checkPubignore() {
  final file = File('.pubignore');
  if (!file.existsSync()) {
    fail('.pubignore is missing.');
    return;
  }
  final content = file.readAsStringSync();
  for (final required in ['plugins/', 'AGENTS.md', 'CLAUDE.md', 'tool/']) {
    if (!content.contains(required)) {
      fail(
        '.pubignore must exclude "$required" so the pub.dev archive never '
        'ships a partial AI plugin tree.',
      );
    }
  }
}

void checkReadme() {
  final file = File('README.md');
  if (!file.existsSync()) {
    fail('README.md is missing.');
    return;
  }
  final content = file.readAsStringSync();
  for (final command in [
    '/plugin marketplace add omar-hanafy/scroll_spy',
    'codex plugin marketplace add omar-hanafy/scroll_spy',
  ]) {
    if (!content.contains(command)) {
      warn('README.md does not document `$command`.');
    }
  }
}

void main() {
  final packageVersion = pubspecVersion();
  checkManifests(packageVersion);
  checkSkills();
  checkDuplicatedReferencesInSync();
  checkPubignore();
  checkReadme();

  for (final warning in warnings) {
    stdout.writeln('WARN: $warning');
  }
  if (errors.isEmpty) {
    stdout.writeln('AI plugin validation passed.');
    return;
  }
  stderr.writeln('AI plugin validation failed:');
  for (final error in errors) {
    stderr.writeln('  ERROR: $error');
  }
  exitCode = 1;
}
