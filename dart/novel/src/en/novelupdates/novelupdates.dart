// {

import 'dart:convert';

import 'package:mangayomi/bridge_lib.dart';

MPages _mangaListFromPage(Response res, int sourceId) {
  final MDocument doc = parseHtml(res.body);
  final mangaElements = doc.select("div.search_main_box_nu");
  if (mangaElements == null) {
    return MPages([], false);
  }
  List<MManga> list = [];
  for (var element in mangaElements) {
    final name = element.selectFirst(".search_title > a")?.text;
    final imageUrl = element.selectFirst("img")?.getSrc;
    final link = element.selectFirst(".search_title > a")?.getHref;
    list.add(
      MManga(
        name: name,
        imageUrl: getPreferenceValue(sourceId, "use_web_archive_images")
            ? "https://web.archive.org/save/$imageUrl"
            : imageUrl,
        link: link,
      ),
    );
  }

  final hasNextPage =
      doc.selectFirst("div.digg_pagination > a.next_page")?.text == " →";
  return MPages(list, hasNextPage);
}

MStatus _toStatus(String status) {
  if (status.contains("Ongoing")) {
    return MStatus.ongoing;
  } else if (status.contains("Completed")) {
    return MStatus.completed;
  } else if (status.contains("Hiatus")) {
    return MStatus.onHiatus;
  } else if (status.contains("Dropped")) {
    return MStatus.canceled;
  } else {
    return MStatus.unknown;
  }
}

class NovelUpdates extends MProvider {
  NovelUpdates({required this.source});

  MSource source;

  late final Client client = Client(source);

  @override
  Future<MPages> getPopular(int page) async {
    Uri uri = Uri.https(
      source.baseUrl!.replaceFirst("https://", ""),
      "/series-finder/",
      {"sf": "1", "sort": "sdate", "order": "desc", "pg": "$page"},
    );
    return _mangaListFromPage(
      await client.get(uri, headers: getHeader(source.baseUrl!)),
      source.id!,
    );
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    Response res = await client.get(
      Uri.https(
        source.baseUrl!.replaceFirst("https://", ""),
        "/latest-series/",
        {"st": "1", "pg": "$page"},
      ),
      headers: getHeader(source.baseUrl!),
    );
    return _mangaListFromPage(res, source.id!);
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    Map<String, dynamic> params = {"sf": "1", "sh": query, "pg": "$page"};

    final filters = filterList.filters;

    for (var f in filters) {
      switch (f.type) {
        case "nt":
        case "org":
          {
            GroupFilter filter = f;
            List<CheckBoxFilter> state = filter.state.cast<CheckBoxFilter>();
            List<String> nt = [];
            for (var checkbox in state) {
              if (checkbox.state) {
                nt.add(checkbox.value);
              }
            }
            if (nt.isNotEmpty) {
              params[filter.type as String] = nt.join(",");
            }
            break;
          }
        case "rl":
        case "rf":
        case "rvc":
        case "rt":
        case "rtc":
        case "rct":
        case "dtf":
        case "dt":
          {
            GroupFilter filter = f;
            SelectFilter modeFilter = filter.state[0];
            TextFilter textFilter = filter.state[1];
            if (textFilter.state.isNotEmpty) {
              SelectFilterOption option = modeFilter.values[modeFilter.state];
              params[modeFilter.type as String] = option.value;
              params[textFilter.type as String] = textFilter.state;
            }
            break;
          }
        case "gi":
        case "tgi":
          {
            GroupFilter filter = f;
            SelectFilter modeFilter = filter.state[0];
            GroupFilter groupFilter = filter.state[1];
            List<TriStateFilter> triStateFilters = groupFilter.state
                .cast<TriStateFilter>();
            List<String> i = [];
            List<String> e = [];
            for (var filter in triStateFilters) {
              switch (filter.state) {
                case 1:
                  i.add(filter.value);
                  break;
                case 2:
                  e.add(filter.value);
                  break;
              }
            }
            if (i.isNotEmpty) {
              params[(groupFilter.type as String).split("/")[0]] = i.join(",");
            }
            if (e.isNotEmpty) {
              params[(groupFilter.type as String).split("/")[1]] = e.join(",");
            }
            if (i.isNotEmpty || e.isNotEmpty) {
              SelectFilterOption option = modeFilter.values[modeFilter.state];
              params[(modeFilter.type as String)] = option.value;
            }
            break;
          }
        case "hd":
          {
            GroupFilter filter = f;
            SelectFilter modeFilter = filter.state[0];
            GroupFilter checkboxesFilter = filter.state[1];
            List<CheckBoxFilter> state = checkboxesFilter.state
                .cast<CheckBoxFilter>();
            List<String> hd = [];
            for (var checkbox in state) {
              if (checkbox.state) {
                hd.add(checkbox.value);
              }
            }
            if (hd.isNotEmpty) {
              SelectFilterOption option = modeFilter.values[modeFilter.state];
              params[modeFilter.type as String] = option.value;
              params[filter.type as String] = hd.join(",");
            }
            break;
          }
        case "ss":
        case "sort":
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
      Uri.https(
        source.baseUrl!.replaceFirst("https://", ""),
        "/series-finder/",
        params,
      ),
      headers: getHeader(source.baseUrl!),
    );

    return _mangaListFromPage(res, source.id!);
  }

  @override
  Future<MManga> getDetail(String url) async {
    Response res = await client.get(
      Uri.parse(url),
      headers: getHeader(source.baseUrl!),
    );
    MDocument doc = parseHtml(res.body);
    String? imageUrl = doc.selectFirst(".wpb_wrapper img")?.getSrc;
    String? type = doc.selectFirst("#showtype")?.text?.trim();
    String description =
        "${doc.selectFirst("#editdescription")?.text?.trim()}\n\nType: $type";
    String? author = doc
        .select("#authtag")
        ?.map((el) => el.text?.trim())
        .join(", ");
    String? artist = doc
        .select("#artiststag")
        ?.map((el) => el.text?.trim())
        .join(", ");

    Status status = _toStatus(
      doc.selectFirst("#editstatus")?.text?.trim() ?? "",
    );
    List<String>? genre = doc
        .select("#seriesgenre > a")
        ?.map((el) => el.text?.trim() ?? "")
        .toList();

    String? novelId = doc.selectFirst("input#mypostid")?.attr("value");

    const link = "https://www.novelupdates.com/wp-admin/admin-ajax.php";
    Map<String, String> headers = {
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
      ...getHeader(source.baseUrl!),
    };

    List<MChapter> chapters = [];
    Response chapterRes = await client.post(
      Uri.parse(link),
      headers: headers,
      body: {"action": "nd_getchapters", "mygrr": "0", "mypostid": novelId},
    );
    MDocument chapterDoc = parseHtml(chapterRes.body);

    List<MElement>? chapterElements = chapterDoc.select("li.sp_li_chp");
    if (chapterElements == null) {
      throw "Please sign in via WebView.";
    }
    for (var el in chapterElements) {
      String?
      chapterName = el.selectFirst("span")?.attr("title")?.replaceAllMapped(
        RegExp(
          r"\b(?:v(\d+))?\s*?(?:c(\d+))?\s*?(?:(ex)(\d+)?)?\s*?(?:part(\d+))?\b",
        ),
            (m) {
          List<String> replace = [];
          if (m[1] != null) {
            replace.add("Volume ${m[1]}");
          }
          if (m[2] != null) {
            replace.add("Chapter ${m[2]}");
          }
          if (m[3] != null) {
            replace.add("Extra");
          }
          if (m[4] != null) {
            replace.add(m[4]!);
          }
          if (m[5] != null) {
            replace.add("Part ${m[5]}");
          }
          return replace.join(" ");
        },
      );
      String chapterUrl = "https:${el.select("a")?[1].getHref}";
      chapters.add(MChapter(name: chapterName, url: chapterUrl));
    }

    List<MElement> entries = doc.select("#myTable tbody tr")!;
    for (int i = 0; i < entries.length; i++) {
      List<MElement> tds = entries[i].select("td")!;
      chapters[i].dateUpload = parseDates(
        [tds[0].text!],
        "MM/dd/yy",
        "en_US",
      )[0];
      chapters[i].scanlator = tds[1].text!;
    }

    //chapters.reverse()

    return MManga(
      imageUrl: getPreferenceValue(source.id!, "use_web_archive_images")
          ? "https://web.archive.org/save/$imageUrl"
          : imageUrl,
      description: description,
      genre: genre,
      author: author,
      artist: artist,
      status: status,
      chapters: chapters,
    );
  }

  @override
  Future<String> getHtmlContent(String name, String url) async {
    String html = (await client.get(
      Uri.parse(url),
      headers: {"Priority": "u=0, i"},
    )).body;
    MDocument doc = parseHtml(html);
    String domain = html;

    if (domain.contains("anotivereads")) {
      String title = doc.selectFirst("#comic-nav-name")?.text?.trim() ?? "";
      String? content = doc.selectFirst("#spliced-comic")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("asuratls")) {
      String title =
          doc.selectFirst(".post-body > div > b")?.text?.trim() ?? "";
      String? content = doc
          .selectFirst(".post-body")
          ?.innerHtml
          ?.replaceFirst(title, "");
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("daoist")) {
      String title = doc.selectFirst(".chapter__title")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".chapter__content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("darkstartranslations")) {
      String title = doc.selectFirst("ol.breadcrumb > li")?.text?.trim() ?? "";
      String? content = doc
          .selectFirst(".text-left")
          ?.innerHtml
          ?.replaceFirst("<br>", "<br><br>");
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("fictionread")) {
      String title = doc.selectFirst(".title-image > span")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("helscans")) {
      String title = doc.selectFirst(".entry-title-main")?.text?.trim() ?? "";
      String? content = doc.selectFirst("#readerarea.rdminimal")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("hiraethtranslation")) {
      String title = doc.selectFirst("li.active")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".text-left")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("hostednovel")) {
      String title = doc.selectFirst("#chapter-title")?.text?.trim() ?? "";
      String? content = doc.selectFirst("#chapter-content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("inoveltranslation")) {
      String? content = doc.selectFirst(".styles_content__JHK8G")?.innerHtml;
      return " $content";
    }

    if (domain.contains("isotls")) {
      String title = doc.selectFirst("head > title")?.text?.trim() ?? "";
      String? content = doc.selectFirst("main > article")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("mirilu")) {
      String title =
          doc.selectFirst(".entry-content > p > strong")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".entry-content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("novelplex")) {
      String title = doc.selectFirst(".halChap--jud")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".halChap--kontenInner")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("novelworldtranslations")) {
      String title = doc.selectFirst(".entry-title")?.text?.trim() ?? "";
      String? content = doc
          .selectFirst(".entry-content")
          ?.innerHtml
          ?.replaceAll("&nbsp;", "")
          .replaceAll("\\n", "<br>");
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("readingpia")) {
      String? content = doc.selectFirst(".chapter-body")?.innerHtml;
      return " $content";
    }

    if (domain.contains("sacredtexttranslations")) {
      String title = doc.selectFirst(".entry-title")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".entry-content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("scribblehub")) {
      String title = doc.selectFirst(".chapter-title")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".chp_raw")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("tinytranslation")) {
      String title = doc.selectFirst(".title-content")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("tumblr")) {
      String? content = doc.selectFirst(".post")?.innerHtml;
      return " $content";
    }

