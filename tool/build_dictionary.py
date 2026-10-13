#!/usr/bin/env python3
"""Builds Potha's read-only English dictionary from Wiktionary (feature 003).

Source: wiktextract's extract of the English Wiktionary, from kaikki.org
(https://kaikki.org/dictionary/rawdata.html). Only English entries (lang_code "en")
are kept. The output is a SQLite file with the tables in
specs/003-dictionary-lookup/data-model.md ("Dictionary database"):

  meta(key, value)
  entries(id, key, headword, pos, ipa, senses, rank)   senses: JSON [{"g","t","x"}]
  forms(form_key, base_key, relation)

Wiktionary text is CC BY-SA 4.0, so the built file is too; LICENSE.md is written next to
it (research R1, FR-034).

Usage:
  python3 tool/build_dictionary.py --download           full build (--top N, default 150000) -> assets/dictionary/
  python3 tool/build_dictionary.py --input FILE         full build from a .jsonl[.gz]
  python3 tool/build_dictionary.py --sample             tests -> build/fixtures/dict_sample.sqlite
                                                        and test/fixtures/dictionary/
                                                        dict_sample.sqlite.gz (web tests)
  python3 tool/build_dictionary.py --sample --as-asset  also install the sample as the app
                                                        asset (development without the
                                                        full download)
  python3 tool/build_dictionary.py --fetch-sample test/fixtures/dictionary/sample_words.txt
                                                        refresh sample.jsonl from kaikki.org
  python3 tool/build_dictionary.py --check              key-normalisation self-test

Ranking needs `wordfreq` (build time only, never shipped):
  python3 -m venv build/dictionary/venv && build/dictionary/venv/bin/pip install wordfreq
  build/dictionary/venv/bin/python tool/build_dictionary.py --download
"""

import argparse
import gzip
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_URL = 'https://kaikki.org/dictionary/raw-wiktextract-data.jsonl.gz'
WORD_URL = 'https://kaikki.org/dictionary/English/meaning/{a}/{ab}/{word}.jsonl'
# Names the tool, not the person running it.
USER_AGENT = 'Potha-build (https://github.com/dwarftinker/potha)'
DEFAULT_DUMP_DATE = '2026-09-02'

BUILD_DIR = ROOT / 'build' / 'dictionary'
ASSET_DIR = ROOT / 'assets' / 'dictionary'
SAMPLE_JSONL = ROOT / 'test' / 'fixtures' / 'dictionary' / 'sample.jsonl'
SAMPLE_DB = ROOT / 'build' / 'fixtures' / 'dict_sample.sqlite'
# Committed: the web tests can only fetch files under test/.
SAMPLE_GZ = ROOT / 'test' / 'fixtures' / 'dictionary' / 'dict_sample.sqlite.gz'
KEY_VECTORS = ROOT / 'test' / 'fixtures' / 'dictionary' / 'key_vectors.tsv'

MAX_GZIP = 25 * 1024 * 1024
MAX_DISK = 90 * 1024 * 1024
MAX_SENSES = 12
MAX_EXAMPLES = 2
MAX_EXAMPLE_CHARS = 200
PHRASE_TOP = 20000
# wordfreq ranks "well-known" as its parts: a hyphenated word is kept when every part is
# common enough (FR-009 looks the whole word up first).
HYPHEN_TOP = 50000
NAME_TOP = 50000
MAX_PHRASE_WORDS = 4

# Parts of speech that aren't dictionary words for a reader.
SKIP_POS = {'romanization', 'character', 'symbol', 'punct', 'soft-redirect', 'hard-redirect'}

# Usage labels worth showing (others, mostly grammatical, are dropped to save space).
KEEP_TAGS = {
    'informal', 'formal', 'slang', 'colloquial', 'vulgar', 'offensive', 'derogatory',
    'humorous', 'literary', 'poetic', 'archaic', 'obsolete', 'dated', 'rare', 'historical',
    'figuratively', 'idiomatic', 'euphemistic', 'nonstandard', 'proscribed', 'jargon',
    'US', 'UK', 'British', 'Australia', 'Canada', 'Ireland', 'Scotland', 'India',
    'New-Zealand', 'South-Africa', 'countable', 'uncountable', 'transitive', 'intransitive',
}
LAST_TAGS = {'archaic', 'obsolete'}

