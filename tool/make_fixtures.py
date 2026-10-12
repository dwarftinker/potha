#!/usr/bin/env python3
"""Generates the PDF fixtures used by Potha's tests.

Requires: python3 and Ghostscript (`gs` 10.02 or later, for object streams).

    python3 tool/make_fixtures.py            # small fixtures -> test/fixtures/ (committed)
    python3 tool/make_fixtures.py --large    # also build/fixtures/large_20mb.pdf (not committed)
    python3 tool/make_fixtures.py --reader   # also the 002 reader fixtures:
        test/fixtures/: outline_links.pdf (nested outline, internal and web links),
          mixed_sizes.pdf (landscape fold-out on page 3), scanned.pdf (images only),
          photo.pdf (colour image), damaged_page.pdf (page 3 has broken content; PDFium
          draws it blank),
          accents.pdf ("Café", "CAFE", "naïve"), text_500.pdf ("whale" on known pages)
        build/fixtures/ (not committed): long_2000.pdf, short_20.pdf
"""

import os
import random
import subprocess
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(ROOT, "test", "fixtures")
LARGE = os.path.join(ROOT, "build", "fixtures")


def pdf_string(text):
    """Encodes text as a PDF string: literal for ASCII, UTF-16BE hex with BOM otherwise."""
    if all(ord(c) < 128 for c in text):
        escaped = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        return f"({escaped})".encode("latin-1")
    return b"<FEFF" + text.encode("utf-16-be").hex().upper().encode() + b">"


def build_pdf(pages, info=None, xmp=None, images=None):
    """Writes a minimal classic-xref PDF.

    pages: list of page text lines; info: dict for the Info dictionary;
    xmp: XMP packet string for the catalog Metadata stream;
    images: optional list of (width, height, raw_rgb_bytes), one per page.
    """
    objects = []  # bodies, object number = index + 1

    def add(body):
        objects.append(body)
        return len(objects)

    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    pages_num = len(objects) + 1
    objects.append(None)  # pages tree placeholder
    kids = []
    for i, text in enumerate(pages):
        resources = f"<< /Font << /F1 {font} 0 R >>".encode()
        ops = f"BT /F1 24 Tf 72 720 Td ({text}) Tj ET\n".encode()
        if images:
            w, h, data = images[i]
            img = add(
                f"<< /Type /XObject /Subtype /Image /Width {w} /Height {h} "
                f"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length {len(data)} >>\nstream\n".encode()
                + data + b"\nendstream"
            )
            resources = f"<< /Font << /F1 {font} 0 R >> /XObject << /Im1 {img} 0 R >>".encode()
            ops = b"q 468 0 0 468 72 200 cm /Im1 Do Q\n" + ops
        resources += b" >>"
        content = add(f"<< /Length {len(ops)} >>\nstream\n".encode() + ops + b"endstream")
        kids.append(add(
            f"<< /Type /Page /Parent {pages_num} 0 R /MediaBox [0 0 612 792] ".encode()
            + b"/Resources " + resources + f" /Contents {content} 0 R >>".encode()
        ))
    objects[pages_num - 1] = (
        f"<< /Type /Pages /Count {len(kids)} /Kids [".encode()
        + b" ".join(f"{k} 0 R".encode() for k in kids) + b"] >>"
    )
    catalog_extra = b""
    if xmp is not None:
        data = xmp.encode("utf-8")
        meta = add(f"<< /Type /Metadata /Subtype /XML /Length {len(data)} >>\nstream\n".encode()
                   + data + b"\nendstream")
        catalog_extra = f" /Metadata {meta} 0 R".encode()
    catalog = add(f"<< /Type /Catalog /Pages {pages_num} 0 R".encode() + catalog_extra + b" >>")
    info_num = None
    if info:
        info_num = add(b"<< " + b" ".join(f"/{k} ".encode() + pdf_string(v) for k, v in info.items()) + b" >>")

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for n, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{n} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    trailer = f"<< /Size {len(objects) + 1} /Root {catalog} 0 R".encode()
    if info_num:
        trailer += f" /Info {info_num} 0 R".encode()
    out += b"trailer\n" + trailer + b" >>\n" + f"startxref\n{xref}\n%%EOF\n".encode()
    return bytes(out)


