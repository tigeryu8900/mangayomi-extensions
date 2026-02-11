import '../../../../../model/source.dart';

Source get novelupdatesSource => _novelupdatesSource;
const _novelupdatesVersion = "0.0.2";
const _novelupdatesSourceCodeUrl =
    "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/novel/src/en/novelupdates/novelupdates.dart";
Source _novelupdatesSource = Source(
  name: "Novel Updates",
  lang: "en",
  baseUrl: "https://www.novelupdates.com",
  iconUrl:
      "https://raw.githubusercontent.com/tigeryu8900/mangayomi-extensions/$branchName/dart/novel/src/en/novelupdates/icon.png",
  sourceCodeUrl: _novelupdatesSourceCodeUrl,
  typeSource: "single",
  itemType: ItemType.novel,
  version: _novelupdatesVersion,
  dateFormat: "",
  dateFormatLocale: "",
  isManga: false,
  isNsfw: false,
  hasCloudflare: true,
  notes: "This extension requires you to login to view the chapters!",
);