# Form links with these tags lead readers astray ("went" -> Scots "gan"); they are dropped.
SKIP_LINK_TAGS = {
    'obsolete', 'archaic', 'dialectal', 'nonstandard', 'rare', 'misspelling',
    'eye-dialect', 'pronunciation-spelling', 'Scotland', 'Scots', 'Northern-England',
    'abbreviation', 'initialism', 'acronym', 'dated', 'humorous', 'slang',
    'proscribed', 'colloquial', 'informal', 'poetic',
}

# Most specific first: when one (form, base) pair has several relations, the first wins.
RELATIONS = ['plural', 'comparative', 'superlative', 'third_person', 'present_participle',
             'past', 'past_participle', 'form']


# --- Keys (research R5; Dart's lookupKey follows the same vectors) -------------------

_SPACE = re.compile(r'\s+')


def lookup_key(text):
    text = unicodedata.normalize('NFC', text)
    text = text.replace('’', "'").replace('‘', "'")
    text = _SPACE.sub(' ', text).strip()
    return text.lower()


def _unescape_vector(field):
    field = field.replace('\\t', '\t').replace('\\s', ' ')
    return re.sub(r'\\u([0-9A-Fa-f]{4})', lambda m: chr(int(m.group(1), 16)), field)


def check_vectors():
    failures = 0
    count = 0
    for line in KEY_VECTORS.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        source, expected = (_unescape_vector(f) for f in line.split('\t'))
        count += 1
        got = lookup_key(source)
        if got != expected:
            failures += 1
            print(f'FAIL {source!r}: {got!r} != {expected!r}')
    print(f'{count - failures}/{count} key vectors pass')
    return failures == 0


# --- Reading wiktextract lines -----------------------------------------------------

def relation_for(tags):
    tags = set(tags or ())
    # Verb tags first: conjugation tables tag "went" as "past plural", not a plural.
    if 'participle' in tags and 'present' in tags:
        return 'present_participle'
    if 'participle' in tags and 'past' in tags:
        return 'past_participle'
    if 'past' in tags:
        return 'past'
    if 'third-person' in tags and 'singular' in tags and 'present' in tags:
        return 'third_person'
    if tags & {'present', 'first-person', 'second-person', 'subjunctive', 'imperative',
               'infinitive'}:
        return None
    if 'plural' in tags:
        return 'plural'
    if 'comparative' in tags:
        return 'comparative'
    if 'superlative' in tags:
        return 'superlative'
    return None


def pick_ipa(sounds):
    ipas = [s for s in sounds or () if s.get('ipa')]
    for wanted in ('General-American', 'Received-Pronunciation', 'US', 'UK'):
        for s in ipas:
            if wanted in (s.get('tags') or ()):
                return s['ipa']
    return ipas[0]['ipa'] if ipas else None


def pick_examples(sense):
    """Usage examples only: dated quotations are long and make up most of the size."""
    out = []
    for e in sense.get('examples') or ():
        text = (e.get('text') or '').strip()
        if e.get('type') == 'example' and text and len(text) <= MAX_EXAMPLE_CHARS:
            out.append(text)
        if len(out) == MAX_EXAMPLES:
            break
    return out


ELLIPSES = ('...', '\u2026')


def gloss_of(glosses):
    """The most specific gloss. A sub-sense that continues its parent's sentence
    ("...identifiable..." / "...because it has already been mentioned") is joined to it,
    as on "the"."""
    gloss = glosses[-1]
    if len(glosses) > 1 and gloss.startswith(ELLIPSES):
        parent = glosses[-2].rstrip()
        for e in ELLIPSES:
            parent = parent.removesuffix(e)
            gloss = gloss.removeprefix(e)
        return f'{parent.rstrip()} {gloss.lstrip()}'
    return gloss


