"""Small reproducible EPUB with deliberately tricky layout; no third-party book."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import sys
out = Path(sys.argv[1] if len(sys.argv)>1 else 'tests/output')
out.mkdir(parents=True, exist_ok=True)
first = '''<h1>Linhas reais</h1>
<p>Fim.</p><p style="text-indent: 5em">Recuo depois de frase curta.</p>
<p>Uma linha comum.</p><p style="margin-top: 1.5em">Espaço de parágrafo.</p>
<h2>Título menor</h2><p>Texto <em>com ênfase</em> e <strong>negrito</strong>.</p>
<p style="font-size: 75%">Fonte pequena.</p><p style="font-size: 120%">Fonte maior.</p>
<p>Outra linha.</p><p><a href="next.xhtml">Link para o capítulo seguinte.</a></p>
<p>Última linha.</p>'''
long = '<h1>Várias páginas</h1>' + ''.join(
    '<p>'+('A leitura continua com palavras variadas, espaços e linhas verificáveis. '*18)+
    '</p><p>Fim.</p><p style="text-indent: 5em">Novo início.</p>' for _ in range(12))
files = {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': '''<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''',
    'OEBPS/content.opf': '''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Focus Reader — teste</dc:title><dc:language>pt-BR</dc:language><dc:identifier id="id">urn:focusreader:fixture:1</dc:identifier></metadata><manifest><item id="first" href="first.xhtml" media-type="application/xhtml+xml"/><item id="next" href="next.xhtml" media-type="application/xhtml+xml"/><item id="blank" href="blank.xhtml" media-type="application/xhtml+xml"/><item id="last" href="last.xhtml" media-type="application/xhtml+xml"/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="ncx"><itemref idref="first"/><itemref idref="next"/><itemref idref="blank"/><itemref idref="last"/></spine></package>''',
    'OEBPS/toc.ncx': '''<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head/><docTitle><text>Focus Reader</text></docTitle><navMap><navPoint id="a" playOrder="1"><navLabel><text>Linhas reais</text></navLabel><content src="first.xhtml"/></navPoint></navMap></ncx>''',
}
for name, body in [('first',first),('next',long),('blank','<div style="height: 100px"></div>'),('last','<p>Última página.</p>')]:
    files[f'OEBPS/{name}.xhtml'] = '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>Teste</title><style>body {font-size: 18px;} p {margin: 0 0 .3em 0;} h1 {font-size: 1.5em;} h2 {font-size: 1.2em;}</style></head><body>'+body+'</body></html>'
with ZipFile(out/'focus-reader.epub','w') as archive:
    for name, contents in files.items():
        info = ZipInfo(name, date_time=(2026,1,1,0,0,0))
        info.compress_type = 0 if name=='mimetype' else ZIP_DEFLATED
        archive.writestr(info,contents.encode('utf-8'))
print(out/'focus-reader.epub')
