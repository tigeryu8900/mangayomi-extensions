import 'dart:convert';

import 'package:flutter_qjs/js_eval_result.dart';
import 'package:http_interceptor/http_interceptor.dart' as http_interceptor;
import 'package:mangayomi/services/http/m_client.dart';

import 'eval/lnreader/service.dart';
import 'eval/model/document.dart';
import 'eval/model/filter.dart' as filter;
import 'eval/model/m_bridge.dart';
import 'eval/model/m_manga.dart';
import 'eval/model/m_pages.dart' as m_pages;
import 'eval/model/m_source.dart';
import 'eval/model/source_preference.dart' as source_preference;
import 'models/manga.dart';
import 'models/video.dart';
import 'modules/browse/extension/providers/extension_preferences_providers.dart';
import 'utils/extensions/string_extensions.dart';

export 'eval/model/document.dart';
export 'eval/model/element.dart';
export 'eval/model/m_bridge.dart';
export 'eval/model/m_chapter.dart';
export 'eval/model/m_manga.dart';
export 'eval/model/m_source.dart';
export 'models/manga.dart';
export 'models/video.dart';
export 'modules/browse/extension/providers/extension_preferences_providers.dart';
export 'services/http/m_client.dart';

// package:http_interceptor/http_interceptor.dart

class Client extends http_interceptor.InterceptedClient {
  factory Client([MSource? source, String? reqcopyWith]) {
    return MClient.init(
          source: source,
          reqcopyWith: reqcopyWith == null
              ? null
              : (jsonDecode(reqcopyWith) as Map).cast<String, dynamic>(),
        )
        as Client;
  }
}

typedef BaseRequest = http_interceptor.BaseRequest;
typedef Response = http_interceptor.Response;

// eval/model/filter.dart

class FilterList extends filter.FilterList {
  FilterList(super.filters);
}

class SelectFilter extends filter.SelectFilter {
  SelectFilter(
    super.type,
    super.name,
    super.state,
    super.values, [
    super.typeName,
  ]);
}

class SelectFilterOption extends filter.SelectFilterOption {
  SelectFilterOption(super.name, super.value, [super.typeName]);
}

class SeparatorFilter extends filter.SeparatorFilter {
  SeparatorFilter([super.type]);
}

class HeaderFilter extends filter.HeaderFilter {
  HeaderFilter(super.name, [super.type]);
}

class TextFilter extends filter.TextFilter {
  TextFilter(String? type, String name, {String state = ""})
    : super(type, name, null, state: state);
}

class SortFilter extends filter.SortFilter {
  SortFilter(
    super.type,
    super.name,
    super.state,
    super.values, [
    super.typeName,
  ]);
}

class SortState extends filter.SortState {
  SortState(super.index, super.ascending, [super.typeName]);
}

class TriStateFilter extends filter.TriStateFilter {
  TriStateFilter(super.name, super.value, [super.type = "", super.state]);
}

class GroupFilter extends filter.GroupFilter {
  GroupFilter(super.type, super.name, super.state, [super.typeName]);
}

class CheckBoxFilter extends filter.CheckBoxFilter {
  CheckBoxFilter(super.name, super.value, [super.type = "", super.state]);
}

// eval/model/m_provider.dart

class MProvider {
  String? get baseUrl => throw UnimplementedError();

  Future<String> cleanHtmlContent(String html) {
    throw UnimplementedError();
  }

  Future<MManga> getDetail(String url) {
    throw UnimplementedError();
  }

  List<dynamic> getFilterList() {
    throw UnimplementedError();
  }

  Future<String> getHtmlContent(String name, String url) {
    throw UnimplementedError();
  }

  Future<MPages> getLatestUpdates(int page) {
    throw UnimplementedError();
  }

  Future<List<dynamic>> getPageList(String url) {
    throw UnimplementedError();
  }

  Future<MPages> getPopular(int page) {
    throw UnimplementedError();
  }

  List<dynamic> getSourcePreferences() {
    throw UnimplementedError();
  }

  Future<List<Video>> getVideoList(String url) {
    throw UnimplementedError();
  }

  Map<String, String> get headers => throw UnimplementedError();