def parse_entry(d):
    """Returns (entry or None, [(form_key, base_key, relation)])."""
    word = d.get('word')
    pos = d.get('pos')
    if not word or d.get('lang_code') != 'en' or pos in SKIP_POS:
        return None, []
    key = lookup_key(word)
    links = []
    senses = []
    for s in d.get('senses') or ():
        tags = s.get('tags') or ()
        targets = (s.get('form_of') or []) + (s.get('alt_of') or [])
        if targets and ('form-of' in tags or 'alt-of' in tags):
            # Rule 1: a form-of or alt-of sense becomes a word-form row, not a sense.
            relation = relation_for(tags) or 'form'
            if not SKIP_LINK_TAGS & set(tags):
                for t in targets:
                    if t.get('word'):
                        links.append((key, lookup_key(t['word']), relation))
            continue
        glosses = s.get('glosses') or ()
        if not glosses:
            continue
        sense = {'g': gloss_of(glosses)}
        kept = [t for t in tags if t in KEEP_TAGS]
        if kept:
            sense['t'] = kept
        examples = pick_examples(s)
        if examples:
            sense['x'] = examples
        senses.append(sense)
    # Forms listed on the base word's own entry ("mouse": plural "mice").
    for f in d.get('forms') or ():
        form = f.get('form')
        relation = relation_for(f.get('tags'))
        if SKIP_LINK_TAGS & set(f.get('tags') or ()):
            continue
        if not form or not relation or ' ' in form.strip():
            continue  # "more melancholy" etc. aren't forms to look up
        form_key = lookup_key(form)
        if form_key != key:
            links.append((form_key, key, relation))
    if not senses:
        return None, links
    # Rule 4: archaic and obsolete senses last, then at most 12.
    senses.sort(key=lambda s: bool(LAST_TAGS & set(s.get('t', ()))))
    entry = {
        'key': key,
        'headword': word,
        'pos': pos,
        'ipa': pick_ipa(d.get('sounds')),
        'senses': senses[:MAX_SENSES],
    }
    return entry, links


def open_lines(path):
    path = Path(path)
    if path.suffix == '.gz':
        return gzip.open(path, 'rt', encoding='utf-8')
    return open(path, encoding='utf-8')


# --- Ranking ----------------------------------------------------------------------

def load_ranks(top):
    try:
        import wordfreq
    except ImportError:
        sys.exit('wordfreq is needed for ranking: see the header of this script.')
    words = wordfreq.top_n_list('en', max(top, NAME_TOP), wordlist='large')
    ranks = {}
    for i, w in enumerate(words):
        ranks.setdefault(lookup_key(w), i + 1)
    return ranks


# --- Build ------------------------------------------------------------------------

def stage(lines, staging):
    """Pass 1: every English entry and link into a staging database."""
    db = sqlite3.connect(staging)
    db.executescript('''
        PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;
        CREATE TABLE e (id INTEGER PRIMARY KEY, key TEXT, headword TEXT, pos TEXT,
                        ipa TEXT, senses TEXT);
        CREATE TABLE l (form_key TEXT, base_key TEXT, relation TEXT);
    ''')
    n = 0
    started = time.time()
    for line in lines:
        n += 1
        if n % 500000 == 0:
            print(f'  {n:,} lines, {time.time() - started:.0f} s', flush=True)
        if '"lang_code": "en"' not in line and '"lang_code":"en"' not in line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        entry, links = parse_entry(d)
        if entry:
            db.execute('INSERT INTO e (key, headword, pos, ipa, senses) VALUES (?,?,?,?,?)',
                       (entry['key'], entry['headword'], entry['pos'], entry['ipa'],
                        json.dumps(entry['senses'], ensure_ascii=False,
                                   separators=(',', ':'))))
        if links:
            db.executemany('INSERT INTO l VALUES (?,?,?)', links)
    db.execute('CREATE INDEX e_key ON e (key)')
    db.commit()
    return db


