import '../../../../../model/source.dart';

Source get asmodeusscansSource => _asmodeusscansSource;
const _asmodeusscansVersion = "0.0.1";
const _asmodeusscansSourceCodeUrl =
    "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/asmodeusscans/asmodeusscans.dart";
Source _asmodeusscansSource = Source(
  name: "Asmodeus Scans",
  lang: "en",
  baseUrl: "https://asmotoon.com",
  iconUrl:
  "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/asmodeusscans/icon.png",
  sourceCodeUrl: _asmodeusscansSourceCodeUrl,
  typeSource: "single",
  itemType: ItemType.manga,
  version: _asmodeusscansVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isManga: true,
  isNsfw: false,
  hasCloudflare: false,
);