  Future<MPages> search(String query, int page, FilterList filterList) {
    throw UnimplementedError();
  }
}

// eval/model/m_bridge.dart

String getPrefStringValue(int sourceId, String key, String defaultValue) {
  return getSourcePreferenceStringValue(sourceId, key, defaultValue);
}

String cryptoHandler(
  String text,
  String iv,
  String secretKeyString,
  bool encrypt,
) {
  return MBridge.cryptoHandler(text, iv, secretKeyString, encrypt);
}

String encryptAESCryptoJS(String plainText, String passphrase) {
  return MBridge.encryptAESCryptoJS(plainText, passphrase);
}

String decryptAESCryptoJS(String encrypted, String passphrase) {
  return MBridge.decryptAESCryptoJS(encrypted, passphrase);
}

String deobfuscateJsPassword(String inputString) {
  return MBridge.deobfuscateJsPassword(inputString);
}

Future<List<Video>> sibnetExtractor(String url, String prefix) {
  return MBridge.sibnetExtractor(url, prefix);
}

Future<List<Video>> myTvExtractor(String url) {
  return MBridge.myTvExtractor(url);
}

Future<List<Video>> okruExtractor(String url) {
  return MBridge.okruExtractor(url);
}

Future<List<Video>> voeExtractor(String url, String? quality) {
  return MBridge.voeExtractor(url, quality);
}

Future<List<Video>> vidBomExtractor(String url) {
  return MBridge.vidBomExtractor(url);
}

Future<List<Video>> streamlareExtractor(
  String url,
  String prefix,
  String suffix,
) {
  return MBridge.streamlareExtractor(url, prefix, suffix);
}

Future<List<Video>> sendVidExtractor(
  String url,
  String? headers,
  String prefix,
) {
  return MBridge.sendVidExtractor(url, headers, prefix);
}

Future<List<Video>> yourUploadExtractor(
  String url,
  String? headers,
  String? name,
  String prefix,
) {
  return MBridge.yourUploadExtractor(url, headers, name, prefix);
}

Future<List<Video>> quarkVideosExtractor(String url, String cookie) {
  return MBridge.quarkVideosExtractor(url, cookie);
}

Future<List<Video>> ucVideosExtractor(String url, String cookie) {
  return MBridge.ucVideosExtractor(url, cookie);
}

Future<List<Map<String, String>>> quarkFilesExtractor(
  List<String> url,
  String cookie,
) {
  return MBridge.quarkFilesExtractor(url, cookie);
}

Future<List<Map<String, String>>> ucFilesExtractor(
  List<String> url,
  String cookie,
) {
  return MBridge.ucFilesExtractor(url, cookie);
}

String substringAfter(String text, String pattern) {
  return MBridge.substringAfter(text, pattern);
}

String substringBefore(String text, String pattern) {
  return MBridge.substringBefore(text, pattern);
}

String substringBeforeLast(String text, String pattern) {
  return MBridge.substringBeforeLast(text, pattern);
}

String substringAfterLast(String text, String pattern) {
  return MBridge.substringAfterLast(text, pattern);
}

String getMapValue(String source, String attr, {bool encode = false}) {
  return MBridge.getMapValue(source, attr, encode);
}

MStatus parseStatus(String status, List<dynamic> statusList) {
  return MBridge.parseStatus(status, statusList);
}

List<dynamic> parseDates(
  List<dynamic> value,
  String dateFormat,
  String dateFormatLocale,
) {
  return MBridge.parseDates(value, dateFormat, dateFormatLocale);
}

List<String>? xpath(String html, String xpath) {
  return MBridge.xpath(html, xpath);
}

Future<List<Video>> gogoCdnExtractor(String url) {
  return MBridge.gogoCdnExtractor(url);
}

Future<List<Video>> doodExtractor(String url, String? quality) {
  return MBridge.doodExtractor(url, quality);
}

Future<List<Video>> streamTapeExtractor(String url, String? quality) {
  return MBridge.streamTapeExtractor(url, quality);
}

Future<List<Video>> mp4UploadExtractor(
  String url,
  String? headers,
  String prefix,
  String suffix,
) {
  return MBridge.mp4UploadExtractor(url, headers, prefix, suffix);
}