def select_keys(db, ranks, top, trim):
    """Rules 2 and 3: which keys to keep, and each key's rank."""
    keys = {k for (k,) in db.execute('SELECT DISTINCT key FROM e')}
    if not trim:
        return {k: ranks.get(k, len(ranks) + 1) for k in keys}
    kept = {}
    for k in keys:
        words = k.split(' ')
        if len(words) == 1 and '-' in k.strip('-'):
            rs = [ranks.get(p) for p in k.split('-') if p]
            if rs and all(r is not None and r <= HYPHEN_TOP for r in rs):
                kept[k] = max(rs)
        elif len(words) == 1:
            r = ranks.get(k)
            if r is not None and r <= top:
                kept[k] = r
        elif len(words) <= MAX_PHRASE_WORDS:
            rs = [ranks.get(w) for w in words]
            if all(r is not None and r <= PHRASE_TOP for r in rs):
                kept[k] = max(rs)
    # A base word is kept when one of its frequent forms is ("mice" keeps "mouse").
    for form_key, base_key in db.execute('SELECT form_key, base_key FROM l'):
        r = ranks.get(form_key)
        if r is not None and r <= top and base_key in keys:
            kept[base_key] = min(kept.get(base_key, r), r)
    return kept


def write_output(db, out_path, kept, trim, meta):
    if out_path.exists():
        out_path.unlink()
    out = sqlite3.connect(out_path)
    out.executescript('''
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE entries (id INTEGER PRIMARY KEY, key TEXT NOT NULL,
            headword TEXT NOT NULL, pos TEXT NOT NULL, ipa TEXT, senses TEXT NOT NULL,
            rank INTEGER NOT NULL);
        CREATE TABLE forms (form_key TEXT NOT NULL, base_key TEXT NOT NULL,
            relation TEXT NOT NULL, PRIMARY KEY (form_key, base_key)) WITHOUT ROWID;
    ''')
    headwords = 0
    for key, headword, pos, ipa, senses in db.execute(
            'SELECT key, headword, pos, ipa, senses FROM e ORDER BY id'):
        rank = kept.get(key)
        if rank is None:
            continue
        if trim and pos == 'name' and rank > NAME_TOP:
            continue  # rule 3
        out.execute('INSERT INTO entries (key, headword, pos, ipa, senses, rank) '
                    'VALUES (?,?,?,?,?,?)', (key, headword, pos, ipa, senses, rank))
        headwords += 1
    entry_keys = {k for (k,) in out.execute('SELECT DISTINCT key FROM entries')}
    best = {}
    for form_key, base_key, relation in db.execute('SELECT * FROM l'):
        if base_key not in entry_keys or form_key == base_key:
            continue
        pair = (form_key, base_key)
        if pair not in best or RELATIONS.index(relation) < RELATIONS.index(best[pair]):
            best[pair] = relation
    out.executemany('INSERT INTO forms VALUES (?,?,?)',
                    [(f, b, r) for (f, b), r in sorted(best.items())])
    out.executescript('''
        CREATE INDEX entries_key ON entries (key);
        CREATE INDEX forms_form_key ON forms (form_key);
    ''')
    meta = dict(meta, headwords=str(len(entry_keys)))
    out.executemany('INSERT INTO meta VALUES (?,?)', sorted(meta.items()))
    # drift treats user_version 0 as a new database and would try to create it; the app
    # opens this file read-only at schema version 1.
    out.execute('PRAGMA user_version = 1')
    out.commit()
    out.execute('VACUUM')
    out.close()
    return len(entry_keys), headwords, len(best)


