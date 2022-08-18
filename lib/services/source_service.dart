// Exposes functions related to interacting with App sources and retrieving App info
// Stateless - not a provider

import 'dart:convert';
import 'package:http/http.dart';

// Sub-classes used in App Source

class AppNames {
  late String author;
  late String name;

  AppNames(this.author, this.name);
}

class APKDetails {
  late String version;
  late String downloadUrl;

  APKDetails(this.version, this.downloadUrl);
}

// App Source abstract class (diff. implementations for GitHub, GitLab, etc.)

abstract class AppSource {
  String standardizeURL(String url);
  Future<APKDetails> getLatestAPKUrl(String standardUrl);
  AppNames getAppNames(String standardUrl);
}

// App class

class App {
  late String id;
  late String url;
  late String author;
  late String name;
  String? installedVersion;
  late String latestVersion;
  late String apkUrl;
  String? currentDownloadId;
  App(this.id, this.url, this.author, this.name, this.installedVersion,
      this.latestVersion, this.apkUrl, this.currentDownloadId);

  @override
  String toString() {
    return 'ID: $id URL: $url INSTALLED: $installedVersion LATEST: $latestVersion APK: $apkUrl';
  }

  factory App.fromJson(Map<String, dynamic> json) => App(
      json['id'] as String,
      json['url'] as String,
      json['author'] as String,
      json['name'] as String,
      json['installedVersion'] == null
          ? null
          : json['installedVersion'] as String,
      json['latestVersion'] as String,
      json['apkUrl'] as String,
      json['currentDownloadId'] == null
          ? null
          : json['currentDownloadId'] as String);

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'author': author,
        'name': name,
        'installedVersion': installedVersion,
        'latestVersion': latestVersion,
        'apkUrl': apkUrl,
        'currentDownloadId': currentDownloadId
      };
}

// Specific App Source classes

class GitHub implements AppSource {
  @override
  String standardizeURL(String url) {
    RegExp standardUrlRegEx = RegExp(r'^https?://github.com/[^/]*/[^/]*');
    RegExpMatch? match = standardUrlRegEx.firstMatch(url.toLowerCase());
    if (match == null) {
      throw 'Not a valid URL';
    }
    return url.substring(0, match.end);
  }

  String convertURL(String url, String replaceText) {
    int tempInd1 = url.indexOf('://') + 3;
    int tempInd2 = url.substring(tempInd1).indexOf('/') + tempInd1;
    return '${url.substring(0, tempInd1)}$replaceText${url.substring(tempInd2)}';
  }

  @override
  Future<APKDetails> getLatestAPKUrl(String standardUrl) async {
    Response res = await get(Uri.parse(
        '${convertURL(standardUrl, 'api.github.com/repos')}/releases/latest'));
    if (res.statusCode == 200) {
      dynamic release = jsonDecode(res.body);
      for (int i = 0; i < release['assets'].length; i++) {
        if (release['assets'][i]['name']
            .toString()
            .toLowerCase()
            .endsWith('.apk')) {
          return APKDetails(release['tag_name'],
              release['assets'][i]['browser_download_url']);
        }
      }
      throw 'No APK found';
    } else {
      throw 'Unable to fetch release info';
    }
  }

  @override
  AppNames getAppNames(String standardUrl) {
    String temp = standardUrl.substring(standardUrl.indexOf('://') + 3);
    List<String> names = temp.substring(temp.indexOf('/') + 1).split('/');
    return AppNames(names[0], names[1]);
  }
}

class SourceService {
  // Add more source classes here so they are available via the service
  AppSource github = GitHub();
  AppSource getSource(String url) {
    if (url.toLowerCase().contains('://github.com')) {
      return github;
    }
    throw 'URL does not match a known source';
  }

  Future<App> getApp(String url) async {
    if (url.toLowerCase().indexOf('http://') != 0 &&
        url.toLowerCase().indexOf('https://') != 0) {
      url = 'https://$url';
    }
    AppSource source = getSource(url);
    String standardUrl = source.standardizeURL(url);
    AppNames names = source.getAppNames(standardUrl);
    APKDetails apk = await source.getLatestAPKUrl(standardUrl);
    return App(
        '${names.author}_${names.name}',
        standardUrl,
        names.author[0].toUpperCase() + names.author.substring(1),
        names.name[0].toUpperCase() + names.name.substring(1),
        null,
        apk.version,
        apk.downloadUrl,
        null);
  }
}
