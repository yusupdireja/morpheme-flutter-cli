import 'package:morpheme/constants.dart';
import 'package:morpheme/dependency_manager.dart';
import 'package:morpheme/extensions/extensions.dart';
import 'package:morpheme/helper/helper.dart';
import 'package:path_to_regexp/path_to_regexp.dart';

class EndpointCommand extends Command {
  EndpointCommand() {
    argParser.addOptionMorphemeYaml();
    argParser.addFlag(
      'json2dart',
      help: 'Generate from json2dart',
      defaultsTo: false,
    );
  }

  @override
  String get name => 'endpoint';

  @override
  String get description => 'Generate endpoint from json2dart.yaml.';

  @override
  String get category => Constants.generate;

  String projectName = '';

  @override
  void run() async {
    final argMorphemeYaml = argResults.getOptionMorphemeYaml();
    projectName = YamlHelper.loadFileYaml(argMorphemeYaml).projectName;

    final bool json2dart = argResults?['json2dart'] ?? false;

    final pathOutput = join(
      current,
      'core',
      'lib',
      'src',
      'constants',
      'src',
      '${projectName.snakeCase}_endpoints.dart',
    );

    StringBuffer file = StringBuffer();

    final findOld = find(
      '*_endpoints.dart',
      workingDirectory: join(
        current,
        'core',
        'lib',
        'src',
        'constants',
        'src',
      ),
    ).toList();

    for (var item in findOld) {
      delete(item);
    }

    file.write('''abstract class ${projectName.pascalCase}Endpoints {
''');

    final workingDirectory = find(
      '*json2dart.yaml',
      workingDirectory: join(current, 'json2dart'),
    ).toList();

    for (var pathJson2Dart in workingDirectory) {
      if (!exists(pathJson2Dart)) continue;

      final yml = YamlHelper.loadFileYaml(pathJson2Dart);
      Map json2DartMap = Map.from(yml);

      List environmentUrl =
          json2DartMap['json2dart']?['environment_url'] ?? ['BASE_URL'];

      for (var baseUrl in environmentUrl) {
        if (!file
            .toString()
            .contains('_createUri${baseUrl.toString().pascalCase}')) {
          file.writeln(
            '  static Uri _createUri${baseUrl.toString().pascalCase}(String path) => Uri.parse(const String.fromEnvironment(\'$baseUrl\') + path);',
          );
        }
      }
    }

    file.writeln();

    for (var pathJson2Dart in workingDirectory) {
      if (!exists(pathJson2Dart)) continue;

      final yml = YamlHelper.loadFileYaml(pathJson2Dart);
      Map json2DartMap = Map.from(yml);

      json2DartMap.forEach((featureName, featureValue) {
        final lastPathJson2Dart = pathJson2Dart.split(separator).last;

        String appsName = '';
        if (lastPathJson2Dart.contains('_')) {
          appsName = lastPathJson2Dart.split('_').first;
        }
        if (featureValue is Map) {
          featureValue.forEach((pageKey, pageValue) {
            if (pageValue is Map) {
              pageValue.forEach((apiKey, apiValue) {
                final baseUrl = apiValue['base_url'] ?? 'BASE_URL';
                final pathUrl = apiValue['path'];
                if (pathUrl != null) {
                  final parameters = <String>[];
                  parse(pathUrl, parameters: parameters);

                  final isHttp =
                      RegExp(r'^(http|https):\/\/').hasMatch(pathUrl);

                  String data = '';

                  if (parameters.isEmpty) {
                    data =
                        "static Uri ${apiKey.toString().camelCase}${appsName.pascalCase} = ${isHttp ? 'Uri.parse' : '_createUri${baseUrl.toString().pascalCase}'}('$pathUrl');";
                  } else {
                    final parameterString = parameters
                        .map((e) => 'String ${e.camelCase}')
                        .join(',');
                    final replacePath = parameters
                        .map((e) => ".replaceAll(':$e', ${e.camelCase})")
                        .join();

                    data =
                        "static Uri ${apiKey.toString().camelCase}${appsName.pascalCase}($parameterString) => ${isHttp ? 'Uri.parse' : '_createUri${baseUrl.toString().pascalCase}'}('$pathUrl'$replacePath,);";
                  }

                  if (!file.toString().contains(data)) {
                    file.writeln(data);
                  }
                }
              });
            }
          });
        }
      });
    }

    file.write("}");
    pathOutput.write(file.toString());
    StatusHelper.generated(pathOutput);

    if (!json2dart) await ModularHelper.format();

    StatusHelper.success('morpheme endpoint');
  }
}