def build(lines, out_path, *, top, trim, dump_date, build_number):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    staging = out_path.with_suffix('.staging.sqlite')
    if staging.exists():
        staging.unlink()
    print('Pass 1: reading entries', flush=True)
    db = stage(lines, staging)
    print('Ranking', flush=True)
    ranks = load_ranks(top)
    kept = select_keys(db, ranks, top, trim)
    version = dump_date.replace('-', '') + '.' + str(build_number)
    meta = {
        'language': 'en',
        'version': version,
        'source': 'English Wiktionary via wiktextract / kaikki.org',
        'source_url': 'https://en.wiktionary.org/',
        'dump_date': dump_date,
        'licence': 'CC BY-SA 4.0',
        'licence_url': 'https://creativecommons.org/licenses/by-sa/4.0/',
    }
    if trim:  # left out of the sample so its committed gzip is reproducible
        meta['built_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    print('Pass 2: writing', out_path, flush=True)
    keys, rows, forms = write_output(db, out_path, kept, trim, meta)
    db.close()
    staging.unlink()
    print(f'{keys:,} headwords ({rows:,} entries), {forms:,} forms, version {version}')
    return version


def gzip_file(src, dst):
    with open(src, 'rb') as f, gzip.GzipFile(dst, 'wb', compresslevel=9, mtime=0) as g:
        shutil.copyfileobj(f, g, 1 << 20)


def install_asset(db_path, version, dump_date):
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    gz = ASSET_DIR / 'en.sqlite.gz'
    gzip_file(db_path, gz)
    (ASSET_DIR / 'version').write_text(version + '\n', encoding='utf-8')
    (ASSET_DIR / 'LICENSE.md').write_text(LICENSE_TEXT.format(dump_date=dump_date),
                                          encoding='utf-8')
    disk = db_path.stat().st_size
    packed = gz.stat().st_size
    mib = 1024 * 1024
    print(f'Size: {packed / mib:.1f} MiB gzipped (limit {MAX_GZIP // mib}), '
          f'{disk / mib:.1f} MiB on the device (limit {MAX_DISK // mib})')
    return packed <= MAX_GZIP and disk <= MAX_DISK


LICENSE_TEXT = '''# Potha English dictionary

The definitions come from the English Wiktionary (https://en.wiktionary.org/), in the
extract made by wiktextract (https://github.com/tatuylonen/wiktextract) and published by
kaikki.org (https://kaikki.org/). Wiktionary dump: {dump_date}.

Wiktionary's text is available under the Creative Commons Attribution-ShareAlike 4.0
licence (CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/). This dictionary
file is an adapted work (entries selected, trimmed and converted to SQLite by
tool/build_dictionary.py in Potha's repository), and is shared under the same licence.

Tatu Ylonen: Wiktextract: Wiktionary as Machine-Readable Structured Data, Proceedings of
the 13th Conference on Language Resources and Evaluation (LREC), pp. 1317-1325, 2022.
'''


# --- Downloads --------------------------------------------------------------------

def http_get(url, dst=None, resume=False):
    headers = {'User-Agent': USER_AGENT}
    mode = 'wb'
    if resume and dst and dst.exists():
        headers['Range'] = f'bytes={dst.stat().st_size}-'
        mode = 'ab'
    req = urllib.request.Request(url, headers=headers)
    try:
        resp = urllib.request.urlopen(req, timeout=60)
    except urllib.error.HTTPError as e:
        if e.code == 416:  # already complete
            return None
        if e.code == 404:
            return None
        raise
    if dst is None:
        return resp.read()
    if mode == 'ab' and resp.status != 206:
        mode = 'wb'
    total = int(resp.headers.get('Content-Length') or 0)
    done = 0
    last = time.time()
    with open(dst, mode) as f:
        while chunk := resp.read(1 << 20):
            f.write(chunk)
            done += len(chunk)
            if time.time() - last > 10:
                print(f'  {done / 1e9:.2f} / {total / 1e9:.2f} GB', flush=True)
                last = time.time()
    return dst


def download_raw():
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    dst = BUILD_DIR / 'raw-wiktextract-data.jsonl.gz'
    print('Downloading', RAW_URL, '(resumable)', flush=True)
    http_get(RAW_URL, dst, resume=True)
    return dst


def word_url(word):
    a = word[0]
    ab = word[:2]
    q = lambda s: urllib.parse.quote(s, safe='')
    return WORD_URL.format(a=q(a), ab=q(ab), word=q(word))


def slim(d):
    """Only the fields parse_entry reads, so the committed sample stays small."""
    out = {k: d[k] for k in ('word', 'pos', 'lang_code') if k in d}
    out['senses'] = [{k: s[k] for k in ('glosses', 'tags', 'examples', 'form_of', 'alt_of')
                      if k in s} for s in d.get('senses') or ()]
    for s in out['senses']:
        if 'examples' in s:
            s['examples'] = [{k: e[k] for k in ('text', 'type') if k in e}
                             for e in s['examples'][:4]]
    sounds = [{k: s[k] for k in ('ipa', 'tags') if k in s}
              for s in d.get('sounds') or () if s.get('ipa')]
    if sounds:
        out['sounds'] = sounds[:4]
    forms = [{k: f[k] for k in ('form', 'tags') if k in f} for f in d.get('forms') or ()
             if relation_for(f.get('tags'))]
    if forms:
        out['forms'] = forms
    return out


def fetch_sample(words_file):
    words = [w.strip() for w in Path(words_file).read_text(encoding='utf-8').splitlines()
             if w.strip() and not w.startswith('#')]
    lines = []
    missing = []
    for word in words:
        body = http_get(word_url(word))
        if body is None:
            missing.append(word)
            continue
        for line in body.decode('utf-8').splitlines():
            d = json.loads(line) if line.strip() else {}
            if d.get('lang_code') == 'en':
                lines.append(json.dumps(slim(d), ensure_ascii=False))
        time.sleep(0.2)  # be polite
    SAMPLE_JSONL.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'{len(lines)} lines for {len(words) - len(missing)} words -> {SAMPLE_JSONL}')
    if missing:
        print('No kaikki.org entry (expected for the made-up control words):',
              ', '.join(missing))


