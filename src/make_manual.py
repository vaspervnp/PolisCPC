"""Τα εγχειρίδια του παίκτη σε PDF.

    python3 src/make_manual.py

docs/manual_en.md, docs/manual_el.md -> docs/manual_en.pdf, docs/manual_el.pdf

Markdown -> HTML (python-markdown, με πίνακες) -> PDF με το LibreOffice
(headless). Οι εικόνες (docs/img/) είναι στιγμιότυπα του emulator.
"""
import os
import re
import shutil
import subprocess
import tempfile

import markdown

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, 'docs')
CSS = '''
body  { font-family: 'Noto Sans', 'DejaVu Sans', sans-serif; font-size: 10.5pt;
        line-height: 1.4; color: #111; }
h1    { font-size: 24pt; color: #8a5a00; margin-bottom: 2pt; }
h2    { font-size: 15pt; color: #1d3c8f; border-bottom: 1px solid #1d3c8f;
        margin-top: 16pt; }
h3    { font-size: 12pt; color: #1d3c8f; }
table { border-collapse: collapse; margin: 6pt 0; }
th, td { border: 1px solid #999; padding: 1pt 4pt; font-size: 9.5pt;
         vertical-align: top; line-height: 1.15; margin: 0; }
th    { background: #e4e8f4; }
code, pre { font-family: 'DejaVu Sans Mono', monospace; }
img   { width: 12cm; }
'''


def build(lang):
    src = os.path.join(DOCS, 'manual_%s.md' % lang)
    body = markdown.markdown(open(src, encoding='utf-8').read(),
                             extensions=['tables', 'fenced_code'])
    body = re.sub(r'>\s+<', '><', body)       # (κενές γραμμές στους πίνακες)
    body = body.replace('<img ', '<img width="454" ')
    body = body.replace('<table>', '<table border="1" cellpadding="3" '
                        'cellspacing="0">')
    html = ('<!DOCTYPE html><html lang="%s"><head><meta charset="utf-8">'
            '<title>POLIS</title><style>%s</style></head><body>%s'
            '</body></html>' % (lang, CSS, body))
    tmp = tempfile.mkdtemp()
    try:
        page = os.path.join(tmp, 'manual_%s.html' % lang)
        open(page, 'w', encoding='utf-8').write(html)
        shutil.copytree(os.path.join(DOCS, 'img'), os.path.join(tmp, 'img'))
        subprocess.check_call(
            ['libreoffice', '--headless', '--convert-to',
             'pdf:writer_web_pdf_Export', '--outdir', tmp, page],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        out = os.path.join(DOCS, 'manual_%s.pdf' % lang)
        shutil.move(os.path.join(tmp, 'manual_%s.pdf' % lang), out)
        print(out)
    finally:
        shutil.rmtree(tmp)


def main():
    for lang in ('en', 'el'):
        build(lang)


if __name__ == '__main__':
    main()
