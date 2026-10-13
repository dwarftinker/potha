// Search online (003 US6, research R9): Wikimedia's definition API, parsed to entries.
// Recorded responses in test/fixtures/dictionary/wikimedia_*.json.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/core/dictionary/online_dictionary.dart';

String fixture(String name) => File('test/fixtures/dictionary/$name').readAsStringSync();

void main() {
  late List<http.Request> requests;

  WikimediaDictionary client(http.Response Function(http.Request) respond) {
    requests = [];
    return WikimediaDictionary(
      client: MockClient((r) async {
        requests.add(r);
        return respond(r);
      }),
    );
  }

  test('the English section maps to entries, HTML stripped, link text kept', () async {
    final online = client(
      (_) => http.Response.bytes(utf8.encode(fixture('wikimedia_serendipity.json')), 200),
    );
    final result = await online.lookUp('serendipity') as OnlineFound;
    final e = result.entries.single;
    expect(e.headword, 'serendipity');
    expect(e.pos, 'noun');
    expect(
      e.senses.first.gloss,
      startsWith('The phenomenon of making an unplanned, fortunate discovery'),
    );
    expect(e.senses.every((s) => !s.gloss.contains('<')), isTrue);
  });

  test('other languages are ignored; entities are decoded; empty definitions dropped', () async {
    final body = jsonEncode({
      'fr': [
        {
          'partOfSpeech': 'Noun',
          'language': 'French',
          'definitions': [
            {'definition': 'non'},
          ],
        },
      ],
      'en': [
        {
          'partOfSpeech': 'Verb',
          'language': 'English',
          'definitions': [
            {'definition': ''},
            {
              'definition': 'To <b>run</b> &amp; jump',
              'examples': ['He ran &quot;fast&quot;.'],
            },
          ],
        },
      ],
    });
    final online = client((_) => http.Response(body, 200));
    final e = (await online.lookUp('run') as OnlineFound).entries.single;
    expect(e.pos, 'verb');
    expect(e.senses.single.gloss, 'To run & jump');
    expect(e.senses.single.examples, ['He ran "fast".']);
  });

  test('404 is not found', () async {
    final online = client((_) => http.Response(fixture('wikimedia_404.json'), 404));
    expect(await online.lookUp('zorblaxquim'), isA<OnlineNotFound>());
  });

  test('a response with no English section is not found', () async {
    final online = client((_) => http.Response(jsonEncode({'fr': []}), 200));
    expect(await online.lookUp('chat'), isA<OnlineNotFound>());
  });

  test('a server error or a network error fails', () async {
    expect(await client((_) => http.Response('oops', 500)).lookUp('x'), isA<OnlineFailed>());
    final broken = WikimediaDictionary(
      client: MockClient((_) async => throw const SocketException('no route')),
    );
    expect(await broken.lookUp('x'), isA<OnlineFailed>());
  });

  test('a request that takes too long fails; the limit is 8 s', () async {
    expect(WikimediaDictionary().timeout, const Duration(seconds: 8));
    final never = Completer<http.Response>();
    final online = WikimediaDictionary(
      client: MockClient((_) => never.future),
      timeout: const Duration(milliseconds: 50),
    );
    expect(await online.lookUp('slow'), isA<OnlineFailed>());
  });

  test('the word is encoded in the URL; only the app is named in the header', () async {
    final online = client((_) => http.Response(jsonEncode({}), 200));
    await online.lookUp('give up?');
    final r = requests.single;
    expect(r.url.toString(), 'https://en.wiktionary.org/api/rest_v1/page/definition/give_up%3F');
    expect(r.method, 'GET');
    final agent = r.headers['Api-User-Agent']!;
    expect(agent, startsWith('Potha/'));
    expect(agent, contains('https://github.com/dwarftinker/potha'));
    expect(agent, isNot(contains('@')));
    expect(r.headers.keys.map((k) => k.toLowerCase()), isNot(contains('cookie')));
  });
}