# --- Main -------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--download', action='store_true')
    p.add_argument('--input')
    p.add_argument('--sample', action='store_true')
    p.add_argument('--as-asset', action='store_true')
    p.add_argument('--fetch-sample', metavar='WORDS_TXT')
    p.add_argument('--check', action='store_true')
    p.add_argument('--top', type=int, default=150000)
    p.add_argument('--dump-date', default=DEFAULT_DUMP_DATE)
    # Raise when the output changes for the same dump, so installed copies are replaced
    # (the version names the unpacked file and the web database). 2: joined glosses.
    p.add_argument('--build-number', type=int, default=2)
    args = p.parse_args()

    if args.check:
        sys.exit(0 if check_vectors() else 1)
    if args.fetch_sample:
        fetch_sample(args.fetch_sample)
        return
    if not check_vectors():
        sys.exit('Key normalisation is broken; fix it first.')
    if args.sample:
        with open_lines(SAMPLE_JSONL) as lines:
            version = build(lines, SAMPLE_DB, top=args.top, trim=False,
                            dump_date=args.dump_date, build_number=0)
        gzip_file(SAMPLE_DB, SAMPLE_GZ)
        if args.as_asset:
            install_asset(SAMPLE_DB, version, args.dump_date)
            print('Installed the SAMPLE dictionary as the app asset (development only).')
        return
    source = Path(args.input) if args.input else (download_raw() if args.download else None)
    if source is None:
        p.error('give --download, --input FILE, --sample, --fetch-sample or --check')
    out = BUILD_DIR / 'en.sqlite'
    with open_lines(source) as lines:
        version = build(lines, out, top=args.top, trim=True, dump_date=args.dump_date,
                        build_number=args.build_number)
    if not install_asset(out, version, args.dump_date):
        sys.exit('Over the size budget: lower --top (research R1).')


if __name__ == '__main__':
    main()