def write(name, data, folder=FIXTURES):
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, name), "wb") as f:
        f.write(data)


def gs(src, dst, *args):
    subprocess.run(
        ["gs", "-q", "-dBATCH", "-dNOPAUSE", "-dSAFER", "-sDEVICE=pdfwrite",
         f"-sOutputFile={dst}", *args, src],
        check=True,
    )


WORDS = ("the sea was calm and grey under a low sky while the ship moved slowly north "
         "past islands and long reefs where birds gathered in the cold morning light").split()


def text_lines(rng, count, extra=None):
    """Lines of filler prose; [extra] words are placed in the middle line."""
    lines = [" ".join(rng.choice(WORDS) for _ in range(9)) for _ in range(count)]
    if extra:
        mid = count // 2
        lines[mid] = lines[mid] + " " + extra
    return lines


def build_doc(pages, outline=None):
    """Writes a classic-xref PDF with Flate content streams.

    pages: list of dicts with keys
      size: (w, h) in points (default US Letter)
      lines: text lines (WinAnsi; Latin-1 characters allowed)
      image: optional (w, h, raw_rgb_bytes) drawn above the text
      links: optional list of (rect, target) where target is a page index (0-based)
             or a URL string
      broken: True to write a page that PDFium cannot load
    outline: optional list of (title, page_index, children) tuples
    """
    objects = []

    def add(body):
        objects.append(body)
        return len(objects)

    def reserve():
        objects.append(None)
        return len(objects)

    def stream(dict_extra, data, compress=True):
        if compress:
            data = zlib.compress(data)
            dict_extra += b" /Filter /FlateDecode"
        return (b"<< " + dict_extra + f" /Length {len(data)} >>\nstream\n".encode()
                + data + b"\nendstream")

    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
               b"/Encoding /WinAnsiEncoding >>")
    pages_num = reserve()
    page_nums = [reserve() for _ in pages]

    for i, page in enumerate(pages):
        w, h = page.get("size", (612, 792))
        if page.get("broken"):
            # Broken content and an empty MediaBox. PDFium draws this as a blank Letter page;
            # a broken page tree instead makes pdfrx refuse the whole file.
            objects[page_nums[i] - 1] = (
                f"<< /Type /Page /Parent {pages_num} 0 R /MediaBox [0 0 0 0] "
                f"/Contents 99999 0 R /Resources 99998 0 R >>").encode()
            continue
        ops = bytearray()
        xobjects = b""
        if page.get("image"):
            iw, ih, data = page["image"]
            img = add(stream(f"/Type /XObject /Subtype /Image /Width {iw} /Height {ih} "
                             f"/ColorSpace /DeviceRGB /BitsPerComponent 8".encode(), data))
            xobjects = f" /XObject << /Im1 {img} 0 R >>".encode()
            side = min(w, h) - 144
            ops += f"q {side} 0 0 {side * ih / iw:.2f} 72 {h - 72 - side * ih / iw:.2f} cm /Im1 Do Q\n".encode()
        lines = page.get("lines", [])
        if lines:
            ops += f"BT /F1 12 Tf 15 TL 72 {h - 90} Td\n".encode()
            for line in lines:
                esc = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
                ops += b"(" + esc.encode("latin-1") + b") Tj T*\n"
            ops += b"ET\n"
        content = add(stream(b"", bytes(ops)))
        annots = []
        for rect, target in page.get("links", []):
            r = " ".join(str(v) for v in rect)
            if isinstance(target, int):
                annots.append(add(f"<< /Type /Annot /Subtype /Link /Rect [{r}] /Border [0 0 0] "
                                  f"/Dest [{page_nums[target]} 0 R /Fit] >>".encode()))
            else:
                annots.append(add(f"<< /Type /Annot /Subtype /Link /Rect [{r}] /Border [0 0 0] "
                                  f"/A << /S /URI /URI ({target}) >> >>".encode()))
        annots_entry = (b" /Annots [" + b" ".join(f"{a} 0 R".encode() for a in annots) + b"]"
                        if annots else b"")
        objects[page_nums[i] - 1] = (
            f"<< /Type /Page /Parent {pages_num} 0 R /MediaBox [0 0 {w} {h}] ".encode()
            + f"/Resources << /Font << /F1 {font} 0 R >>".encode() + xobjects + b" >>"
            + f" /Contents {content} 0 R".encode() + annots_entry + b" >>")

    objects[pages_num - 1] = (
        f"<< /Type /Pages /Count {len(page_nums)} /Kids [".encode()
        + b" ".join(f"{k} 0 R".encode() for k in page_nums) + b"] >>")

    catalog_extra = b""
    if outline:
        root = reserve()

        def add_items(items, parent):
            nums = [reserve() for _ in items]
            for j, (title, target, children) in enumerate(items):
                body = f"<< /Title {pdf_string(title).decode('latin-1')} /Parent {parent} 0 R ".encode()
                body += f"/Dest [{page_nums[target]} 0 R /Fit]".encode()
                if j > 0:
                    body += f" /Prev {nums[j - 1]} 0 R".encode()
                if j < len(items) - 1:
                    body += f" /Next {nums[j + 1]} 0 R".encode()
                if children:
                    first, last = add_items(children, nums[j])
                    body += f" /First {first} 0 R /Last {last} 0 R /Count {len(children)}".encode()
                objects[nums[j] - 1] = body + b" >>"
            return nums[0], nums[-1]

        first, last = add_items(outline, root)
        objects[root - 1] = (f"<< /Type /Outlines /First {first} 0 R /Last {last} 0 R "
                             f"/Count {len(outline)} >>").encode()
        catalog_extra = f" /Outlines {root} 0 R /PageMode /UseOutlines".encode()
    catalog = add(f"<< /Type /Catalog /Pages {pages_num} 0 R".encode() + catalog_extra + b" >>")

    out = bytearray(b"%PDF-1.5\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for n, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{n} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += (f"trailer\n<< /Size {len(objects) + 1} /Root {catalog} 0 R >>\n"
            f"startxref\n{xref}\n%%EOF\n").encode()
    return bytes(out)