Future<List<Video>> streamWishExtractor(String url, String prefix) {
  return MBridge.streamWishExtractor(url, prefix);
}

Future<List<Video>> filemoonExtractor(
  String url,
  String prefix,
  String suffix,
) {
  return MBridge.filemoonExtractor(url, prefix, suffix);
}

String? unpackJs(String code) {
  return MBridge.unpackJs(code);
}

String? unpackJsAndCombine(String code) {
  return MBridge.unpackJsAndCombine(code);
}

Future<JsEvalResult> evalJs(String code) {
  return getJavascriptRuntime().evaluateAsync(code);
}

JsEvalResult evalJsSync(String code) {
  return getJavascriptRuntime().evaluate(code);
}

String regExp(
  String expression,
  String source,
  String replace,
  int type,
  int group,
) {
  return MBridge.regExp(expression, source, replace, type, group);
}

List<dynamic> sortMapList(List<dynamic> list, String value, int type) {
  return MBridge.sortMapList(list, value, type);
}

MDocument parseHtml(String html) {
  return MBridge.parsHtml(html);
}

String getUrlWithoutDomain(String url) {
  return url.getUrlWithoutDomain;
}

Future<String> evaluateJavascriptViaWebview(
  String url,
  Map<String, String> headers,
  List<String> scripts, {
  int time = 30,
}) {
  return MBridge.evaluateJavascriptViaWebview(
    url,
    headers,
    scripts,
    time: time,
  );
}

// eval/model/m_pages.dart

class MPages extends m_pages.MPages {
  MPages(List<MManga> list, [bool hasNextPage = false])
    : super(list: list, hasNextPage: hasNextPage);
}

// models/manga.dart

typedef MStatus = Status;

// eval/model/source_preference.dart

class CheckBoxPreference extends source_preference.CheckBoxPreference {
  factory CheckBoxPreference({
    String? key,
    String? title,
    String? summary,
    bool? value,
  }) {
    return source_preference.SourcePreference(
          key: key,
          checkBoxPreference: CheckBoxPreference(
            title: title,
            summary: summary,
            value: value,
          ),
        )
        as CheckBoxPreference;
  }
}

class SwitchPreferenceCompat extends source_preference.SwitchPreferenceCompat {
  factory SwitchPreferenceCompat({
    String? key,
    String? title,
    String? summary,
    bool? value,
  }) {
    return source_preference.SourcePreference(
          key: key,
          switchPreferenceCompat: SwitchPreferenceCompat(
            title: title,
            summary: summary,
            value: value,
          ),
        )
        as SwitchPreferenceCompat;
  }
}

class ListPreference extends source_preference.ListPreference {
  factory ListPreference({
    String? key,
    String? title,
    String? summary,
    int? valueIndex,
    List<String>? entries,
    List<String>? entryValues,
  }) {
    return source_preference.SourcePreference(
          key: key,
          listPreference: ListPreference(
            title: title,
            summary: summary,
            valueIndex: valueIndex,
            entries: entries,
            entryValues: entryValues,
          ),
        )
        as ListPreference;
  }
}

class MultiSelectListPreference
    extends source_preference.MultiSelectListPreference {
  factory MultiSelectListPreference({
    String? key,
    String? title,
    String? summary,
    int? valueIndex,
    List<String>? entries,
    List<String>? entryValues,
    List<String>? values,
  }) {
    return source_preference.SourcePreference(
          key: key,
          multiSelectListPreference: MultiSelectListPreference(
            title: title,
            summary: summary,
            valueIndex: valueIndex,
            entries: entries,
            entryValues: entryValues,
            values: values,
          ),
        )
        as MultiSelectListPreference;
  }
}

class EditTextPreference extends source_preference.EditTextPreference {
  factory EditTextPreference({
    String? key,
    String? title,
    String? summary,
    String? value,
    String? dialogTitle,
    String? dialogMessage,
    String? text,
  }) {
    return source_preference.SourcePreference(
          key: key,
          editTextPreference: EditTextPreference(
            title: title,
            summary: summary,
            value: value,
            dialogTitle: dialogTitle,
            dialogMessage: dialogMessage,
            text: text,
          ),
        )
        as EditTextPreference;
  }
}
