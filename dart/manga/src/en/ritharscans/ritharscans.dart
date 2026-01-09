// {

import 'dart:convert';

import 'package:mangayomi/bridge_lib.dart';

MPages _mangaListFromSearchPage(Response res, String baseUrl) {
  MDocument doc = parseHtml(res.body);
  List<MElement>? entries = doc.select(".group");
  if (entries == null) {
    return MPages([], false);
  }
  List<MManga> list = [];
  for (var entry in entries) {
    list.add(
      MManga(
        genre: (jsonDecode(entry.attr("tags") ?? "[]") as List<String>)
            .map((tag) => tag.trim())
            .toList(),
        imageUrl: RegExp(r"(?<=background-image:\s*url\().*?(?=\))").firstMatch(
          entry.selectFirst("[style*=\"background-image\"]")?.attr("style") ??
              "",
        )?[0],
        link: Uri.https(
          baseUrl.replaceFirst("https://", ""),
          entry.selectFirst("a")?.getHref ?? "",
        ).toString(),
        name: entry.attr("title"),
      ),
    );
  }
  return MPages(list, false);
}

MStatus _toStatus(String? status) {
  return switch (status?.toLowerCase()) {
    "ongoing" => MStatus.ongoing,
    "completed" => MStatus.completed,
    "on hold" => MStatus.onHiatus,
    "dropped" => MStatus.canceled,
    _ => MStatus.unknown,
  };
}

class RitharScans extends MProvider {
  RitharScans({required this.source});

  MSource source;

  late final Client client = Client(source);

  @override
  String? get baseUrl => source.baseUrl;

