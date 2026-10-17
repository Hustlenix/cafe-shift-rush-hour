"""Original, code-authored pixel silhouettes for the playable counter.

SVG coordinates are snapped to a 32px grid. No third-party or generated image input.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'original' / 'food'
OUT.mkdir(parents=True, exist_ok=True)
art = {
    'espresso': '''<path fill="#dcc6a5" d="M3 25h26v3H3z"/><path fill="#f7ead0" d="M7 13h17v12H9v-2H7zM24 15h5v7h-5v-3h3v-2h-3z"/><path fill="#543731" d="M9 12h13v4H9z"/><path fill="#b9814e" d="M10 13h11v2H10z"/><path fill="#b49c89" d="M11 5h2v5h-2zM18 3h2v6h-2z"/>''',
    'latte': '''<path fill="#c9b795" d="M3 27h26v2H3z"/><path fill="#f8ebce" d="M6 9h18v16H8v-2H6zM24 12h6v10h-6v-3h3v-4h-3z"/><path fill="#bc7f47" d="M8 8h14v5H8z"/><path fill="#fff1cb" d="M11 9h3v2h2V9h3v3h-2v2h-3v-2h-3z"/><path fill="#d8ae73" d="M8 20h14v3H8z"/><path fill="#b19f85" d="M10 3h2v3h-2zM18 1h2v5h-2z"/>''',
    'coldbrew': '''<path fill="#b3c3be" d="M7 7h20v3h-2v19H9V10H7z"/><path fill="#71503e" d="M10 11h14v15H10z"/><path fill="#a5d4d4" d="M10 9h5v5h-5zM18 13h5v5h-5zM12 19h5v5h-5z"/><path fill="#e9eecc" d="M21 1h2v10h-2zM10 26h14v2H10z"/>''',
    'chai': '''<path fill="#d1bc91" d="M2 26h28v3H2z"/><path fill="#cc7c4a" d="M4 12h20v6h-2v6H8v-3H6v-3H4zM24 13h6v6h-7v-2h4v-2h-3z"/><path fill="#ebba69" d="M5 11h18v4H5z"/><path fill="#fff0c8" d="M8 18h13v2H8zM10 22h10v2H10z"/><path fill="#d7c6a1" d="M9 3h2v6H9zM15 1h2v7h-2zM21 4h2v5h-2z"/>''',
    'matcha': '''<path fill="#bcd4b7" d="M6 6h21v3h-2v20H8V9H6z"/><path fill="#6e965b" d="M10 16h13v10H10z"/><path fill="#dfe6c7" d="M10 11h13v7H10z"/><path fill="#a3cabe" d="M10 8h5v5h-5zM18 10h5v5h-5z"/><path fill="#9a7751" d="M20 1h3v9h-3z"/><path fill="#ebeed9" d="M10 26h13v2H10z"/>''',
    'croissant': '''<path fill="#825331" d="M2 13h2V9h4V7h4V5h9v2h5v3h3v4h2v7h-3v5h-5v-3h-3v-4h3v-5h-3v-2h-8v2H9v5h3v4H9v3H5v-4H2z"/><path fill="#e0a24d" d="M4 13h3v-3h5V8h9v2h5v4h3v6h-3v3h-3v-4h2v-6h-4v-2h-9v2H7v7h2v3H6v-4H4z"/><path fill="#f3c46c" d="M9 10h3v5H9zM14 7h3v5h-3zM20 9h3v5h-3z"/>''',
    'toastie': '''<path fill="#95633f" d="M3 25V6h3l23 18v3H3z"/><path fill="#e4ae58" d="M5 23V8l20 15z"/><path fill="#f9dc92" d="M7 20v-8l12 8z"/><path fill="#b56f3e" d="M4 24h24v3H4z"/><path fill="#e9b942" d="M5 23h21v3h-5v2h-3v-2H5z"/><path fill="#684c35" d="M13 12h2v12h-2z"/>''',
    'brownie': '''<path fill="#3b282b" d="M4 10h21v16H4zM25 12h3v12h-3z"/><path fill="#714135" d="M4 7h20v4H4zM24 10h4v4h-4z"/><path fill="#925443" d="M6 8h17v3H6z"/><path fill="#d29667" d="M7 9h3v2H7zM17 8h3v2h-3zM13 13h3v2h-3z"/><path fill="#59362c" d="M6 17h17v2H6zM8 22h13v2H8z"/>''',
    'cookie': '''<path fill="#94603e" d="M11 3h10v2h5v4h3v13h-3v5h-5v2H10v-2H5v-5H3V11h2V7h6z"/><path fill="#dfa75f" d="M11 5h10v2h4v4h2v10h-3v4h-4v2H11v-3H7v-4H5v-9h3V8h3z"/><path fill="#674236" d="M10 9h4v4h-4zM19 9h4v3h-4zM18 17h4v5h-4zM9 19h4v3H9zM8 15h2v2H8z"/><path fill="#f7c879" d="M14 6h5v2h-5zM6 12h2v5H6z"/>'''
}
for name, body in art.items():
    (OUT / f'{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' + body + '</svg>\n', encoding='utf-8')
print('Created 9 distinct original counter sprites.')
