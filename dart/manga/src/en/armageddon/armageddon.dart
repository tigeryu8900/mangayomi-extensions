// {

import 'package:mangayomi/bridge_lib.dart';

MStatus _toStatus(String? status) {
  return switch (status?.toLowerCase()) {
    "ongoing" => MStatus.ongoing,
    "completed" => MStatus.completed,
    "hiatus" => MStatus.onHiatus,
    "dropped" => MStatus.canceled,
    _ => MStatus.unknown,
  };
}

MPages _mangaListFromPage(Response res) {
  MDocument doc = parseHtml(res.body);
  List<MElement>? entries = doc.select(".listupd a[title]");
  if (entries == null) {
    return MPages([], false);
  }
  List<MManga> list = [];
  for (var entry in entries) {
    list.add(
      MManga(
        imageUrl: entry.selectFirst("img")?.getSrc,
        link: entry.getHref,
        name: entry.attr("title"),
        status: _toStatus(entry.selectFirst(".status")?.text),
      ),
    );
  }
  return MPages(list, doc.selectFirst(".pagination .next") != null);
}

const _imageHeaders = {
  "Content-Type": "image/webp",
  "Referer": "https://www.silentquill.net/",
};

class Armageddon extends MProvider {
  Armageddon({required this.source});

  MSource source;

  late final Client client = Client(source);

  @override
  String? get baseUrl => source.baseUrl;

