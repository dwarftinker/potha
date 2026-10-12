#!/usr/bin/env python3
"""Generates the PDF fixtures used by Potha's tests.

Requires: python3 and Ghostscript (`gs` 10.02 or later, for object streams).

    python3 tool/make_fixtures.py            # small fixtures -> test/fixtures/ (committed)
    python3 tool/make_fixtures.py --large    # also build/fixtures/large_20mb.pdf (not committed)
"""

import os
import random
import subprocess
import sys

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


if __name__ == "__main__":
    main()
