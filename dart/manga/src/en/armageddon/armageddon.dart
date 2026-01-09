// {

import 'dart:convert';

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

List<String> _getImageURLs(Response res) {
  MDocument doc = parseHtml(res.body);
  MElement script = doc.selectFirst(".maincontent script")!;
  String base64Str = RegExp(
    r"(?<=')Wy(?:[\w\-\/]{4})+(?:Jd|[\w\-\/]iXQ==|[\w\-\/]{2}Il0=)",
  ).firstMatch(script.text!)![0]!;
  String jsonStr = utf8.decode(base64.decode(base64Str));
  return jsonDecode(jsonStr);
}

const _imageHeaders = {
  "Content-Type": "image/webp",
  "Referer": "https://www.silentquill.net/",
};

Future<bool> _testImage(String url, String referer, Client client) async {
  Response res = await client.head(Uri.parse(url), headers: _imageHeaders);
  return res.statusCode == 200;
}

const chapterTemps = [
  ["", ""],
  ["Ch%20", ""],
  ["Chapter%20", ""],
];

const pageTemps = [
  ["", ".webp"],
  ["", "_out.webp"],
  ["Ch%20", "Page%20", ".webp"],
  ["Chapter%20", "Page%20", ".webp"],
];

class _Subformat {
  List<String> temp;
  List<int> subs;

  _Subformat({required this.temp, required this.subs});

  int get length => subs.length;

  String getString(List<String> values) {
    int i = 0;
    String res = "";
    while (i < values.length) {
      res += temp[i];
      res += values[i].padLeft(subs[i]);
      i++;
    }
    res += temp[i];
    return res;
  }
}

class _Format {
  String prefix;
  _Subformat chapter;
  _Subformat page;

  _Format({required this.prefix, required this.chapter, required this.page});

  String getImageURL(String chapter, String page) {
    String chapterSegment = this.chapter.getString([chapter]);
    String pageSegment = this.page.length == 1
        ? this.page.getString([page])
        : this.page.getString([chapter, page]);
    return "$prefix/$chapterSegment/$pageSegment";
  }

  Future<bool> test(String chapter, String referer, Client client) {
    String url = getImageURL(chapter, "1");
    return _testImage(url, referer, client);
  }

  Future<_Format?> getFuture(
    String chapter,
    String referer,
    Client client,
  ) async {
    if (await test(chapter, referer, client)) {
      return this;
    }
    return null;
  }
}

Future<_Format> _getFormat(
  String chapter,
  String firstImage,
  String referer,
  Client client,
) async {
  Uri uri = Uri.parse(firstImage);
  String origin = uri.origin;
  String pathname = uri.path;
  List<String> paths = pathname.split("/");
  String pageFormat = paths.removeLast();
  String chapterFormat = paths.removeLast();
  String prefix = "$origin${paths.join("/")}";
  List<String> chapterTemp = chapterFormat.split(
    RegExp(r"(?<!%\w?)[\d\.]+", caseSensitive: false),
  );
  List<int> chapterSubs = RegExp(
    r"(?<!%\w?)[\d\.]+",
    caseSensitive: false,
  ).allMatches(chapterFormat).map((e) => e[0]!.length).toList();
  List<String> pageTemp = pageFormat.split(RegExp(r"(?<!%\w?)\d+"));
  List<int> pageSubs = RegExp(
    r"(?<!%\w?)\d+",
  ).allMatches(pageFormat).map((e) => e[0]!.length).toList();
  _Format format = _Format(
    prefix: prefix,
    chapter: _Subformat(temp: chapterTemp, subs: chapterSubs),
    page: _Subformat(temp: pageTemp, subs: pageSubs),
  );
  if (await format.test(chapter, referer, client)) {
    return format;
  }
  List<Future<_Format?>> futures = [];
  if (pageTemp.length == 2) {
    for (int i = chapter.length; i < 5; i++) {
      for (int j = 1; j < 5; j++) {
        _Format format = _Format(
          prefix: prefix,
          chapter: _Subformat(temp: chapterTemp, subs: [i]),
          page: _Subformat(temp: pageTemp, subs: [j]),
        );
        futures.add(format.getFuture(chapter, referer, client));
      }
    }
  } else {
    List<Future<_Format?>> futures = [];
    for (int i = chapter.length; i < 5; i++) {
      for (int j = chapter.length; j < 5; j++) {
        for (int k = 1; j < 5; j++) {
          _Format format = _Format(
            prefix: prefix,
            chapter: _Subformat(temp: chapterTemp, subs: [i]),
            page: _Subformat(temp: pageTemp, subs: [j, k]),
          );
          futures.add(format.getFuture(chapter, referer, client));
        }
      }
    }
  }
  for (var future in futures) {
    _Format? format = await future;
    if (format != null) {
      return format;
    }
  }
  for (var chapterTemp in chapterTemps) {
    for (var pageTemp in pageTemps) {
      futures.clear();
      if (pageTemp.length == 2) {
        for (int i = chapter.length; i < 5; i++) {
          for (int j = 1; j < 5; j++) {
            _Format format = _Format(
              prefix: prefix,
              chapter: _Subformat(temp: chapterTemp, subs: [i]),
              page: _Subformat(temp: pageTemp, subs: [j]),
            );
            futures.add(format.getFuture(chapter, referer, client));
          }
        }
      } else {
        List<Future<_Format?>> futures = [];
        for (int i = chapter.length; i < 5; i++) {
          for (int j = chapter.length; j < 5; j++) {
            for (int k = 1; j < 5; j++) {
              _Format format = _Format(
                prefix: prefix,
                chapter: _Subformat(temp: chapterTemp, subs: [i]),
                page: _Subformat(temp: pageTemp, subs: [j, k]),
              );
              futures.add(format.getFuture(chapter, referer, client));
            }
          }
        }
      }
      for (var future in futures) {
        _Format? format = await future;
        if (format != null) {
          return format;
        }
      }
    }
  }
  throw "format not found";
}

