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

class AsmodeusScans extends MProvider {
  AsmodeusScans({required this.source});

  MSource source;

  late final Client client = Client(source);

  @override
  String? get baseUrl => source.baseUrl;

  @override
  Future<MPages> getPopular(int page) async {
    Uri uri = Uri.https(baseUrl!.replaceFirst("https://", ""), "/series");
    Response res = await client.get(
      getPreferenceValue(source.id!, "use_web_archive")
          ? Uri.parse("https://web.archive.org/save/$uri")
          : uri,
    );
    MDocument doc = parseHtml(res.body);
    List<MElement>? entries = doc.select(".group");
    if (entries == null) {
      return MPages([], false);
    }
    List<MManga> list = [];
    for (var entry in entries) {
      String name = entry.attr("title") ?? "";
      if (name.startsWith("[ Novel ]")) {
        continue;
      }
      String href = entry.selectFirst("a")!.getHref!;
      list.add(
        MManga(
          genre: jsonDecode(entry.attr("tags") ?? "[]"),
          imageUrl: RegExp(
            r"(?<=background-image:\s*url\().*?(?=\))",
          ).firstMatch(entry.selectFirst(".bg-cover")?.attr("style") ?? "")?[0],
          link: href.startsWith("/web/")
              ? href.substring(20)
              : Uri.https(
                  baseUrl!.replaceFirst("https://", ""),
                  href,
                ).toString(),
          name: entry.attr("title"),
        ),
      );
    }
    return MPages(list, false);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    Uri uri = Uri.https(baseUrl!.replaceFirst("https://", ""), "/latest");
    MDocument doc = parseHtml(
      (await client.get(
        getPreferenceValue(source.id!, "use_web_archive")
            ? Uri.parse("https://web.archive.org/save/$uri")
            : uri,
      )).body,
    );
    List<MElement>? entries = doc.select(".group");
    if (entries == null) {
      return MPages([], false);
    }
    List<MManga> list = [];
    for (var entry in entries) {
      MElement a = entry.selectFirst("a[style*=\"background-image\"]")!;
      String name = a.attr("title") ?? "";
      if (name.startsWith("[ Novel ]")) {
        continue;
      }
      List<MChapter> chapters = [];
      List<MElement> chapterEntries = entry.select("a[title^=\"Chapter\"]")!;
      for (var ch in chapterEntries) {
        if (ch.selectFirst("img[alt=\"Coin\"]") == null) {
          String? dateString = ch.selectFirst("span.whitespace-nowrap")?.text;
          String href = ch.getHref!;
          chapters.add(
            MChapter(
              name: ch.attr("title"),
              url: href.startsWith("/web/")
                  ? href.substring(20)
                  : Uri.https(
                      baseUrl!.replaceFirst("https://", ""),
                      href,
                    ).toString(),
              dateUpload: dateString == null
                  ? null
                  : parseDates([dateString], "MMM d, y", "en_US")[0],
            ),
          );
        }
      }
      String href = a.getHref!;
      list.add(
        MManga(
          genre: jsonDecode(entry.attr("tags") ?? "[]"),
          imageUrl: RegExp(
            r"(?<=background-image:\s*url\().*?(?=\))",
          ).firstMatch(a.attr("style") ?? "")?[0],
          link: href.startsWith("/web/")
              ? href.substring(20)
              : Uri.https(
                  baseUrl!.replaceFirst("https://", ""),
                  href,
                ).toString(),
          name: a.attr("title"),
          chapters: chapters,
        ),
      );
    }
    return MPages(list, false);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    query = query.toLowerCase();
    Uri uri = Uri.https(baseUrl!.replaceFirst("https://", ""), "/series");
    Response res = await client.get(
      getPreferenceValue(source.id!, "use_web_archive")
          ? Uri.parse("https://web.archive.org/save/$uri")
          : uri,
    );
    Set<String> includeGenres = <String>{};
    Set<String> excludeGenres = <String>{};
    for (TriStateFilter filter in filterList.filters[0].state) {
      switch (filter.state) {
        case 1:
          includeGenres.add(filter.value);
          break;
        case 2:
          excludeGenres.add(filter.value);
          break;
      }
    }
    MDocument doc = parseHtml(res.body);
    List<MElement>? entries = doc.select(".group");
    if (entries == null) {
      return MPages([], false);
    }
    List<MManga> list = [];
    for (var entry in entries) {
      String name = entry.attr("title") ?? "";
      if (name.startsWith("[ Novel ]") || !name.toLowerCase().contains(query)) {
        continue;
      }
      List<String> genre = jsonDecode(entry.attr("tags") ?? "[]");
      Set<String> genreSet = genre.map((g) => g.toLowerCase().trim()).toSet();
      if (includeGenres.isNotEmpty &&
          genreSet.intersection(includeGenres).isEmpty) {
        continue;
      }
      if (genreSet.intersection(excludeGenres).isNotEmpty) {
        continue;
      }
      String href = entry.selectFirst("a")!.getHref!;
      list.add(
        MManga(
          genre: genre,
          imageUrl: RegExp(
            r"(?<=background-image:\s*url\().*?(?=\))",
          ).firstMatch(entry.selectFirst(".bg-cover")?.attr("style") ?? "")?[0],
          link: href.startsWith("/web/")
              ? href.substring(20)
              : Uri.https(
                  baseUrl!.replaceFirst("https://", ""),
                  href,
                ).toString(),
          name: name,
        ),
      );
    }
    return MPages(list, false);
  }

