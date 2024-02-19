import 'dart:convert';

import 'package:morpheme/constants.dart';
import 'package:morpheme/dependency_manager.dart';
import 'package:morpheme/extensions/extensions.dart';
import 'package:morpheme/helper/helper.dart';

class PreBuildIosCommand extends Command {
  PreBuildIosCommand() {
    argParser.addOptionFlavor(defaultsTo: Constants.dev);
    argParser.addOptionMorphemeYaml();
  }

  @override
  String get name => 'ios';

  @override
  String get description => 'Prepare setup ios before build';

  @override
  void run() async {
    final argFlavor = argResults.getOptionFlavor(defaultTo: Constants.dev);
    final argMorphemeYaml = argResults.getOptionMorphemeYaml();

    YamlHelper.validateMorphemeYaml(argMorphemeYaml);

    final pathAppstoreDeployment =
        join(current, 'ios', 'deployment', 'appstore_deployment.json');
    if (!exists(pathAppstoreDeployment)) {
      StatusHelper.failed('$pathAppstoreDeployment is not found!');
    }

    final morphemeYaml = YamlHelper.loadFileYaml(argMorphemeYaml);
    final Map appstoreDeployment =
        jsonDecode(readFile(pathAppstoreDeployment))[argFlavor];

    final bundleId = morphemeYaml['flavor'][argFlavor]['IOS_APPLICATION_ID'];

    setupFastlane(bundleId, appstoreDeployment);
    setupProjectIos(bundleId, appstoreDeployment);
    setupExportOptions(bundleId, appstoreDeployment);

    StatusHelper.success('prebuild ios');
  }

  void setupFastlane(String bundleId, Map appstoreDeployment) {
    final path = join(current, 'ios', 'fastlane', 'Appfile');
    path.write(
        '''app_identifier("$bundleId") # The bundle identifier of your app
apple_id("${appstoreDeployment['email_identity']}") # Your Apple email address

itc_team_id("${appstoreDeployment['itc_team_id']}") # App Store Connect Team ID
team_id("${appstoreDeployment['team_id']}") # Developer Portal Team ID

# For more information about the Appfile, see:
#     https://docs.fastlane.tools/advanced/#appfile''');

    StatusHelper.generated(path);
  }

  void setupProjectIos(String bundleId, Map appstoreDeployment) {
    final path = join(current, 'ios', 'Runner.xcodeproj', 'project.pbxproj');

    String file = readFile(path);
    file = file.replaceAll(
        RegExp(r'"?CODE_SIGN_IDENTITY"?(\s+)?=(\s+)?"?.+"?;'),
        'CODE_SIGN_IDENTITY = "iPhone Distribution";');
    file = file.replaceAll(
        RegExp(r'"?CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]"?(\s+)?=(\s+)?"?.+"?;'),
        '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Distribution";');
    file = file.replaceAll(RegExp(r'"?DEVELOPMENT_TEAM"?(\s+)?=(\s+)?"?.+"?;'),
        'DEVELOPMENT_TEAM = ${appstoreDeployment['team_id']};');
    file = file.replaceAll(
        RegExp(r'"?DEVELOPMENT_TEAM\[sdk=iphoneos\*\]"?(\s+)?=(\s+)?"?.+"?;'),
        '"DEVELOPMENT_TEAM[sdk=iphoneos*]" = ${appstoreDeployment['team_id']};');
    file = file.replaceAll(
        RegExp(r'"?PRODUCT_BUNDLE_IDENTIFIER"?(\s+)?=(\s+)?"?.+"?;'),
        'PRODUCT_BUNDLE_IDENTIFIER = "\${IOS_APPLICATION_ID}";');
    file = file.replaceAll(
        RegExp(
            r'"?PRODUCT_BUNDLE_IDENTIFIER\[sdk=iphoneos\*\]"?(\s+)?=(\s+)?"?.+"?;'),
        '"PRODUCT_BUNDLE_IDENTIFIER[sdk=iphoneos*]" = "\${IOS_APPLICATION_ID}";');
    file = file.replaceAll(
        RegExp(r'"?PROVISIONING_PROFILE_SPECIFIER"?(\s+)?=(\s+)?"?.+"?;'),
        'PROVISIONING_PROFILE_SPECIFIER = "${appstoreDeployment['provisioning_profiles']}";');
    file = file.replaceAll(
        RegExp(
            r'"?PROVISIONING_PROFILE_SPECIFIER\[sdk=iphoneos\*\]"?(\s+)?=(\s+)?"?.+"?;'),
        '"PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]" = "${appstoreDeployment['provisioning_profiles']}";');

    path.write(file);
    StatusHelper.generated(path);
  }

  void setupExportOptions(String bundleId, Map appstoreDeployment) {
    final path = join(current, 'ios', 'ExportOptions.plist');

    path.write('''<?xml version=”1.0" encoding=”UTF-8"?>
<!DOCTYPE plist PUBLIC “-//Apple//DTD PLIST 1.0//EN” “http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version=”1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${appstoreDeployment['team_id']}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$bundleId</key>
        <string>${appstoreDeployment['provisioning_profiles']}</string>
    </dict>
 </dict>
 </plist>''');

    StatusHelper.generated(path);
  }
}