  @override
  Future<MPages> getPopular(int page) async {
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/manga/", {
        "order": "popular",
        "page": "$page",
      }),
    );
    return _mangaListFromPage(res);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/manga/", {
        "order": "latest",
        "page": "$page",
      }),
    );
    return _mangaListFromPage(res);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    if (query.isNotEmpty) {
      Response res = await client.get(
        Uri.https(baseUrl!.replaceFirst("https://", ""), "/page/$page/", {
          "s": query,
        }),
      );
      return _mangaListFromPage(res);
    }

    Map<String, dynamic> params = {"page": "$page"};

    final filters = filterList.filters;

    for (var f in filters) {
      switch (f.type) {
        case "genre[]":
          {
            GroupFilter filter = f;
            List<TriStateFilter> triStateFilters = filter.state
                .cast<TriStateFilter>();
            List<String> genres = [];
            for (var triStateFilter in triStateFilters) {
              switch (triStateFilter.state) {
                case 1:
                  genres.add(triStateFilter.value);
                  break;
                case 2:
                  genres.add("-${triStateFilter.value}");
                  break;
              }
            }
            if (genres.isNotEmpty) {
              params[filter.type as String] = genres;
            }
            break;
          }
        case "status":
        case "type":
        case "order":
          {
            SelectFilter filter = f;
            SelectFilterOption option = filter.values[filter.state];
            if (option.value.isNotEmpty) {
              params[filter.type as String] = option.value;
            }
            break;
          }
      }
    }

    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/manga/", params),
    );

    return _mangaListFromPage(res);
  }

  @override
  Future<MManga> getDetail(String url) async {
    Uri uri = Uri.parse(url);
    Response res = await client.get(uri);
    MDocument doc = parseHtml(res.body);

    List<MElement> chapterElements = doc.select("#chapterlist li")!;
    List<MChapter> chapters = [];

    for (var entry in chapterElements) {
      MElement a = entry.selectFirst("a")!;
      chapters.add(
        MChapter(
          name: a.selectFirst(".chapternum")?.text,
          url: a.getHref,
          dateUpload: parseDates(
            [a.selectFirst(".chapterdate")!.text],
            "MMMM d, y",
            "en_US",
          )[0],
        ),
      );
    }

    Map<String, String?> properties = doc.select(".infotable tbody tr")!.fold(
      <String, String?>{},
      (acc, e) {
        List<MElement> tds = e.select("td")!;
        acc[tds[0].text!.trim().toLowerCase()] = tds[1].text!.trim();
        return acc;
      },
    );

    return MManga(
      author: properties["author"],
      artist: properties["artist"],
      genre: doc
          .select(".seriestugenre a")!
          .map((e) => e.text!.trim())
          .toList(),
      imageUrl: doc.selectFirst("meta[property=\"og:image\"]")?.attr("content"),
      link: url,
      name: doc.selectFirst("meta[property=\"og:image:alt\"]")?.attr("content"),
      status: _toStatus(properties["status"]),
      description: doc.selectFirst("[itemprop=\"description\"]")?.text?.trim(),
      chapters: chapters,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPageList(String url) async {
    Uri uri = Uri.parse(url);
    Response res = await client.get(uri);
    MDocument doc = parseHtml(res.body);
    String html = doc.selectFirst("#readerarea noscript")!.innerHtml!;
    List<MElement> images = parseHtml(html).select("img")!;
    return images
        .map((e) => {"url": e.getSrc!, "headers": _imageHeaders})
        .toList();
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter("genre[]", "Genre", [
        TriStateFilter("Action", "8"),
        TriStateFilter("Adaptation", "144"),
        TriStateFilter("Adult", "31"),
        TriStateFilter("Adventure", "9"),
        TriStateFilter("Comedy", "3"),
        TriStateFilter("Completed", "117"),
        TriStateFilter("Delinquents", "132"),
        TriStateFilter("Demons", "65"),
        TriStateFilter("Drama", "21"),
        TriStateFilter("Ecchi", "12"),
        TriStateFilter("Echi", "66"),
        TriStateFilter("Erotica", "102"),
        TriStateFilter("Fantasy", "10"),
        TriStateFilter("Gender Bender", "27"),
        TriStateFilter("Ghosts", "68"),
        TriStateFilter("Gyaru", "118"),
        TriStateFilter("Harem", "13"),
        TriStateFilter("Hentai", "54"),
        TriStateFilter("Horror", "86"),
        TriStateFilter("isekai", "122"),
        TriStateFilter("Josei", "72"),
        TriStateFilter("Magic", "67"),
        TriStateFilter("Martial Arts", "108"),
        TriStateFilter("Mature", "14"),
        TriStateFilter("Mecha", "147"),
        TriStateFilter("Monster Girls", "143"),
        TriStateFilter("Monsters", "141"),
        TriStateFilter("Mystery", "97"),
        TriStateFilter("Psychological", "29"),
        TriStateFilter("Reincarnation", "140"),
        TriStateFilter("Romance", "4"),
        TriStateFilter("School Lif", "105"),
        TriStateFilter("School Life", "17"),
        TriStateFilter("Sci-fi", "79"),
        TriStateFilter("Seinen", "25"),
        TriStateFilter("Sexual Violence", "103"),
        TriStateFilter("Shotacon", "93"),
        TriStateFilter("Shoujo", "5"),
        TriStateFilter("Shounen", "15"),
        TriStateFilter("Slice of Life", "34"),
        TriStateFilter("Smut", "55"),
        TriStateFilter("Sports", "109"),
        TriStateFilter(
          "Suggestive. Comedy. Harem. Web Comic. Slice of Life",
          "119",
        ),
        TriStateFilter("Supernatural", "43"),
        TriStateFilter("Survival", "142"),
        TriStateFilter("Thriller", "104"),
        TriStateFilter("Tragedy", "90"),
        TriStateFilter("Web Comic", "69"),
      ]),
      SelectFilter("status", "Status", 0, [
        SelectFilterOption("All", ""),
        SelectFilterOption("Ongoing", "ongoing"),
        SelectFilterOption("Completed", "completed"),
        SelectFilterOption("Hiatus", "hiatus"),
      ]),
      SelectFilter("type", "Type", 0, [
        SelectFilterOption("All", ""),
        SelectFilterOption("Manga", "manga"),
        SelectFilterOption("Manhwa", "manhwa"),
        SelectFilterOption("Manhua", "manhua"),
        SelectFilterOption("Comic", "comic"),
        SelectFilterOption("Novel", "novel"),
      ]),
      SelectFilter("order", "Order", 0, [
        SelectFilterOption("Default", ""),
        SelectFilterOption("A-Z", "title"),
        SelectFilterOption("Z-A", "titlereverse"),
        SelectFilterOption("Update", "update"),
        SelectFilterOption("Added", "latest"),
        SelectFilterOption("Popular", "popular"),
      ]),
    ];
  }
}

// ignore: main_first_positional_parameter_type
Armageddon main(MSource source) {
  return Armageddon(source: source);
}

// }