def gradient(w, h):
    """A colourful RGB test image: red to blue across, with a green band."""
    data = bytearray()
    for y in range(h):
        for x in range(w):
            g = 200 if h // 3 < y < h // 2 else 40
            data += bytes((255 * (w - x) // w, g, 255 * x // w))
    return (w, h, bytes(data))


def grey_noise(rng, w, h):
    """An image-only "scan": grey speckle that has no text layer."""
    return (w, h, bytes(v for _ in range(w * h) for v in [rng.randrange(180, 256)] * 3))


# Pages (1-based) of text_500.pdf whose text contains "whale".
WHALE_PAGES = [3, 47, 120, 250, 251, 499]


def reader_fixtures():
    rng = random.Random(2)

    pages = [{"lines": [f"Page {i + 1}"] + text_lines(rng, 20)} for i in range(12)]
    pages[0]["lines"][0] = "Page 1 - see chapter three"
    pages[0]["links"] = [((72, 600, 300, 640), 8)]           # to page 9
    pages[1]["links"] = [((72, 600, 300, 640), "https://example.org/potha")]
    outline = [
        ("Chapter One", 0, [("Section 1.1", 1, []), ("Section 1.2", 2, [])]),
        ("Chapter Two", 4, [("Section 2.1", 5, []), ("Section 2.2", 6, [])]),
        ("Chapter Three", 8, [("Section 3.1", 9, []), ("Section 3.2", 10, [])]),
    ]
    write("outline_links.pdf", build_doc(pages, outline=outline))

    write("mixed_sizes.pdf", build_doc([
        {"size": (595, 842), "lines": ["A4 portrait"]},
        {"size": (595, 842), "lines": ["A4 portrait"]},
        {"size": (1191, 842), "lines": ["A3 landscape fold-out"]},
        {"size": (420, 595), "lines": ["A5 portrait"]},
    ]))

    write("scanned.pdf", build_doc([{"image": grey_noise(rng, 60, 80)} for _ in range(5)]))
    write("photo.pdf", build_doc([{"image": gradient(120, 80), "lines": ["A colour photo"]}]))
    damaged = [{"lines": [f"Page {i + 1}"]} for i in range(5)]
    damaged[2] = {"broken": True}
    write("damaged_page.pdf", build_doc(damaged))
    write("accents.pdf", build_doc([
        {"lines": ["Le Café du Port", "CAFE OPEN", "a naïve reader"]}]))

    whale = [{"lines": text_lines(rng, 40, "a whale surfaced" if i + 1 in WHALE_PAGES else None)}
             for i in range(500)]
    write("text_500.pdf", build_doc(whale))

    write("long_2000.pdf",
          build_doc([{"lines": [f"Page {i + 1}"] + text_lines(rng, 40)} for i in range(2000)]),
          folder=LARGE)
    write("short_20.pdf",
          build_doc([{"lines": [f"Page {i + 1}"] + text_lines(rng, 40)} for i in range(20)]),
          folder=LARGE)


XMP = """<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
   <dc:title><rdf:Alt><rdf:li xml:lang="x-default">War &amp; Peace</rdf:li></rdf:Alt></dc:title>
   <dc:creator><rdf:Seq><rdf:li>Leo Tolstoy</rdf:li></rdf:Seq></dc:creator>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>"""


def main():
    meta = {"Title": "The Brothers Karamazov", "Author": "Fyodor Dostoevsky"}
    with_metadata = build_pdf(["The Brothers Karamazov"], info=meta)
    write("with_metadata.pdf", with_metadata)
    write("utf16_title.pdf", build_pdf(
        ["Crime and Punishment"],
        info={"Title": "Crime and Punishment – Преступление"}))
    write("xmp_only.pdf", build_pdf(["War and Peace"], xmp=XMP))
    write("no_metadata.pdf", build_pdf(["No metadata here"]))
    write("three_pages.pdf", build_pdf(["Page one", "Page two", "Page three"]))
    write("truncated.pdf", with_metadata[: int(len(with_metadata) * 0.6)])
    write("not_a_pdf.pdf", b"This is plain text, not a PDF.\n")

    src = os.path.join(FIXTURES, "with_metadata.pdf")
    # Ghostscript rewrites the file with an xref stream and compressed object streams,
    # carrying the Info dictionary across (gs 10.02+). -dOmitXMP drops the XMP packet so
    # the title can only be found inside the compressed object stream.
    gs(src, os.path.join(FIXTURES, "object_stream_metadata.pdf"),
       "-dWriteObjStms=true", "-dWriteXRefStm=true", "-dOmitXMP")
    gs(src, os.path.join(FIXTURES, "encrypted.pdf"),
       "-sOwnerPassword=owner-secret", "-sUserPassword=secret", "-dEncryptionR=3",
       "-dKeyLength=128")

    if "--large" in sys.argv:
        rng = random.Random(42)
        size = 600  # 600x600 RGB, about 1 MB of incompressible data per page
        images = [(size, size, rng.randbytes(size * size * 3)) for _ in range(20)]
        write("large_20mb.pdf",
              build_pdf([f"Page {i + 1}" for i in range(20)],
                        info={"Title": "Large Fixture"}, images=images),
              folder=LARGE)

    if "--reader" in sys.argv:
        reader_fixtures()


if __name__ == "__main__":
    main()