    if (domain.contains("wattpad")) {
      String title = doc.selectFirst(".h2")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".part-content > pre")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("webnovel")) {
      String title =
          doc.selectFirst(".cha-tit > .pr > .dib")?.text?.trim() ?? "";
      String? content =
          doc.selectFirst(".cha-words")?.innerHtml ??
              doc.selectFirst("._content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("wetriedtls")) {
      String? content =
          doc.selectFirst("script:contains(\"p dir=\")")?.innerHtml ??
              doc.selectFirst("script:contains(\"u003c\")")?.innerHtml;
      if (content != null) {
        String jsonString_wetried = content.substring(
          content.indexOf(".push(") + ".push(".length,
          content.lastIndexOf(")"),
        );
        return " ${jsonDecode(jsonString_wetried)[1]}";
      }
      return " <p>Failed to parse JSON content!</p>";
    }

    if (domain.contains("wuxiaworld")) {
      String title = doc.selectFirst("h4 > span")?.text?.trim() ?? "";
      String? content = doc.selectFirst(".chapter-content")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("zetrotranslation")) {
      String title =
          doc.selectFirst(".text-left h2")?.text?.trim() ??
              doc.selectFirst(".active")?.text?.trim() ??
              "";
      String? content = doc.selectFirst(".text-left")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("webnoveltranslations")) {
      String title = doc.selectFirst("#chapter-heading")?.text?.trim() ?? "";

      String? content = doc
          .selectFirst("#novel-chapter-container.text-left")
          ?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("webnovel")) {
      String title =
          doc
              .selectFirst("#page > .chapter_content > .cha-tit > div > div")
              ?.text
              ?.trim() ??
              "";
      String? content = doc
          .selectFirst("#page > .chapter_content > .cha-content > .cha-words")
          ?.innerHtml
          ?.replaceAll(RegExp(r"<i\s*.*?>.*?<\/i>", multiLine: true), "");
      return " <h2>$title</h2><hr><br>$content";
    }

    if (domain.contains("re-library")) {
      String? redirectUrl = doc
          .selectFirst(".entry-content > div > div > p > a")
          ?.getHref;
      MDocument redirectDoc = parseHtml(
        (await client.get(
          Uri.parse(redirectUrl!),
          headers: {"Priority": "u=0, i"},
        )).body,
      );
      String title =
          redirectDoc
              .selectFirst(".entry-header > .entry-title")
              ?.text
              ?.trim() ??
              "";
      String? content = redirectDoc
          .selectFirst(".entry-content")
          ?.innerHtml
          ?.replaceAll(RegExp(r"<i\s*.*?>.*?<\/i>", multiLine: true), "");
      return " <h2>$title</h2><hr><br>$content";
    }

    List<String?> blogspotElements = [
      doc
          .selectFirst("meta[name=\"google-adsense-platform-domain\"]")
          ?.attr("content"),
      doc.selectFirst("meta[name=\"generator\"]")?.attr("content"),
    ];
    bool isBlogspot = blogspotElements.any(
          (e) =>
      (e?.toLowerCase().contains("blogspot") ?? false) ||
          (e?.toLowerCase().contains("blogger") ?? false),
    );

    if (isBlogspot) {
      String title =
          doc.selectFirst("h3.post-title")?.text?.trim() ??
              doc.selectFirst("h3.entry-title")?.text?.trim() ??
              "";
      String? content =
          doc.selectFirst("div.post-body")?.innerHtml ??
              doc.selectFirst("div.entry-content")?.innerHtml ??
              doc.selectFirst("div.content-post")?.innerHtml;
      return " <h2>$title</h2><hr><br>$content";
    }

    List<String?> wordpressElements = [
      doc.selectFirst("#dcl_comments-js-extra")?.innerHtml,
      doc.selectFirst("meta[name=\"generator\"]")?.attr("content"),
      doc.selectFirst(".powered-by")?.text,
      doc.selectFirst("footer")?.text,
    ];
    bool isWordpress = wordpressElements.any(
          (e) =>
      (e?.toLowerCase().contains("wordpress") ?? false) ||
          (e?.toLowerCase().contains("site kit by google") ?? false),
    );

    String title =
        doc.selectFirst(".entry-title")?.text?.trim() ??
            doc.selectFirst(".entry-title-main")?.text?.trim() ??
            doc.selectFirst(".chapter__title")?.text?.trim() ??
            doc.selectFirst(".sp-title")?.text?.trim() ??
            doc.selectFirst(".title-content")?.text?.trim() ??
            doc.selectFirst(".wp-block-post-title")?.text?.trim() ??
            doc.selectFirst(".title_story")?.text?.trim() ??
            doc.selectFirst(".active")?.text?.trim() ??
            doc.selectFirst("head title")?.text?.trim() ??
            doc.selectFirst("h1.leading-none ~ h2")?.text?.trim() ??
            "";
    String subtitle =
        doc.selectFirst(".cat-series")?.text?.trim() ??
            doc.selectFirst("h1.leading-none ~ span")?.text?.trim() ??
            "";
    if (subtitle != "") {
      title = subtitle;
    }
    String? content =
        doc.selectFirst(".rdminimal")?.innerHtml ??
            doc.selectFirst(".entry-content")?.innerHtml ??
            doc.selectFirst(".chapter__content")?.innerHtml ??
            doc.selectFirst(".prevent-select")?.innerHtml ??
            doc.selectFirst(".text_story")?.innerHtml ??
            doc.selectFirst(".contenta")?.innerHtml ??
            doc.selectFirst(".single_post")?.innerHtml ??
            doc.selectFirst(".post-entry")?.innerHtml ??
            doc.selectFirst(".main-content")?.innerHtml ??
            doc.selectFirst(".post-content")?.innerHtml ??
            doc.selectFirst(".content")?.innerHtml ??
            doc.selectFirst(".page-body")?.innerHtml ??
            doc.selectFirst(".td-page-content")?.innerHtml ??
            doc.selectFirst(".reader-content")?.innerHtml ??
            doc.selectFirst("#content")?.innerHtml ??
            doc.selectFirst("#the-content")?.innerHtml ??
            doc.selectFirst("article.post")?.innerHtml;

    if (isWordpress ||
        domain.contains("etherreads") ||
        domain.contains("soafp")) {
      return " <h2>$title</h2><hr><br>$content";
    }

    return " <p>Domain not supported yet. Content might not load properly!</p><h2>$title</h2><hr><br>$content";
  }

  @override
  Future<String> cleanHtmlContent(String html) async {
    if (html[0] == '"') {
      return jsonDecode(html);
    }
    return html;
  }

  @override
  List<dynamic> getFilterList() {
    return [
      GroupFilter("nt", "Novel Type", [
        CheckBoxFilter("Light Novel", "2443"),
        CheckBoxFilter("Published Novel", "26874"),
        CheckBoxFilter("Web Novel", "2444"),
      ]),
      GroupFilter("org", "Language", [
        CheckBoxFilter("Chinese", "495"),
        CheckBoxFilter("Filipino", "9181"),
        CheckBoxFilter("Indonesian", "9179"),
        CheckBoxFilter("Japanese", "496"),
        CheckBoxFilter("Khmer", "18657"),
        CheckBoxFilter("Korean", "497"),
        CheckBoxFilter("Malaysian", "9183"),
        CheckBoxFilter("Thai", "9954"),
        CheckBoxFilter("Vietnamese", "9177"),
      ]),
      GroupFilter("rl", "Chapters", [
        SelectFilter("mrl", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rl", "Chapters"),
      ]),
      GroupFilter("rf", "Release Frequency", [
        SelectFilter("mrf", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rf", "Release Frequency"),
      ]),
      GroupFilter("rvc", "Reviews", [
        SelectFilter("mrvc", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rvc", "Reviews"),
      ]),
      GroupFilter("rt", "Rating", [
        SelectFilter("mrt", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rt", "Rating"),
      ]),
      GroupFilter("rtc", "Number of Ratings", [
        SelectFilter("mrtc", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rtc", "Number of Ratings"),
      ]),
      GroupFilter("rct", "Readers", [
        SelectFilter("mrct", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("rct", "Readers"),
      ]),
      GroupFilter("dtf", "First Release Date", [
        SelectFilter("mdtf", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("dtf", "First Release Date (MM/DD/YYYY)"),
      ]),
      GroupFilter("dt", "Last Release Date", [
        SelectFilter("mdt", "Mode", 0, [
          SelectFilterOption("min", "min"),
          SelectFilterOption("max", "max"),
        ]),
        TextFilter("dt", "Last Release Date (MM/DD/YYYY)"),
      ]),
      GroupFilter("gi", "Genres", [
        SelectFilter("mgi", "Mode", 0, [
          SelectFilterOption("OR", "or"),
          SelectFilterOption("AND", "and"),
        ]),
        GroupFilter("gi/ge", "Genres", [
          TriStateFilter("Action", "8"),
          TriStateFilter("Adult", "280"),
          TriStateFilter("Adventure", "13"),
          TriStateFilter("Comedy", "17"),
          TriStateFilter("Drama", "9"),
          TriStateFilter("Ecchi", "292"),
          TriStateFilter("Fantasy", "5"),
          TriStateFilter("Gender Bender", "168"),
          TriStateFilter("Harem", "3"),
          TriStateFilter("Historical", "330"),
          TriStateFilter("Horror", "343"),
          TriStateFilter("Josei", "324"),
          TriStateFilter("Martial Arts", "14"),
          TriStateFilter("Mature", "4"),
          TriStateFilter("Mecha", "10"),
          TriStateFilter("Mystery", "245"),
          TriStateFilter("Psychological", "486"),
          TriStateFilter("Romance", "15"),
          TriStateFilter("School Life", "6"),
          TriStateFilter("Sci-fi", "11"),
          TriStateFilter("Seinen", "18"),
          TriStateFilter("Shoujo", "157"),
          TriStateFilter("Shoujo Ai", "851"),
          TriStateFilter("Shounen", "12"),
          TriStateFilter("Shounen Ai", "1692"),
          TriStateFilter("Slice of Life", "7"),
          TriStateFilter("Smut", "281"),
          TriStateFilter("Sports", "1357"),
          TriStateFilter("Supernatural", "16"),
          TriStateFilter("Tragedy", "132"),
          TriStateFilter("Wuxia", "479"),
          TriStateFilter("Xianxia", "480"),
          TriStateFilter("Xuanhuan", "3954"),
          TriStateFilter("Yaoi", "560"),
          TriStateFilter("Yuri", "922"),
        ]),
      ]),
      GroupFilter("Tags", "Tags", [
        SelectFilter("mtgi", "Mode", 0, [
          SelectFilterOption("OR", "or"),
          SelectFilterOption("AND", "and"),
        ]),
        GroupFilter("tgi/tge", "Tags", [
          TriStateFilter("16185", "Abandoned Children"),
          TriStateFilter("4859", "Ability Steal"),
          TriStateFilter("1248", "Absent Parents"),
          TriStateFilter("11325", "Abusive Characters"),
          TriStateFilter("4885", "Academy"),
          TriStateFilter("475", "Accelerated Growth"),
          TriStateFilter("13403", "Acting"),
          TriStateFilter("4976", "Adapted from Manga"),
          TriStateFilter("6280", "Adapted from Manhua"),
          TriStateFilter("269", "Adapted to Anime"),
          TriStateFilter("2999", "Adapted to Drama"),
          TriStateFilter("928", "Adapted to Drama CD"),
          TriStateFilter("891", "Adapted to Game"),
          TriStateFilter("270", "Adapted to Manga"),
          TriStateFilter("182", "Adapted to Manhua"),
          TriStateFilter("2721", "Adapted to Manhwa"),
          TriStateFilter("1133", "Adapted to Movie"),
          TriStateFilter("1334", "Adapted to Visual Novel"),
          TriStateFilter("858", "Adopted Children"),
          TriStateFilter("603", "Adopted Protagonist"),
          TriStateFilter("4974", "Adultery"),
          TriStateFilter("3108", "Adventurers"),
          TriStateFilter("3802", "Affair"),
          TriStateFilter("357", "Age Progression"),
          TriStateFilter("216", "Age Regression"),
          TriStateFilter("13720", "Aggressive Characters"),
          TriStateFilter("234", "Alchemy"),
          TriStateFilter("621", "Aliens"),
          TriStateFilter("598", "All-Girls School"),
          TriStateFilter("7909", "Alternate World"),
          TriStateFilter("625", "Amnesia"),
          TriStateFilter("774", "Amusement Park"),
          TriStateFilter("4594", "Anal"),
          TriStateFilter("476", "Ancient China"),
          TriStateFilter("2662", "Ancient Times"),
          TriStateFilter("13263", "Androgynous Characters"),
          TriStateFilter("892", "Androids"),
          TriStateFilter("1327", "Angels"),
          TriStateFilter("255", "Animal Characteristics"),
          TriStateFilter("7323", "Animal Rearing"),
          TriStateFilter("724", "Anti-Magic"),
          TriStateFilter("1732", "Anti-social Protagonist"),
          TriStateFilter("4297", "Antihero Protagonist"),
          TriStateFilter("203", "Antique Shop"),
          TriStateFilter("513", "Apartment Life"),
          TriStateFilter("12913", "Apathetic Protagonist"),
          TriStateFilter("217", "Apocalypse"),
          TriStateFilter("721", "Appearance Changes"),
          TriStateFilter("430", "Appearance Different from Actual Age"),
          TriStateFilter("697", "Archery"),
          TriStateFilter("6442", "Aristocracy"),
          TriStateFilter("9591", "Arms Dealers"),
          TriStateFilter("306", "Army"),
          TriStateFilter("9522", "Army Building"),
          TriStateFilter("2676", "Arranged Marriage"),
          TriStateFilter("13427", "Arrogant Characters"),
          TriStateFilter("9851", "Artifact Crafting"),
          TriStateFilter("4699", "Artifacts"),
          TriStateFilter("141", "Artificial Intelligence"),
          TriStateFilter("271", "Artists"),
          TriStateFilter("81", "Assassins"),
          TriStateFilter("8965", "Astrologers"),
          TriStateFilter("9776", "Autism"),
          TriStateFilter("11491", "Automatons"),
          TriStateFilter("12917", "Average-looking Protagonist"),
          TriStateFilter("1134", "Award-winning Work"),
          TriStateFilter("13016", "Awkward Protagonist"),
          TriStateFilter("4975", "Bands"),
          TriStateFilter("1346", "Based on a Movie"),
          TriStateFilter("1632", "Based on a Song"),
          TriStateFilter("6572", "Based on a TV Show"),
          TriStateFilter("1442", "Based on a Video Game"),
          TriStateFilter("1447", "Based on a Visual Novel"),
          TriStateFilter("1230", "Based on an Anime"),
          TriStateFilter("825", "Battle Academy"),
          TriStateFilter("6308", "Battle Competition"),
          TriStateFilter("10668", "BDSM"),
          TriStateFilter("5363", "Beast Companions"),
          TriStateFilter("5406", "Beastkin"),
          TriStateFilter("116", "Beasts"),
          TriStateFilter("111", "Beautiful Female Lead"),
          TriStateFilter("15625", "Bestiality"),
          TriStateFilter("256", "Betrayal"),
          TriStateFilter("2573", "Bickering Couple"),
          TriStateFilter("13371", "Biochip"),
          TriStateFilter("6359", "Bisexual Protagonist"),
          TriStateFilter("2943", "Black Belly"),
          TriStateFilter("916", "Blackmail"),
          TriStateFilter("2734", "Blacksmith"),
          TriStateFilter("9280", "Blind Dates"),
          TriStateFilter("2347", "Blind Protagonist"),
          TriStateFilter("9492", "Blood Manipulation"),
          TriStateFilter("5824", "Bloodlines"),
          TriStateFilter("2642", "Body Swap"),
          TriStateFilter("9907", "Body Tempering"),
          TriStateFilter("568", "Body-double"),
          TriStateFilter("224", "Bodyguards"),
          TriStateFilter("1288", "Books"),
          TriStateFilter("13805", "Bookworm"),
          TriStateFilter("325", "Boss-Subordinate Relationship"),
          TriStateFilter("1710", "Brainwashing"),
          TriStateFilter("5607", "Breast Fetish"),
          TriStateFilter("9410", "Broken Engagement"),
          TriStateFilter("604", "Brother Complex"),
          TriStateFilter("8185", "Brotherhood"),
          TriStateFilter("3825", "Buddhism"),
          TriStateFilter("123", "Bullying"),
          TriStateFilter("782", "Business Management"),
          TriStateFilter("11786", "Businessmen"),
          TriStateFilter("1597", "Butlers"),
          TriStateFilter("12910", "Calm Protagonist"),
          TriStateFilter("4248", "Cannibalism"),
          TriStateFilter("2774", "Card Games"),
          TriStateFilter("11345", "Carefree Protagonist"),
          TriStateFilter("12951", "Caring Protagonist"),
          TriStateFilter("12914", "Cautious Protagonist"),
          TriStateFilter("2304", "Celebrities"),
          TriStateFilter("257", "Character Growth"),
          TriStateFilter("14493", "Charismatic Protagonist"),
          TriStateFilter("14985", "Charming Protagonist"),
          TriStateFilter("1942", "Chat Rooms"),
          TriStateFilter("5708", "Cheats"),
          TriStateFilter("1832", "Chefs"),
          TriStateFilter("1368", "Child Abuse"),
          TriStateFilter("3470", "Child Protagonist"),
          TriStateFilter("1391", "Childcare"),
          TriStateFilter("85", "Childhood Friends"),
          TriStateFilter("917", "Childhood Love"),
          TriStateFilter("691", "Childhood Promise"),
          TriStateFilter("14986", "Childish Protagonist"),
          TriStateFilter("169", "Chuunibyou"),
          TriStateFilter("4423", "Clan Building"),
          TriStateFilter("7777", "Classic"),
          TriStateFilter("14587", "Clever Protagonist"),
          TriStateFilter("2356", "Clingy Lover"),
          TriStateFilter("2274", "Clones"),
          TriStateFilter("611", "Clubs"),
          TriStateFilter("14989", "Clumsy Love Interests"),
          TriStateFilter("7951", "Co-Workers"),
          TriStateFilter("710", "Cohabitation"),
          TriStateFilter("14606", "Cold Love Interests"),
          TriStateFilter("14605", "Cold Protagonist"),
          TriStateFilter("8656", "Collection of Short Stories"),
          TriStateFilter("7776", "College/University"),
          TriStateFilter("1675", "Coma"),
          TriStateFilter("124", "Comedic Undertone"),
          TriStateFilter("282", "Coming of Age"),
          TriStateFilter("4822", "Complex Family Relationships"),
          TriStateFilter("7117", "Conditional Power"),
          TriStateFilter("14673", "Confident Protagonist"),
          TriStateFilter("1404", "Confinement"),
          TriStateFilter("3241", "Conflicting Loyalties"),
          TriStateFilter("859", "Contracts"),
          TriStateFilter("2506", "Cooking"),
          TriStateFilter("352", "Corruption"),
          TriStateFilter("9926", "Cosmic Wars"),
          TriStateFilter("7844", "Cosplay"),
          TriStateFilter("592", "Couple Growth"),
          TriStateFilter("5792", "Court Official"),
          TriStateFilter("836", "Cousins"),
          TriStateFilter("3752", "Cowardly Protagonist"),
          TriStateFilter("5944", "Crafting"),
          TriStateFilter("2969", "Crime"),
          TriStateFilter("443", "Criminals"),
          TriStateFilter("769", "Cross-dressing"),
          TriStateFilter("1795", "Crossover"),
          TriStateFilter("12956", "Cruel Characters"),
          TriStateFilter("19556", "Cryostasis"),
          TriStateFilter("117", "Cultivation"),
          TriStateFilter("4596", "Cunnilingus"),
          TriStateFilter("14593", "Cunning Protagonist"),
          TriStateFilter("14990", "Curious Protagonist"),
          TriStateFilter("579", "Curses"),
          TriStateFilter("16457", "Cute Children"),
          TriStateFilter("14987", "Cute Protagonist"),
          TriStateFilter("5525", "Cute Story"),
          TriStateFilter("8248", "Dancers"),
          TriStateFilter("10343", "Dao Companion"),
          TriStateFilter("6242", "Dao Comprehension"),
          TriStateFilter("3824", "Daoism"),
          TriStateFilter("4599", "Dark"),
          TriStateFilter("2215", "Dead Protagonist"),
          TriStateFilter("2142", "Death"),
          TriStateFilter("1615", "Death of Loved Ones"),
          TriStateFilter("5333", "Debts"),
          TriStateFilter("749", "Delinquents"),
          TriStateFilter("1362", "Delusions"),
          TriStateFilter("5526", "Demi-Humans"),
          TriStateFilter("2386", "Demon Lord"),
          TriStateFilter("21268", "Demonic Cultivation Technique"),
          TriStateFilter("86", "Demons"),
          TriStateFilter("14541", "Dense Protagonist"),
          TriStateFilter("12964", "Depictions of Cruelty"),
          TriStateFilter("1946", "Depression"),
          TriStateFilter("3135", "Destiny"),
          TriStateFilter("1200", "Detectives"),
          TriStateFilter("12959", "Determined Protagonist"),
          TriStateFilter("15456", "Devoted Love Interests"),
          TriStateFilter("2243", "Different Social Status"),
          TriStateFilter("19241", "Disabilities"),
          TriStateFilter("258", "Discrimination"),
          TriStateFilter("13407", "Disfigurement"),
          TriStateFilter("2343", "Dishonest Protagonist"),
          TriStateFilter("7949", "Distrustful Protagonist"),
          TriStateFilter("2019", "Divination"),
          TriStateFilter("4706", "Divine Protection"),
          TriStateFilter("2305", "Divorce"),
          TriStateFilter("2876", "Doctors"),
          TriStateFilter("16412", "Dolls/Puppets"),
          TriStateFilter("2663", "Domestic Affairs"),
          TriStateFilter("15026", "Doting Love Interests"),
          TriStateFilter("15025", "Doting Older Siblings"),
          TriStateFilter("14674", "Doting Parents"),
          TriStateFilter("509", "Dragon Riders"),
          TriStateFilter("897", "Dragon Slayers"),
          TriStateFilter("72", "Dragons"),
          TriStateFilter("1406", "Dreams"),
          TriStateFilter("311", "Drugs"),
          TriStateFilter("8126", "Druids"),
          TriStateFilter("174", "Dungeon Master"),
          TriStateFilter("175", "Dungeons"),
          TriStateFilter("3569", "Dwarfs"),
          TriStateFilter("1283", "Dystopia"),
          TriStateFilter("15108", "e-Sports"),
          TriStateFilter("7711", "Early Romance"),
          TriStateFilter("1661", "Earth Invasion"),
          TriStateFilter("5431", "Easy Going Life"),
          TriStateFilter("784", "Economics"),
          TriStateFilter("1878", "Editors"),
          TriStateFilter("3796", "Eidetic Memory"),
          TriStateFilter("13177", "Elderly Protagonist"),
          TriStateFilter("9855", "Elemental Magic"),
          TriStateFilter("165", "Elves"),
          TriStateFilter("13305", "Emotionally Weak Protagonist"),
          TriStateFilter("3570", "Empires"),
          TriStateFilter("840", "Enemies Become Allies"),
          TriStateFilter("113", "Enemies Become Lovers"),
          TriStateFilter("263", "Engagement"),
          TriStateFilter("2735", "Engineer"),
          TriStateFilter("4480", "Enlightenment"),
          TriStateFilter("1798", "Episodic"),
          TriStateFilter("10593", "Eunuch"),
          TriStateFilter("7778", "European Ambience"),
          TriStateFilter("10172", "Evil Gods"),
          TriStateFilter("5411", "Evil Organizations"),
          TriStateFilter("12874", "Evil Protagonist"),
          TriStateFilter("7087", "Evil Religions"),
          TriStateFilter("2049", "Evolution"),
          TriStateFilter("6365", "Exhibitionism"),
          TriStateFilter("711", "Exorcism"),
          TriStateFilter("200", "Eye Powers"),
          TriStateFilter("525", "Fairies"),
          TriStateFilter("134", "Fallen Angels"),
          TriStateFilter("734", "Fallen Nobility"),
          TriStateFilter("12009", "Familial Love"),
          TriStateFilter("2152", "Familiars"),
          TriStateFilter("641", "Family"),
          TriStateFilter("2013", "Family Business"),
          TriStateFilter("8664", "Family Conflict"),
          TriStateFilter("1833", "Famous Parents"),
          TriStateFilter("14555", "Famous Protagonist"),
          TriStateFilter("5399", "Fanaticism"),
          TriStateFilter("5691", "Fanfiction"),
          TriStateFilter("771", "Fantasy Creatures"),
          TriStateFilter("99", "Fantasy World"),
          TriStateFilter("3068", "Farming"),
          TriStateFilter("5068", "Fast Cultivation"),
          TriStateFilter("7599", "Fast Learner"),
          TriStateFilter("13721", "Fat Protagonist"),
          TriStateFilter("15974", "Fat to Fit"),
          TriStateFilter("2574", "Fated Lovers"),
          TriStateFilter("14675", "Fearless Protagonist"),
          TriStateFilter("3953", "Fellatio"),
          TriStateFilter("5262", "Female Master"),
          TriStateFilter("2879", "Female Protagonist"),
          TriStateFilter("4178", "Female to Male"),
          TriStateFilter("10919", "Feng Shui"),
          TriStateFilter("9340", "Firearms"),
          TriStateFilter("1569", "First Love"),
          TriStateFilter("4880", "First-time Intercourse"),
          TriStateFilter("6061", "Flashbacks"),
          TriStateFilter("17020", "Fleet Battles"),
          TriStateFilter("923", "Folklore"),
          TriStateFilter("1353", "Forced into a Relationship"),
          TriStateFilter("606", "Forced Living Arrangements"),
          TriStateFilter("3052", "Forced Marriage"),
          TriStateFilter("2367", "Forgetful Protagonist"),
          TriStateFilter("7405", "Former Hero"),
          TriStateFilter("47861", "Found Family"),
          TriStateFilter("6222", "Fox Spirits"),
          TriStateFilter("1576", "Friends Become Enemies"),
          TriStateFilter("1476", "Friendship"),
          TriStateFilter("797", "Fujoshi"),
          TriStateFilter("3468", "Futanari"),
          TriStateFilter("2616", "Futuristic Setting"),
          TriStateFilter("7643", "Galge"),
          TriStateFilter("9425", "Gambling"),
          TriStateFilter("93", "Game Elements"),
          TriStateFilter("16272", "Game Ranking System"),
          TriStateFilter("225", "Gamers"),
          TriStateFilter("313", "Gangs"),
          TriStateFilter("5382", "Gate to Another World"),
          TriStateFilter("9295", "Genderless Protagonist"),
          TriStateFilter("13888", "Generals"),
          TriStateFilter("17629", "Genetic Modifications"),
          TriStateFilter("2014", "Genies"),
          TriStateFilter("14581", "Genius Protagonist"),
          TriStateFilter("515", "Ghosts"),
          TriStateFilter("2044", "Gladiators"),
          TriStateFilter("15547", "Glasses-wearing Love Interests"),
          TriStateFilter("15548", "Glasses-wearing Protagonist"),
          TriStateFilter("11494", "Goblins"),
          TriStateFilter("6683", "God Protagonist"),
          TriStateFilter("1354", "God-human Relationship"),
          TriStateFilter("1355", "Goddesses"),
          TriStateFilter("73", "Godly Powers"),
          TriStateFilter("177", "Gods"),
          TriStateFilter("4437", "Golems"),
          TriStateFilter("455", "Gore"),
          TriStateFilter("1736", "Grave Keepers"),
          TriStateFilter("807", "Grinding"),
          TriStateFilter("2005", "Guardian Relationship"),
          TriStateFilter("47165", "Guideverse"),
          TriStateFilter("438", "Guilds"),
          TriStateFilter("792", "Gunfighters"),
          TriStateFilter("1753", "Hackers"),
          TriStateFilter("9445", "Half-human Protagonist"),
          TriStateFilter("9873", "Handjob"),
          TriStateFilter("192", "Handsome Male Lead"),
          TriStateFilter("14431", "Hard-Working Protagonist"),
          TriStateFilter("14992", "Harem-seeking Protagonist"),
          TriStateFilter("8149", "Harsh Training"),
          TriStateFilter("2307", "Hated Protagonist"),
          TriStateFilter("12141", "Healers"),
          TriStateFilter("5267", "Heartwarming"),
          TriStateFilter("242", "Heaven"),
          TriStateFilter("4770", "Heavenly Tribulation"),
          TriStateFilter("4720", "Hell"),
          TriStateFilter("15545", "Helpful Protagonist"),
          TriStateFilter("808", "Herbalist"),
          TriStateFilter("100", "Heroes"),
          TriStateFilter("2111", "Heterochromia"),
          TriStateFilter("7227", "Hidden Abilities"),
          TriStateFilter("6384", "Hiding True Abilities"),
          TriStateFilter("10134", "Hiding True Identity"),
          TriStateFilter("765", "Hikikomori"),
          TriStateFilter("2741", "Homunculus"),
          TriStateFilter("1772", "Honest Protagonist"),
          TriStateFilter("1387", "Hospital"),
          TriStateFilter("13502", "Hot-blooded Protagonist"),
          TriStateFilter("12338", "Human Experimentation"),
          TriStateFilter("1687", "Human Weapon"),
          TriStateFilter("259", "Human-Nonhuman Relationship"),
          TriStateFilter("17218", "Humanoid Protagonist"),
          TriStateFilter("494", "Hunters"),
          TriStateFilter("1711", "Hypnotism"),
          TriStateFilter("10075", "Identity Crisis"),
          TriStateFilter("3555", "Imaginary Friend"),
          TriStateFilter("233", "Immortals"),
          TriStateFilter("9033", "Imperial Harem"),
          TriStateFilter("626", "Incest"),
          TriStateFilter("3398", "Incubus"),
          TriStateFilter("2319", "Indecisive Protagonist"),
          TriStateFilter("12135", "Industrialization"),
          TriStateFilter("506", "Inferiority Complex"),
          TriStateFilter("1400", "Inheritance"),
          TriStateFilter("5132", "Inscriptions"),
          TriStateFilter("550", "Insects"),
          TriStateFilter("4539", "Interconnected Storylines"),
          TriStateFilter("11229", "Interdimensional Travel"),
          TriStateFilter("14993", "Introverted Protagonist"),
          TriStateFilter("9064", "Investigations"),
          TriStateFilter("3978", "Invisibility"),
          TriStateFilter("3687", "Jack of All Trades"),
          TriStateFilter("1864", "Jealousy"),
          TriStateFilter("6665", "Jiangshi"),
          TriStateFilter("7086", "Jobless Class"),
          TriStateFilter("5300", "JSDF"),
          TriStateFilter("1250", "Kidnappings"),
          TriStateFilter("13901", "Kind Love Interests"),
          TriStateFilter("3869", "Kingdom Building"),
          TriStateFilter("1904", "Kingdoms"),
          TriStateFilter("137", "Knights"),
          TriStateFilter("571", "Kuudere"),
          TriStateFilter("5086", "Lack of Common Sense"),
          TriStateFilter("5426", "Language Barrier"),
          TriStateFilter("5920", "Late Romance"),
          TriStateFilter("4551", "Lawyers"),
          TriStateFilter("338", "Lazy Protagonist"),
          TriStateFilter("6706", "Leadership"),
          TriStateFilter("3430", "Legends"),
          TriStateFilter("7443", "Level System"),
          TriStateFilter("1402", "Library"),
          TriStateFilter("84407", "Life Extension System"),
          TriStateFilter("2222", "Limited Lifespan"),
          TriStateFilter("49529", "Livestreaming"),
          TriStateFilter("3154", "Living Abroad"),
          TriStateFilter("1437", "Living Alone"),
          TriStateFilter("3715", "Loli"),
          TriStateFilter("865", "Loneliness"),
          TriStateFilter("651", "Loner Protagonist"),
          TriStateFilter("2891", "Long Separations"),
          TriStateFilter("1859", "Long-distance Relationship"),
          TriStateFilter("1696", "Lost Civilizations"),
          TriStateFilter("7151", "Lottery"),
          TriStateFilter("1561", "Love at First Sight"),
          TriStateFilter("19605", "Love Interest Falls in Love First"),
          TriStateFilter("627", "Love Rivals"),
          TriStateFilter("607", "Love Triangles"),
          TriStateFilter("1616", "Lovers Reunited"),
          TriStateFilter("9161", "Low-key Protagonist"),
          TriStateFilter("12035", "Loyal Subordinates"),
          TriStateFilter("6526", "Lucky Protagonist"),
          TriStateFilter("60", "Magic"),
          TriStateFilter("6095", "Magic Beasts"),
          TriStateFilter("3038", "Magic Formations"),
          TriStateFilter("516", "Magical Girls"),
          TriStateFilter("3460", "Magical Space"),
          TriStateFilter("14900", "Magical Technology"),
          TriStateFilter("336", "Maids"),
          TriStateFilter("3257", "Male Protagonist"),
          TriStateFilter("171", "Male to Female"),
          TriStateFilter("557", "Male Yandere"),
          TriStateFilter("2604", "Management"),
          TriStateFilter("2781", "Mangaka"),
          TriStateFilter("12963", "Manipulative Characters"),
          TriStateFilter("2084", "Manly Gay Couple"),
          TriStateFilter("642", "Marriage"),
          TriStateFilter("706", "Marriage of Convenience"),
          TriStateFilter("10145", "Martial Spirits"),
          TriStateFilter("19604", "Masochistic Characters"),
          TriStateFilter("667", "Master-Disciple Relationship"),
          TriStateFilter("260", "Master-Servant Relationship"),
          TriStateFilter("2501", "Masturbation"),
          TriStateFilter("6437", "Matriarchy"),
          TriStateFilter("279", "Mature Protagonist"),
          TriStateFilter("9021", "Medical Knowledge"),
          TriStateFilter("4498", "Medieval"),
          TriStateFilter("9573", "Mercenaries"),
          TriStateFilter("14516", "Merchants"),
          TriStateFilter("589", "Military"),
          TriStateFilter("6073", "Mind Break"),
          TriStateFilter("456", "Mind Control"),
          TriStateFilter("11503", "Misandry"),
          TriStateFilter("1516", "Mismatched Couple"),
          TriStateFilter("50416", "Mistaken Identity"),
          TriStateFilter("172", "Misunderstandings"),
          TriStateFilter("105", "MMORPG"),
          TriStateFilter("12487", "Mob Protagonist"),
          TriStateFilter("14781", "Models"),
          TriStateFilter("2606", "Modern Day"),
          TriStateFilter("2666", "Modern Knowledge"),
          TriStateFilter("3754", "Money Grubber"),
          TriStateFilter("510", "Monster Girls"),
          TriStateFilter("8988", "Monster Society"),
          TriStateFilter("253", "Monster Tamer"),
          TriStateFilter("261", "Monsters"),
          TriStateFilter("345", "Movies"),
          TriStateFilter("20139", "Mpreg"),
          TriStateFilter("7163", "Multiple Identities"),
          TriStateFilter("8266", "Multiple Personalities"),
          TriStateFilter("14639", "Multiple POV"),
          TriStateFilter("441", "Multiple Protagonists"),
          TriStateFilter("3706", "Multiple Realms"),
          TriStateFilter("5149", "Multiple Reincarnated Individuals"),
          TriStateFilter("7802", "Multiple Timelines"),
          TriStateFilter("16138", "Multiple Transported Individuals"),
          TriStateFilter("885", "Murders"),
          TriStateFilter("1231", "Music"),
          TriStateFilter("5036", "Mutated Creatures"),
          TriStateFilter("68", "Mutations"),
          TriStateFilter("1141", "Mute Character"),
          TriStateFilter("8440", "Mysterious Family Background"),
          TriStateFilter("2224", "Mysterious Illness"),
          TriStateFilter("4783", "Mysterious Past"),
          TriStateFilter("3537", "Mystery Solving"),
          TriStateFilter("8995", "Mythical Beasts"),
          TriStateFilter("1474", "Mythology"),
          TriStateFilter("14644", "Naive Protagonist"),
          TriStateFilter("14994", "Narcissistic Protagonist"),
          TriStateFilter("6204", "Nationalism"),
          TriStateFilter("130", "Near-Death Experience"),
          TriStateFilter("186", "Necromancer"),
          TriStateFilter("1728", "Neet"),
          TriStateFilter("4126", "Netorare"),
          TriStateFilter("11561", "Netorase"),
          TriStateFilter("3862", "Netori"),
          TriStateFilter("6164", "Nightmares"),
          TriStateFilter("1725", "Ninjas"),
          TriStateFilter("265", "Nobles"),
          TriStateFilter("17199", "Non-humanoid Protagonist"),
          TriStateFilter("2514", "Non-linear Storytelling"),
          TriStateFilter("1524", "Nudity"),
          TriStateFilter("7551", "Nurses"),
          TriStateFilter("1477", "Obsessive Love"),
          TriStateFilter("9331", "Office Romance"),
          TriStateFilter("16202", "Older Love Interests"),
          TriStateFilter("14574", "Omegaverse"),
          TriStateFilter("10980", "Oneshot"),
          TriStateFilter("5122", "Online Romance"),
          TriStateFilter("2060", "Onmyouji"),
          TriStateFilter("6211", "Orcs"),
          TriStateFilter("2645", "Organized Crime"),
          TriStateFilter("11994", "Orgy"),
          TriStateFilter("125", "Orphans"),
          TriStateFilter("277", "Otaku"),
          TriStateFilter("466", "Otome Game"),
          TriStateFilter("726", "Outcasts"),
          TriStateFilter("1222", "Outdoor Intercourse"),
          TriStateFilter("875", "Outer Space"),
          TriStateFilter("4598", "Overpowered Protagonist"),
          TriStateFilter("145", "Overprotective Siblings"),
          TriStateFilter("8832", "Pacifist Protagonist"),
          TriStateFilter("6049", "Paizuri"),
          TriStateFilter("318", "Parallel Worlds"),
          TriStateFilter("1300", "Parasites"),
          TriStateFilter("4741", "Parent Complex"),
          TriStateFilter("2350", "Parody"),
          TriStateFilter("628", "Part-Time Job"),
          TriStateFilter("220", "Past Plays a Big Role"),
          TriStateFilter("6457", "Past Trauma"),
          TriStateFilter("15546", "Persistent Love Interests"),
          TriStateFilter("488", "Personality Changes"),
          TriStateFilter("14643", "Perverted Protagonist"),
          TriStateFilter("2710", "Pets"),
          TriStateFilter("5623", "Pharmacist"),
          TriStateFilter("1799", "Philosophical"),
          TriStateFilter("1817", "Phobias"),
          TriStateFilter("8790", "Phoenixes"),
          TriStateFilter("1371", "Photography"),
          TriStateFilter("3019", "Pill Based Cultivation"),
          TriStateFilter("9071", "Pill Concocting"),
          TriStateFilter("1215", "Pilots"),
          TriStateFilter("3025", "Pirates"),
          TriStateFilter("1311", "Playboys"),
          TriStateFilter("13369", "Playful Protagonist"),
          TriStateFilter("7813", "Poetry"),
          TriStateFilter("2674", "Poisons"),
          TriStateFilter("83", "Police"),
          TriStateFilter("14996", "Polite Protagonist"),
          TriStateFilter("298", "Politics"),
          TriStateFilter("11890", "Polyandry"),
          TriStateFilter("2684", "Polygamy"),
          TriStateFilter("12909", "Poor Protagonist"),
          TriStateFilter("8801", "Poor to Rich"),
          TriStateFilter("13481", "Popular Love Interests"),
          TriStateFilter("94", "Possession"),
          TriStateFilter("12966", "Possessive Characters"),
          TriStateFilter("1301", "Post-apocalyptic"),
          TriStateFilter("2551", "Power Couple"),
          TriStateFilter("673", "Power Struggle"),
          TriStateFilter("564", "Pragmatic Protagonist"),
          TriStateFilter("2020", "Precognition"),
          TriStateFilter("3330", "Pregnancy"),
          TriStateFilter("1763", "Pretend Lovers"),
          TriStateFilter("1124", "Previous Life Talent"),
          TriStateFilter("3534", "Priestesses"),
          TriStateFilter("2341", "Priests"),
          TriStateFilter("1426", "Prison"),
          TriStateFilter("701", "Proactive Protagonist"),
          TriStateFilter("6302", "Programmer"),
          TriStateFilter("13215", "Prophecies"),
          TriStateFilter("1892", "Prostitutes"),
          TriStateFilter("19606", "Protagonist Falls in Love First"),
          TriStateFilter("167", "Protagonist Strong from the Start"),
          TriStateFilter("18652", "Protagonist with Multiple Bodies"),
          TriStateFilter("13480", "Psychic Powers"),
          TriStateFilter("846", "Psychopaths"),
          TriStateFilter("9950", "Puppeteers"),
          TriStateFilter("13370", "Quiet Characters"),
          TriStateFilter("931", "Quirky Characters"),
          TriStateFilter("2738", "R-15"),
          TriStateFilter("4074", "R-18"),
          TriStateFilter("2903", "Race Change"),
          TriStateFilter("3314", "Racism"),
          TriStateFilter("431", "Rape"),
          TriStateFilter("11714", "Rape Victim Becomes Lover"),
          TriStateFilter("5574", "Rebellion"),
          TriStateFilter("447", "Reincarnated as a Monster"),
          TriStateFilter("9480", "Reincarnated as an Object"),
          TriStateFilter("7297", "Reincarnated in a Game World"),
          TriStateFilter("6304", "Reincarnated in Another World"),
          TriStateFilter("120", "Reincarnation"),
          TriStateFilter("15178", "Religions"),
          TriStateFilter("179", "Reluctant Protagonist"),
          TriStateFilter("1684", "Reporters"),
          TriStateFilter("1835", "Restaurant"),
          TriStateFilter("1209", "Resurrection"),
          TriStateFilter("13303", "Returning from Another World"),
          TriStateFilter("121", "Revenge"),
          TriStateFilter("558", "Reverse Harem"),
          TriStateFilter("4500", "Reverse Rape"),
          TriStateFilter("28883", "Reversible Couple"),
          TriStateFilter("11448", "Rich to Poor"),
          TriStateFilter("7780", "Righteous Protagonist"),
          TriStateFilter("614", "Rivalry"),
          TriStateFilter("334", "Romantic Subplot"),
          TriStateFilter("106", "Roommates"),
          TriStateFilter("335", "Royalty"),
          TriStateFilter("12916", "Ruthless Protagonist"),
          TriStateFilter("13496", "Sadistic Characters"),
          TriStateFilter("7288", "Saints"),
          TriStateFilter("1189", "Salaryman"),
          TriStateFilter("826", "Samurai"),
          TriStateFilter("788", "Saving the World"),
          TriStateFilter("24959", "Schemes And Conspiracies"),
          TriStateFilter("2288", "Schizophrenia"),
          TriStateFilter("843", "Scientists"),
          TriStateFilter("426", "Sculptors"),
          TriStateFilter("732", "Sealed Power"),
          TriStateFilter("2571", "Second Chance"),
          TriStateFilter("1475", "Secret Crush"),
          TriStateFilter("214", "Secret Identity"),
          TriStateFilter("827", "Secret Organizations"),
          TriStateFilter("1190", "Secret Relationship"),
          TriStateFilter("14997", "Secretive Protagonist"),
          TriStateFilter("1623", "Secrets"),
          TriStateFilter("7536", "Sect Development"),
          TriStateFilter("2595", "Seduction"),
          TriStateFilter("201", "Seeing Things Other Humans Can't"),
          TriStateFilter("1463", "Selfish Protagonist"),
          TriStateFilter("1372", "Selfless Protagonist"),
          TriStateFilter("14319", "Seme Protagonist"),
          TriStateFilter("629", "Senpai-Kouhai Relationship"),
          TriStateFilter("13520", "Sentient Objects"),
          TriStateFilter("13498", "Sentimental Protagonist"),
          TriStateFilter("1328", "Serial Killers"),
          TriStateFilter("254", "Servants"),
          TriStateFilter("3863", "Seven Deadly Sins"),
          TriStateFilter("13993", "Seven Virtues"),
          TriStateFilter("4432", "Sex Friends"),
          TriStateFilter("656", "Sex Slaves"),
          TriStateFilter("3252", "Sexual Abuse"),
          TriStateFilter("6245", "Sexual Cultivation Technique"),
          TriStateFilter("13802", "Shameless Protagonist"),
          TriStateFilter("10602", "Shapeshifters"),
          TriStateFilter("7874", "Sharing A Body"),
          TriStateFilter("13996", "Sharp-tongued Characters"),
          TriStateFilter("17746", "Shield User"),
          TriStateFilter("2280", "Shikigami"),
          TriStateFilter("3358", "Short Story"),
          TriStateFilter("5580", "Shota"),
          TriStateFilter("7147", "Shoujo-Ai Subplot"),
          TriStateFilter("7146", "Shounen-Ai Subplot"),
          TriStateFilter("565", "Showbiz"),
          TriStateFilter("13499", "Shy Characters"),
          TriStateFilter("1971", "Sibling Rivalry"),
          TriStateFilter("8186", "Sibling's Care"),
          TriStateFilter("1411", "Siblings"),
          TriStateFilter("65", "Siblings Not Related by Blood"),
          TriStateFilter("13199", "Sickly Characters"),
          TriStateFilter("8631", "Sign Language"),
          TriStateFilter("209", "Singers"),
          TriStateFilter("1985", "Single Parent"),
          TriStateFilter("668", "Sister Complex"),
          TriStateFilter("3820", "Skill Assimilation"),
          TriStateFilter("7032", "Skill Books"),
          TriStateFilter("6753", "Skill Creation"),
          TriStateFilter("3936", "Slave Harem"),
          TriStateFilter("5420", "Slave Protagonist"),
          TriStateFilter("180", "Slaves"),
          TriStateFilter("3014", "Sleeping"),
          TriStateFilter("3185", "Slow Growth at Start"),
          TriStateFilter("76", "Slow Romance"),
          TriStateFilter("831", "Smart Couple"),
          TriStateFilter("652", "Social Outcasts"),
          TriStateFilter("674", "Soldiers"),
          TriStateFilter("7828", "Soul Power"),
          TriStateFilter("4627", "Souls"),
          TriStateFilter("8777", "Spatial Manipulation"),
          TriStateFilter("4842", "Spear Wielder"),
          TriStateFilter("323", "Special Abilities"),
          TriStateFilter("2069", "Spies"),
          TriStateFilter("2586", "Spirit Advisor"),
          TriStateFilter("11422", "Spirit Users"),
          TriStateFilter("202", "Spirits"),
          TriStateFilter("1713", "Stalkers"),
          TriStateFilter("1373", "Stockholm Syndrome"),
          TriStateFilter("13500", "Stoic Characters"),
          TriStateFilter("13633", "Store Owner"),
          TriStateFilter("1191", "Straight Seme"),
          TriStateFilter("1594", "Straight Uke"),
          TriStateFilter("675", "Strategic Battles"),
          TriStateFilter("4777", "Strategist"),
          TriStateFilter("14788", "Strength-based Social Hierarchy"),
          TriStateFilter("12881", "Strong Love Interests"),
          TriStateFilter("4971", "Strong to Stronger"),
          TriStateFilter("1643", "Stubborn Protagonist"),
          TriStateFilter("608", "Student Council"),
          TriStateFilter("1224", "Student-Teacher Relationship"),
          TriStateFilter("645", "Succubus"),
          TriStateFilter("898", "Sudden Strength Gain"),
          TriStateFilter("9574", "Sudden Wealth"),
          TriStateFilter("1743", "Suicides"),
          TriStateFilter("2990", "Summoned Hero"),
          TriStateFilter("4127", "Summoning Magic"),
          TriStateFilter("347", "Survival"),
          TriStateFilter("348", "Survival Game"),
          TriStateFilter("4302", "Sword And Magic"),
          TriStateFilter("18792", "Sword Wielder"),
          TriStateFilter("7357", "System Administrator"),
          TriStateFilter("1749", "Teachers"),
          TriStateFilter("1847", "Teamwork"),
          TriStateFilter("16962", "Technological Gap"),
          TriStateFilter("8760", "Tentacles"),
          TriStateFilter("2225", "Terminal Illness"),
          TriStateFilter("2196", "Terrorists"),
          TriStateFilter("1360", "Thieves"),
          TriStateFilter("1420", "Threesome"),
          TriStateFilter("2970", "Thriller"),
          TriStateFilter("886", "Time Loop"),
          TriStateFilter("2054", "Time Manipulation"),
          TriStateFilter("887", "Time Paradox"),
          TriStateFilter("360", "Time Skip"),
          TriStateFilter("92", "Time Travel"),
          TriStateFilter("5085", "Timid Protagonist"),
          TriStateFilter("267", "Tomboyish Female Lead"),
          TriStateFilter("355", "Torture"),
          TriStateFilter("14264", "Toys"),
          TriStateFilter("148", "Tragic Past"),
          TriStateFilter("16178", "Transformation Ability"),
          TriStateFilter("3046", "Transmigration"),
          TriStateFilter("4323", "Transplanted Memories"),
          TriStateFilter("7663", "Transported into a Game World"),
          TriStateFilter("6559", "Transported Modern Structure"),
          TriStateFilter("15008", "Transported to Another World"),
          TriStateFilter("1279", "Trap"),
          TriStateFilter("5825", "Tribal Society"),
          TriStateFilter("4856", "Trickster"),
          TriStateFilter("795", "Tsundere"),
          TriStateFilter("518", "Twins"),
          TriStateFilter("10488", "Twisted Personality"),
          TriStateFilter("12155", "Ugly Protagonist"),
          TriStateFilter("4851", "Ugly to Beautiful"),
          TriStateFilter("1595", "Unconditional Love"),
          TriStateFilter("12907", "Underestimated Protagonist"),
          TriStateFilter("3718", "Unique Cultivation Technique"),
          TriStateFilter("13875", "Unique Weapon User"),
          TriStateFilter("13874", "Unique Weapons"),
          TriStateFilter("38534", "Unlimited Flow"),
          TriStateFilter("2314", "Unlucky Protagonist"),
          TriStateFilter("4697", "Unreliable Narrator"),
          TriStateFilter("1268", "Unrequited Love"),
          TriStateFilter("17588", "Valkyries"),
          TriStateFilter("149", "Vampires"),
          TriStateFilter("11404", "Villainess Noble Girls"),
          TriStateFilter("109", "Virtual Reality"),
          TriStateFilter("1634", "Vocaloid"),
          TriStateFilter("2887", "Voice Actors"),
          TriStateFilter("3256", "Voyeurism"),
          TriStateFilter("1216", "Waiters"),
          TriStateFilter("5128", "War Records"),
          TriStateFilter("101", "Wars"),
          TriStateFilter("12813", "Weak Protagonist"),
          TriStateFilter("71", "Weak to Strong"),
          TriStateFilter("13334", "Wealthy Characters"),
          TriStateFilter("17533", "Werebeasts"),
          TriStateFilter("1338", "Wishes"),
          TriStateFilter("1829", "Witches"),
          TriStateFilter("634", "Wizards"),
          TriStateFilter("21767", "World Hopping"),
          TriStateFilter("364", "World Travel"),
          TriStateFilter("13198", "World Tree"),
          TriStateFilter("548", "Writers"),
          TriStateFilter("291", "Yandere"),
          TriStateFilter("926", "Youkai"),
          TriStateFilter("11677", "Younger Brothers"),
          TriStateFilter("16201", "Younger Love Interests"),
          TriStateFilter("11678", "Younger Sisters"),
          TriStateFilter("350", "Zombies"),
        ]),
      ]),
      GroupFilter("hd", "Reading Lists", [
        SelectFilter("mRLi", "Mode", 0, [
          SelectFilterOption("Exclude", "exclude"),
          SelectFilterOption("Include", "Include"),
        ]),
        GroupFilter("hd", "Reading Lists", [
          CheckBoxFilter("All Reading Lists", "-1"),
          CheckBoxFilter("Reading", "0"),
        ]),
      ]),
      SelectFilter("ss", "Story Status (Translation)", 0, [
        SelectFilterOption("All", ""),
        SelectFilterOption("Completed", "2"),
        SelectFilterOption("Ongoing", "3"),
        SelectFilterOption("Hiatus", "4"),
      ]),
      SelectFilter("sort", "Sort By", 0, [
        SelectFilterOption("srel", "Chapters"),
        SelectFilterOption("sfrel", "Frequency"),
        SelectFilterOption("srank", "Rank"),
        SelectFilterOption("srate", "Rating"),
        SelectFilterOption("sread", "Readers"),
        SelectFilterOption("sreview", "Reviews"),
        SelectFilterOption("abc", "Title"),
        SelectFilterOption("sdate", "Last Updated"),
      ]),
      SelectFilter("order", "Order", 0, [
        SelectFilterOption("Ascending", "asc"),
        SelectFilterOption("Descending", "desc"),
      ]),
    ];
  }

  @override
  List<dynamic> getSourcePreferences() {
    return [
      CheckBoxPreference(
        key: "use_web_archive_images",
        title: "Use web.archive.org for images",
        summary: "",
        value: false,
      ),
    ];
  }
}

Map<String, String> getHeader(String url) {
  final headers = {
    "Referer": "$url/",
    "Origin": url,
    "Connection": "keep-alive",
    "Accept": "*/*",
    "Accept-Language": "*",
    "Sec-Fetch-Mode": "cors",
    "Accept-Encoding": "gzip, deflate",
  };
  return headers;
}

// ignore: main_first_positional_parameter_type
NovelUpdates main(MSource source) {
  return NovelUpdates(source: source);
}

// }
