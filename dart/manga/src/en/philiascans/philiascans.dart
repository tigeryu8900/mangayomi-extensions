// {

import 'package:mangayomi/bridge_lib.dart';

MStatus _toStatus(String? status) {
  return switch (status?.toLowerCase()) {
    "releasing" => MStatus.ongoing,
    "completed" => MStatus.completed,
    "hiatus" => MStatus.onHiatus,
    "dropped" => MStatus.canceled,
    _ => MStatus.unknown,
  };
}

MPages _mangaListFromSearch(Response res) {
  MDocument doc = parseHtml(res.body);
  List<MManga> mangas = [];
  for (MElement entry in doc.select(".original .inner")!) {
    MElement? img = entry.selectFirst(".poster-image-wrapper> img[data-src]");
    mangas.add(
      MManga(
        imageUrl: img?.getDataSrc,
        link: entry.selectFirst("a.poster")?.getHref,
        name: img?.attr("alt"),
      ),
    );
  }
  return MPages(
    mangas,
    doc.selectFirst(".pagination .page-item.disabled [rel=\"last\"]") != null,
  );
}

class PhiliaScans extends MProvider {
  PhiliaScans({required this.source});

  MSource source;

  late final Client client = Client(source);

  @override
  String? get baseUrl => source.baseUrl;

  @override
  Future<MPages> getPopular(int page) async {
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/page/$page/", {
        "post_type": "wp-manga",
        "s": "",
        "sort": "most_viewed",
      }),
    );

    return _mangaListFromSearch(res);
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/page/$page/", {
        "post_type": "wp-manga",
        "s": "",
        "sort": "recently_added",
      }),
    );

    return _mangaListFromSearch(res);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    Map<String, dynamic> params = {"post_type": "wp-manga", "s": query};
    for (var f in filterList.filters) {
      switch (f.type) {
        case "type[]":
        case "genre[]":
        case "release[]":
          {
            GroupFilter filter = f;
            List<String> values = [];
            for (CheckBoxFilter c in filter.state) {
              if (c.state) {
                values.add(c.value);
              }
            }
            if (values.isNotEmpty) {
              params[filter.type!] = values;
            }
            break;
          }
        case "genre_mode":
          {
            CheckBoxFilter filter = f;
            if (filter.state) {
              params[filter.type!] = filter.value;
            }
            break;
          }
        case "sort":
          {
            SelectFilter filter = f;
            params[filter.type!] = filter.values[filter.state].value;
            break;
          }
      }
    }

    Response res = await client.get(
      Uri.https(baseUrl!.replaceFirst("https://", ""), "/page/$page/", params),
    );

    return _mangaListFromSearch(res);
  }

  @override
  Future<MManga> getDetail(String url) async {
    Uri uri = Uri.parse(url);
    Response res = await client.get(uri);
    MDocument doc = parseHtml(res.body);

    List<MElement> chapterElements = doc.select("#free-list li")!;
    List<MChapter> chapters = [];

    for (var entry in chapterElements) {
      MElement a = entry.selectFirst("a")!;
      chapters.add(
        MChapter(
          name:
              "${entry.attr("data-chapter")?.trim() ?? ""} ${a.attr("title")?.trim() ?? ""}"
                  .trim(),
          url: a.getHref,
          thumbnailUrl: a.selectFirst("img")?.getDataSrc,
        ),
      );
    }

    Map<String, String?> properties = doc
        .select(".manga-stats .stat-item .stat-details")!
        .fold(<String, String?>{}, (acc, e) {
          List<MElement> spans = e.select("span")!;
          acc[spans[0].text!.trim().toLowerCase()] = spans[1].text!.trim();
          return acc;
        });

    return MManga(
      author: properties["author"],
      artist: properties["artist"],
      genre: doc
          .select(".genre-list .genre-link")!
          .map((e) => e.text!.trim())
          .toList(),
      imageUrl: doc.selectFirst("meta[property=\"og:image\"]")?.attr("content"),
      link: url,
      name: doc.selectFirst("meta[property=\"og:image:alt\"]")?.attr("content"),
      status: _toStatus(properties["status"]),
      description: doc.selectFirst(".comic-desc")?.text?.trim(),
      chapters: chapters,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPageList(String url) async {
    MDocument doc = parseHtml((await client.get(Uri.parse(url))).body);
    List<MElement> imgs = doc.select("#ch-images img[data-src]")!;
    List<Map<String, dynamic>> images = [];
    for (var img in imgs) {
      images.add({
        "url": img.getDataSrc,
        "headers": {"Referer": baseUrl},
      });
    }
    return images;
  }

  @override
  List<dynamic> getFilterList() {
    int year = DateTime.now().year;
    return [
      GroupFilter("type[]", "Type", [
        CheckBoxFilter("Manga", "manga"),
        CheckBoxFilter("Manhua", "manhua"),
        CheckBoxFilter("Manhwa", "manhwa"),
        CheckBoxFilter("Seinen", "seinen"),
      ]),
      GroupFilter("genre[]", "Genre", [
        CheckBoxFilter("Action", "29"),
        CheckBoxFilter("Adventure", "38"),
        CheckBoxFilter("Comedy", "42"),
        CheckBoxFilter("Crime", "30"),
        CheckBoxFilter("Drama", "34"),
        CheckBoxFilter("Ecchi", "39"),
        CheckBoxFilter("Fantasy", "43"),
        CheckBoxFilter("Gore", "157"),
        CheckBoxFilter("Gourmet", "188"),
        CheckBoxFilter("Harem", "46"),
        CheckBoxFilter("Historical", "40"),
        CheckBoxFilter("Horror", "44"),
        CheckBoxFilter("Isekai", "31"),
        CheckBoxFilter("Josie", "173"),
        CheckBoxFilter("Josie", "302"),
        CheckBoxFilter("Josie", "174"),
        CheckBoxFilter("Magic", "87"),
        CheckBoxFilter("Martial Arts", "61"),
        CheckBoxFilter("Medical", "32"),
        CheckBoxFilter("Monsters", "99"),
        CheckBoxFilter("Music", "303"),
        CheckBoxFilter("Mystery", "35"),
        CheckBoxFilter("Psychological", "62"),
        CheckBoxFilter("Regression", "122"),
        CheckBoxFilter("Romance", "33"),
        CheckBoxFilter("School Life", "47"),
        CheckBoxFilter("Sci-Fi", "36"),
        CheckBoxFilter("Seinen", "48"),
        CheckBoxFilter("Shoujo", "69"),
        CheckBoxFilter("Shounen", "55"),
        CheckBoxFilter("Slice of Life", "37"),
        CheckBoxFilter("Sports", "45"),
        CheckBoxFilter("Supernatural", "49"),
        CheckBoxFilter("Survival", "121"),
        CheckBoxFilter("Tragedy", "41"),
        CheckBoxFilter("Villainess", "253"),
        CheckBoxFilter("War", "120"),
        CheckBoxFilter("Yuri", "195"),
      ]),
      CheckBoxFilter("Include all selected genres", "and", "genre_mode"),
      GroupFilter(
        "release[]",
        "Year",
        List.generate(
          year - 2018,
          (i) => CheckBoxFilter("${year - i}", "${year - i}"),
        ),
      ),
      SelectFilter("sort", "Sort", 0, [
        SelectFilterOption("Newest", "recently_added"),
        SelectFilterOption("Alphabetical", "title_az"),
        SelectFilterOption("Most Viewed", "most_viewed"),
      ]),
    ];
  }
}

// ignore: main_first_positional_parameter_type
PhiliaScans main(MSource source) {
  return PhiliaScans(source: source);
}

// }