Future<int> _getNumPages(
  String chapter,
  _Format format,
  String referer,
  Client client,
) async {
  int l = 1;
  int r = 100;
  while (r - l > 1) {
    int m = (l + r) >> 1;
    if (await format.test(chapter, referer, client)) {
      l = m;
    } else {
      r = m;
    }
  }
  return l;
}

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

    Uri premiumUri = Uri(
      scheme: uri.scheme,
      host: "web.archive.org",
      path: "/web/20250000000000id_/https://armageddontl.com${uri.path}",
    );
    Response premiumRes = await client.get(premiumUri);

    if (premiumRes.statusCode == 200) {
      MDocument premiumDoc = parseHtml(premiumRes.body);
      List<MElement> premiumChapterElements = premiumDoc.select(
        "#chapterlist li",
      )!;
      if (premiumChapterElements.length > chapterElements.length) {
        premiumChapterElements = premiumChapterElements.sublist(
          0,
          premiumChapterElements.length - chapterElements.length,
        );
        for (var entry in premiumChapterElements) {
          MElement a = entry.selectFirst("a")!;
          chapters.add(
            MChapter(
              name: a
                  .selectFirst(".chapternum")
                  ?.text,
              url: a.getHref,
              dateUpload: parseDates(
                [a.selectFirst(".chapterdate")!.text],
                "MMMM d, y",
                "en_US",
              )[0],
            ),
          );
        }
      }
    }

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
    if (uri.host == "www.silentquill.net") {
      Response res = await client.get(uri);
      List<String> images = _getImageURLs(res);
      return images
          .map((url) => {"url": url, "headers": _imageHeaders})
          .toList();
    } else {
      Uri mangaUri = Uri(
        scheme: uri.scheme,
        host: "www.silentquill.net",
        path: uri.path.replaceFirst(RegExp(r"-ch(?:apter)?(?:-\d+)+(?=/)"), ""),
      );
      String chapter = RegExp(
        r"(?<=-ch(?:apter)?-)\d+(?:-\d+)*(?=/)",
      ).firstMatch(uri.path)![0]!.replaceAll("-", ".");
      Response mangaRes = await client.get(mangaUri);
      MDocument mangaDoc = parseHtml(mangaRes.body);
      MElement a = mangaDoc.selectFirst("#chapterlist li a")!;
      Uri chapterUri = Uri.parse(a.getHref!);
      Response chapterRes = await client.get(chapterUri);
      List<String> images = _getImageURLs(chapterRes);
      _Format format = await _getFormat(chapter, images[1], url, client);
      int numPages = await _getNumPages(chapter, format, url, client);
      List<Map<String, dynamic>> ret = [];
      for (int i = 1; i <= numPages; i++) {
        ret.add({
          "url": format.getImageURL(chapter, i.toString()),
          "headers": _imageHeaders,
        });
      }
      return ret;
    }
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
