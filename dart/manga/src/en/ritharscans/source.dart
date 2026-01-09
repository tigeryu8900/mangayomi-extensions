import '../../../../../model/source.dart';

Source get ritharscansSource => _ritharscansSource;
const _ritharscansVersion = "0.0.1";
const _ritharscansSourceCodeUrl =
    "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/ritharscans/ritharscans.dart";
Source _ritharscansSource = Source(
  name: "Rithar Scans",
  lang: "en",
  baseUrl: "https://ritharscans.com",
  iconUrl:
  "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/ritharscans/icon.png",
  sourceCodeUrl: _ritharscansSourceCodeUrl,
  typeSource: "single",
  itemType: ItemType.manga,
  version: _ritharscansVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isManga: true,
  isNsfw: false,
  hasCloudflare: false,
);
