import '../../../../../model/source.dart';

Source get armageddonSource => _armageddonSource;
const _armageddonVersion = "0.0.1";
const _armageddonSourceCodeUrl =
    "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/armageddon/armageddon.dart";
Source _armageddonSource = Source(
  name: "Armageddon",
  lang: "en",
  baseUrl: "https://www.silentquill.net",
  iconUrl:
  "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/manga/src/en/armageddon/icon.webp",
  sourceCodeUrl: _armageddonSourceCodeUrl,
  typeSource: "single",
  itemType: ItemType.manga,
  version: _armageddonVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isManga: true,
  isNsfw: true,
  hasCloudflare: false,
);