  @override
  Future<MPages> getPopular(int page) async {
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/search", {
        "status": "ongoing",
      }),
    );
    return _mangaListFromSearchPage(res, baseUrl!);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    MDocument doc = parseHtml(
      (await client.get(
        Uri.https(baseUrl!.replaceFirst("https://", ""), "/latest"),
      )).body,
    );
    List<MElement>? entries = doc.select(".group");
    if (entries == null) {
      return MPages([], false);
    }
    List<MManga> list = [];
    for (var entry in entries) {
      MElement? a = entry.selectFirst("a[style*=\"background-image\"]");
      List<MChapter> chapters = [];
      List<MElement> chapterEntries = entry.select("a[title^=\"Chapter\"]")!;
      for (var ch in chapterEntries) {
        String? dateString = ch.selectFirst("span.whitespace-nowrap")?.text;
        chapters.add(
          MChapter(
            name: ch.attr("title"),
            url: a?.getHref,
            dateUpload: dateString == null
                ? null
                : parseDates([dateString], "MMM d, y", "en_US")[0],
          ),
        );
      }
      list.add(
        MManga(
          imageUrl: RegExp(
            r"(?<=background-image:\s*url\().*?(?=\))",
          ).firstMatch(a?.attr("style") ?? "")?[0],
          link: a?.getHref,
          name: a?.attr("title"),
          chapters: chapters,
        ),
      );
    }
    return MPages(list, false);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    Map<String, String> params = {"title": query};

    final filters = filterList.filters;
    for (var f in filters) {
      SelectFilter filter = f;
      params[filter.name] = filter.values[filter.state].value;
    }
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/search", params),
    );
    return _mangaListFromSearchPage(res, baseUrl!);
  }

  @override
  Future<MManga> getDetail(String url) async {
    MDocument doc = parseHtml((await client.get(Uri.parse(url))).body);

    Map<String, String?> properties = doc
        .select(
          "div:has(>div>img.h-auto[src^=\"https://api.iconify.design/\"])",
        )!
        .fold(<String, String?>{}, (acc, e) {
          acc[e.selectFirst("span")?.text?.toLowerCase() ?? ""] = e
              .selectFirst("div:not(:has(*))")
              ?.text
              ?.trim();
          return acc;
        });

    List<MChapter> chapters = [];

    for (var entry in doc.select("a.group")!) {
      String? dateString = entry.selectFirst(".text-xs:not(:has(*))")?.text;
      chapters.add(
        MChapter(
          name: entry.attr("title"),
          url: Uri.https(
            baseUrl!.replaceFirst("https://", ""),
            entry.getHref ?? "",
          ).toString(),
          dateUpload: dateString == null
              ? null
              : parseDates([dateString], "MMM d, y", "en_US")[0],
          thumbnailUrl: RegExp(r"(?<=background-image:\s*url\().*?(?=\))")
              .firstMatch(
                entry
                        .selectFirst("[style*=\"background-image\"]")
                        ?.attr("style") ??
                    "",
              )?[0],
        ),
      );
    }

    return MManga(
      genre: doc
          .selectFirst("meta[name=\"keywords\"]")
          ?.attr("content")
          ?.split(", ")
          .where((genre) => !genre.startsWith("Asmo"))
          .toList(),
      imageUrl:
          RegExp(r"(?<=background-image:\s*url\().*?(?=\))").firstMatch(
            doc
                    .selectFirst("div.bg-cover[style*=\"background-image\"]")
                    ?.attr("style") ??
                "",
          )?[0] ??
          doc.selectFirst("meta[property=\"og:image\"]")?.attr("content"),
      link: url,
      name: doc.selectFirst("#serieTitle")?.attr("value")?.trim(),
      status: _toStatus(doc.selectFirst("[title=\"Status\"]")?.text!.trim()),
      description: doc
          .selectFirst("meta[property=\"og:description\"]")
          ?.attr("content")
          ?.trim(),
      chapters: chapters,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPageList(String url) async {
    Response res = await client.get(Uri.parse(url));
    MDocument doc = parseHtml(res.body);
    Map<String, dynamic> data = jsonDecode(
      doc.selectFirst('script[type="application/ld+json"]')!.text!,
    );
    String series = RegExp(
      r"(?<=\/)[\w\-]+$",
    ).firstMatch(data["isPartOf"]["url"])![0]!;
    String chapter = RegExp(r"(?<=\/)[\w\-]+$").firstMatch(data["url"])![0]!;

    List<Map<String, dynamic>> pages = [];
    for (int i = 0; i < data["numberOfPages"]; i++) {
      pages.add({
        "url": Uri.https(
          baseUrl!.replaceFirst("https://", ""),
          "/storage/series/webtoon/$series/chapters/$chapter/${(i + 1).toString().padLeft(3, "0")}.jpg",
        ).toString(),
        "headers": {"Referer": url},
      });
    }

    return pages;
  }

  @override
  List<dynamic> getFilterList() {
    return [
      SelectFilter("status", "Status", 0, [
        SelectFilterOption("All", ""),
        SelectFilterOption("Ongoing", "ongoing"),
        SelectFilterOption("Completed", "completed"),
        SelectFilterOption("Dropped", "dropped"),
        SelectFilterOption("On Hold", "onhold"),
        SelectFilterOption("Soon", "soon"),
      ]),
      SelectFilter("genre", "Genre", 0, [
        SelectFilterOption("All", ""),
        SelectFilterOption("Action", "1"),
        SelectFilterOption("Adventure", "2"),
        SelectFilterOption("Seinen", "3"),
        SelectFilterOption("Fantasy", "4"),
        SelectFilterOption("Comedy", "5"),
        SelectFilterOption("Drama", "6"),
        SelectFilterOption("Romance", "7"),
        SelectFilterOption("Shounen", "8"),
        SelectFilterOption("Isekai", "9"),
        SelectFilterOption("slice of life", "10"),
        SelectFilterOption("harem", "11"),
        SelectFilterOption("school life", "12"),
        SelectFilterOption("mystery", "13"),
        SelectFilterOption("magic", "14"),
      ]),
    ];
  }
}

// ignore: main_first_positional_parameter_type
RitharScans main(MSource source) {
  return RitharScans(source: source);
}

// }