  @override
  Future<MManga> getDetail(String url) async {
    MDocument doc = parseHtml(
      (await client.get(
        Uri.parse(
          getPreferenceValue(source.id!, "use_web_archive")
              ? "https://web.archive.org/save/$url"
              : url,
        ),
      )).body,
    );

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
      if ((entry.selectFirst("img[alt=\"Coin\"]")?.outerHtml ?? "").isEmpty) {
        String? dateString = entry.selectFirst(".text-xs:not(:has(*))")?.text;
        String? imageStyle = entry
            .selectFirst("[style*=\"background-image\"]")
            ?.attr("style");
        String href = entry.getHref!;
        chapters.add(
          MChapter(
            name: entry.attr("title"),
            url: href.startsWith("/web/")
                ? href.substring(20)
                : Uri.https(
                    baseUrl!.replaceFirst("https://", ""),
                    href,
                  ).toString(),
            dateUpload: dateString == null
                ? null
                : parseDates([dateString], "MMM d, y", "en_US")[0],
            thumbnailUrl: imageStyle == null
                ? null
                : RegExp(
                    r"(?<=background-image:\s*url\().*?(?=\))",
                  ).firstMatch(imageStyle)?[0],
          ),
        );
      }
    }

    return MManga(
      author: properties["author"],
      artist: properties["artist"],
      genre: doc
          .selectFirst("meta[name=\"keywords\"]")
          ?.attr("content")
          ?.split(", ")
          .where((genre) => !genre.startsWith("Asmo"))
          .toList(),
      imageUrl: doc.selectFirst("meta[property=\"og:image\"]")?.attr("content"),
      link: url,
      name: doc
          .selectFirst("meta[property=\"og:title\"]")
          ?.attr("content")
          ?.trim(),
      status: _toStatus(properties["status"]),
      description: doc
          .selectFirst("meta[property=\"og:description\"]")
          ?.attr("content")
          ?.trim(),
      chapters: chapters,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPageList(String url) async {
    Response res = await client.get(
      Uri.parse(
        getPreferenceValue(source.id!, "use_web_archive")
            ? "https://web.archive.org/save/$url"
            : url,
      ),
    );
    MDocument doc = parseHtml(res.body);
    return doc
            .select("#pages img[uid]")!
            .map(
              (img) => {
                "url": "https://cdn.meowing.org/uploads/${img.attr("uid")}",
                "headers": {"Referer": url},
              },
            )
            .toList() ??
        [];
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter("genre", "Genre", [
        TriStateFilter("academy", "academy"),
        TriStateFilter("action", "action"),
        TriStateFilter("adaptation", "adaptation"),
        TriStateFilter("adaption", "adaption"),
        TriStateFilter("adeventure", "adeventure"),
        TriStateFilter("advanture", "advanture"),
        TriStateFilter("adventure", "adventure"),
        TriStateFilter("banished", "banished"),
        TriStateFilter("battle fantasy", "battle fantasy"),
        TriStateFilter("big breasts", "big breasts"),
        TriStateFilter("cheat abilities", "cheat abilities"),
        TriStateFilter("comdey", "comdey"),
        TriStateFilter("comedy", "comedy"),
        TriStateFilter("crossdressing", "crossdressing"),
        TriStateFilter("cuckold", "cuckold"),
        TriStateFilter("darma", "darma"),
        TriStateFilter("death flag", "death flag"),
        TriStateFilter("demon", "demon"),
        TriStateFilter("diplomacy", "diplomacy"),
        TriStateFilter("drama", "drama"),
        TriStateFilter("ecchi", "ecchi"),
        TriStateFilter("fantasy", "fantasy"),
        TriStateFilter("fantsasy", "fantsasy"),
        TriStateFilter("fight", "fight"),
        TriStateFilter("game world", "game world"),
        TriStateFilter("harem", "harem"),
        TriStateFilter("isekai", "isekai"),
        TriStateFilter("kamen rider", "kamen rider"),
        TriStateFilter("kingdom building", "kingdom building"),
        TriStateFilter("magic", "magic"),
        TriStateFilter("mangatoon", "mangatoon"),
        TriStateFilter("mecha", "mecha"),
        TriStateFilter("medical", "medical"),
        TriStateFilter("military", "military"),
        TriStateFilter("monster", "monster"),
        TriStateFilter("monsters", "monsters"),
        TriStateFilter("monters", "monters"),
        TriStateFilter("mystery", "mystery"),
        TriStateFilter("nobility", "nobility"),
        TriStateFilter("official colored", "official colored"),
        TriStateFilter("overpowered", "overpowered"),
        TriStateFilter(
          "overpowered main character",
          "overpowered main character",
        ),
        TriStateFilter("regression", "regression"),
        TriStateFilter("reincarnation", "reincarnation"),
        TriStateFilter("revenge", "revenge"),
        TriStateFilter("reverse harem", "reverse harem"),
        TriStateFilter("rom-com", "rom-com"),
        TriStateFilter("romace", "romace"),
        TriStateFilter("romance", "romance"),
        TriStateFilter("royalty & nobility", "royalty & nobility"),
        TriStateFilter("royalty/nobility", "royalty/nobility"),
        TriStateFilter("school life", "school life"),
        TriStateFilter("second chance", "second chance"),
        TriStateFilter("seinen", "seinen"),
        TriStateFilter("serializing", "serializing"),
        TriStateFilter("shoujo", "shoujo"),
        TriStateFilter("shounen", "shounen"),
        TriStateFilter("slice of life", "slice of life"),
        TriStateFilter("superhero", "superhero"),
        TriStateFilter("supernatural", "supernatural"),
        TriStateFilter("system", "system"),
        TriStateFilter("time travel", "time travel"),
        TriStateFilter("unparalleled", "unparalleled"),
        TriStateFilter("video games", "video games"),
        TriStateFilter("villainess", "villainess"),
        TriStateFilter("villian", "villian"),
        TriStateFilter("violence", "violence"),
        TriStateFilter("war", "war"),
        TriStateFilter("weak to strong", "weak to strong"),
      ]),
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [
      CheckBoxPreference(
        key: "use_web_archive",
        title: "Use web.archive.org",
        summary: "",
        value: false,
      ),
    ];
  }
}

// ignore: main_first_positional_parameter_type
AsmodeusScans main(MSource source) {
  return AsmodeusScans(source: source);
}

// }
