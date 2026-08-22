import json
import os
import shutil
import sqlite3
import sys

try:
    import fitz
except Exception as err:
    raise SystemExit(f"PyMuPDF import failed: {err}")


TYPE_METHODS = {
    "text": "add_text_annot",
    "highlight": "add_highlight_annot",
    "underline": "add_underline_annot",
    "squiggly": "add_squiggly_annot",
    "strike-out": "add_strikeout_annot",
}


MARKUP_TYPES = {"highlight", "underline", "squiggly", "strike-out"}


def page_rect_from_edges(page, edges):
    raw = fitz.Rect(edges)
    page_rect = page.rect
    return fitz.Rect(
        page_rect.x0 + raw.x0 * page_rect.width,
        page_rect.y0 + raw.y0 * page_rect.height,
        page_rect.x0 + raw.x1 * page_rect.width,
        page_rect.y0 + raw.y1 * page_rect.height,
    )


def page_rects_from_edges(page, edges):
    if edges and isinstance(edges[0], list):
        return [page_rect_from_edges(page, item) for item in edges]
    return [page_rect_from_edges(page, edges)]


def annotation_rects(page, data):
    if data["type"] in MARKUP_TYPES and data.get("markup-edges"):
        return page_rects_from_edges(page, data["markup-edges"])
    return page_rects_from_edges(page, data["edges"])


def union_rect(rects):
    rect = fitz.Rect(rects[0])
    for item in rects[1:]:
        rect |= item
    return rect


def existing_key(page_index, annot):
    annot_type = annot.type[1]
    if annot_type == "Text":
        return (page_index, "text")
    reverse_types = {
        "Highlight": "highlight",
        "Underline": "underline",
        "Squiggly": "squiggly",
        "StrikeOut": "strike-out",
    }
    return (page_index, reverse_types.get(annot_type, annot_type))


def rect_close(left, right):
    left_area = max(left.get_area(), 1.0)
    right_area = max(right.get_area(), 1.0)
    intersection = left & right
    if intersection.is_empty:
        return False
    overlap = intersection.get_area() / min(left_area, right_area)
    center_dx = abs(left.tl.x + left.br.x - right.tl.x - right.br.x) / 2
    center_dy = abs(left.tl.y + left.br.y - right.tl.y - right.br.y) / 2
    return overlap >= 0.60 and center_dx <= 8 and center_dy <= 8


def duplicate_annotation(existing, page_index, annot_type, rect, contents):
    contents = contents or ""
    for existing_contents, existing_rect in existing.get((page_index, annot_type), ()):
        if existing_contents != contents:
            continue
        if annot_type == "text" or rect_close(rect, existing_rect):
            return True
    return False


def annotation_snapshot(annot):
    return (annot.info.get("content") or "", fitz.Rect(annot.rect))


def set_optional_info(annot, data, page):
    info = {}
    mapping = {
        "contents": "content",
        "label": "title",
        "subject": "subject",
        "created": "creationDate",
        "modified": "modDate",
    }
    for source, target in mapping.items():
        value = data.get(source)
        if value not in (None, ""):
            info[target] = str(value)
    if info:
        annot.set_info(info)
    color = data.get("color")
    if color:
        rgb = tuple(int(color[i : i + 2], 16) / 255 for i in (1, 3, 5))
        annot.set_colors(stroke=rgb)
    if data.get("opacity") is not None:
        annot.set_opacity(float(data["opacity"]))
    if data.get("flags") is not None:
        annot.set_flags(int(data["flags"]))
    if data.get("type") == "text" and data.get("icon"):
        annot.set_name(str(data["icon"]))
    if data.get("popup-edges"):
        annot.set_popup(union_rect(page_rects_from_edges(page, data["popup-edges"])))
    open_value = data.get("is-open")
    if open_value is None:
        open_value = data.get("popup-is-open")
    if open_value is not None:
        annot.set_open(bool(open_value))
    annot.update()


def book_pdf(library_root, book_id):
    db = os.path.join(library_root, "metadata.db")
    with sqlite3.connect(db) as conn:
        row = conn.execute(
            """
            SELECT books.path, data.name
            FROM data
            JOIN books ON books.id = data.book
            WHERE data.book = ? AND lower(data.format) = 'pdf'
            LIMIT 1
            """,
            (book_id,),
        ).fetchone()
    if not row:
        raise SystemExit(f"No PDF format for Calibre book {book_id}")
    path = os.path.join(library_root, row[0], row[1] + ".pdf")
    if not os.path.isfile(path):
        raise SystemExit(f"Calibre PDF is missing: {path}")
    return path


def annotated_pdf(pdf_file):
    directory, filename = os.path.split(pdf_file)
    stem, ext = os.path.splitext(filename)
    path = os.path.join(directory, stem + " - annotated" + ext)
    if not os.path.exists(path):
        shutil.copy2(pdf_file, path)
    if not os.path.isfile(path):
        raise SystemExit(f"Annotated PDF is missing: {path}")
    return path


try:
    json_file, library_root, book_id = sys.argv[1:]
    with open(json_file, encoding="utf-8") as handle:
        incoming = json.load(handle)
    incoming = [data for data in incoming if data.get("type") in TYPE_METHODS]
    if not incoming:
        raise SystemExit(0)

    pdf_file = annotated_pdf(book_pdf(library_root, int(book_id)))
    stat = os.stat(pdf_file)
    doc = fitz.open(pdf_file)
    try:
        existing = {}
        for page_index in range(len(doc)):
            for annot in doc[page_index].annots() or ():
                existing.setdefault(existing_key(page_index, annot), []).append(
                    annotation_snapshot(annot)
                )
        added = 0
        for data in incoming:
            page_index = int(data["page"]) - 1
            annot_type = data["type"]
            if page_index < 0 or page_index >= len(doc):
                raise SystemExit(f"Annotation page out of range: {page_index + 1}")
            if annot_type not in TYPE_METHODS:
                continue
            page = doc[page_index]
            rects = annotation_rects(page, data)
            rect = union_rect(rects)
            if duplicate_annotation(
                existing, page_index, annot_type, rect, data.get("contents")
            ):
                continue
            method = getattr(page, TYPE_METHODS[annot_type])
            if annot_type == "text":
                annot = method(rects[0].tl, data.get("contents") or "")
            else:
                annot = method(rects if len(rects) > 1 else rects[0])
            set_optional_info(annot, data, page)
            existing.setdefault((page_index, annot_type), []).append(
                annotation_snapshot(annot)
            )
            added += 1
        if added:
            tmp = pdf_file + ".pdf-sync-tmp"
            doc.save(tmp)
            doc.close()
            os.replace(tmp, pdf_file)
            os.utime(pdf_file, (stat.st_atime, stat.st_mtime))
        else:
            doc.close()
    finally:
        if not doc.is_closed:
            doc.close()
    print(added)
finally:
    if "json_file" in globals() and os.path.exists(json_file):
        os.unlink(json_file)
