import '../../../../../model/source.dart';

Source get philiascansSource => _philiascansSource;
const _philiascansVersion = "0.0.1";
const _philiascansSourceCodeUrl =
    "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/philiascans/philiascans.dart";
Source _philiascansSource = Source(
  name: "Philia Scans",
  lang: "en",
  baseUrl: "https://philiascans.org",
  iconUrl:
  "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/philiascans/icon.png",
  sourceCodeUrl: _philiascansSourceCodeUrl,
  typeSource: "single",
  itemType: ItemType.manga,
  version: _philiascansVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isManga: true,
  isNsfw: false,
  hasCloudflare: false,
);
