"""Assemble final TSV for FP-43784 — 4 columns aligned with source CSV row order:
    Matched nick | Level | Country | Is Payer
Combines pass-1 direct matches and pass-2 confident variant matches.
Country normalized to ISO-2 UPPERCASE via pycountry (fallback: as-is uppercased)."""

import csv
import os
import sys

import pycountry

sys.stdout.reconfigure(encoding='utf-8')

ART = r'D:\kb\fishing-planet\tasks\FP-43784--poll-player-segmentation\artifacts'
SRC = r'P:\My Drive\Research\Forms\2026-05-19 - Next Fishing Planet Map (Responses) - Form Responses 1.csv'
OUT = os.path.join(ART, '07_final_tsv.tsv')

BUCKET = {
    'Steam': 'steam', 'Epic Games': 'steam',
    'PlayStation': 'ps', 'PS': 'ps',
    'Xbox': 'xb', 'UWP': 'xb',
    'Mobile (Android)': 'mob', 'Mobile (iOS)': 'mob',
    'Nintendo Switch': 'nx',
}

# Manual fixes for country strings the lookup can't resolve
COUNTRY_OVERRIDES = {
    'eN': 'EN_BAD',  # questionable raw data, will surface
    'om': '',         # ambiguous fragment, drop
    'ta': '',
    'ti': '',
    'in': 'IN',       # India
    'us': 'US', 'fr': 'FR', 'de': 'DE', 'gb': 'GB', 'pl': 'PL', 'br': 'BR',
    'it': 'IT', 'es': 'ES', 'ua': 'UA', 'ca': 'CA', 'au': 'AU', 'id': 'ID',
    'ar': 'AR', 'mx': 'MX', 'nl': 'NL', 'be': 'BE', 'jp': 'JP', 'hk': 'HK',
    'tr': 'TR', 'fi': 'FI', 'no': 'NO', 'se': 'SE', 'dk': 'DK', 'at': 'AT',
    'ch': 'CH', 'ie': 'IE', 'cn': 'CN', 'hu': 'HU', 'lt': 'LT', 'lv': 'LV',
    'ee': 'EE', 'cz': 'CZ', 'sk': 'SK', 'ro': 'RO', 'bg': 'BG', 'hr': 'HR',
    'si': 'SI', 'rs': 'RS', 'ru': 'RU', 'kz': 'KZ', 'by': 'BY', 'md': 'MD',
    'gr': 'GR', 'pt': 'PT', 'cl': 'CL', 'co': 'CO', 'pe': 'PE', 'py': 'PY',
    'uy': 'UY', 'bo': 'BO', 've': 'VE', 'cr': 'CR', 'hn': 'HN', 'gt': 'GT',
    'pa': 'PA', 'ni': 'NI', 'sv': 'SV', 'do': 'DO', 'pr': 'PR',
    'za': 'ZA', 'eg': 'EG', 'ma': 'MA', 'dz': 'DZ', 'tn': 'TN', 'ng': 'NG',
    'ke': 'KE', 'gh': 'GH', 'th': 'TH', 'ph': 'PH', 'vn': 'VN', 'my': 'MY',
    'sg': 'SG', 'kr': 'KR', 'tw': 'TW', 'mn': 'MN', 'pk': 'PK', 'bd': 'BD',
    'lk': 'LK', 'np': 'NP', 'ae': 'AE', 'sa': 'SA', 'qa': 'QA', 'kw': 'KW',
    'jo': 'JO', 'il': 'IL', 'lb': 'LB', 'ir': 'IR', 'nz': 'NZ',
    'is': 'IS', 'lu': 'LU', 'mt': 'MT', 'cy': 'CY', 'al': 'AL', 'mk': 'MK',
    'ba': 'BA', 'me': 'ME', 'xk': 'XK',
    'EN_BAD': '',  # for safety
    '**': '',
    ',': '',
    '"': '',
    '': '',
}


def norm_country(raw: str) -> str:
    s = (raw or '').strip()
    if not s:
        return ''
    # Direct ISO-2: 2 letters case-insensitive
    if len(s) == 2 and s.isalpha():
        up = s.upper()
        # filter out gibberish 2-letter combos that aren't real ISO-2
        try:
            pycountry.countries.lookup(up)
            return up
        except LookupError:
            return COUNTRY_OVERRIDES.get(s.lower(), '')
    # Try full-name lookup via pycountry
    try:
        c = pycountry.countries.lookup(s)
        return c.alpha_2
    except LookupError:
        pass
    # Try by official_name
    try:
        for c in pycountry.countries:
            if c.name.upper() == s.upper():
                return c.alpha_2
    except Exception:
        pass
    return ''


# ---- 1) Load combined matched map ----

matched = {}  # (bucket, lower_nick) -> {matched, level, country, ispayer}

# Pass-1: from 02_prod_result_<bucket>.csv
for b in ['steam', 'ps', 'xb', 'mob', 'nx']:
    p = os.path.join(ART, f'02_prod_result_{b}.csv')
    with open(p, encoding='utf-8', newline='') as f:
        for r in csv.DictReader(f):
            if r['MatchedUsername'].strip():
                key = (b, r['PolledNickname'].lower())
                matched[key] = {
                    'matched': r['MatchedUsername'],
                    'level': r['Level'],
                    'country': r['Country'],
                    'ispayer': r['IsPayer'],
                    'source': 'pass1',
                }

# Pass-2 auto-keep: from 06_pass2_auto.csv
auto_path = os.path.join(ART, '06_pass2_auto.csv')
with open(auto_path, encoding='utf-8', newline='') as f:
    for r in csv.DictReader(f):
        key = (r['bucket'], r['original'].lower())
        matched[key] = {
            'matched': r['matched'],
            'level': r['level'],
            'country': r['country'],
            'ispayer': r['ispayer'],
            'source': 'pass2_auto',
        }

# Pass-2 KEEPs from review_stale (3 manual decisions per user verdict)
MANUAL_KEEPS = [
    # (bucket, original, matched, level, country, ispayer)
    ('steam', 'Ivakis Solo', 'Ivakis_Solo', '67', 'BG', '1'),
    ('steam', 'Jekyll&Hyde', 'Jekyll_Hyde', '22', 'FR', '1'),
    ('steam',
     'My discord name is Prxme or p.r.x.m.e my steam is Br00ther7',
     'Br00ther7', '95', 'US', '1'),
]
for b, orig, m, lvl, ctry, ip in MANUAL_KEEPS:
    matched[(b, orig.lower())] = {
        'matched': m, 'level': lvl, 'country': ctry, 'ispayer': ip,
        'source': 'pass2_manual_keep',
    }

print(f'Matched map size: {len(matched)}')
src_breakdown = {'pass1': 0, 'pass2_auto': 0, 'pass2_manual_keep': 0}
for v in matched.values():
    src_breakdown[v['source']] += 1
print(f'By source: {src_breakdown}')

# ---- 2) Read source CSV in order, build TSV ----

with open(SRC, encoding='utf-8-sig', newline='') as f:
    rdr = csv.reader(f)
    header = next(rdr)
    src_rows = list(rdr)

print(f'Source rows: {len(src_rows)}')

unknown_country = {}
written = 0
filled = 0
seen_nicks = set()
dup_count = 0
out_lines = ['Matched nick\tLevel\tCountry\tIs Payer\tDuplicate?']
for r in src_rows:
    nick = r[1].strip() if len(r) > 1 else ''
    plat = r[5].strip() if len(r) > 5 else ''
    bucket = BUCKET.get(plat, '')
    info = matched.get((bucket, nick.lower())) if bucket and nick else None
    nick_key = nick.lower()
    dup_label = ''
    if nick_key:
        if nick_key in seen_nicks:
            dup_label = 'DUPLICATE'
            dup_count += 1
        else:
            seen_nicks.add(nick_key)
    if info:
        ctry_norm = norm_country(info['country'])
        if not ctry_norm and info['country']:
            unknown_country[info['country']] = unknown_country.get(info['country'], 0) + 1
        ispayer_label = 'Yes' if info['ispayer'] == '1' else 'No'
        line = f"{info['matched']}\t{info['level']}\t{ctry_norm}\t{ispayer_label}\t{dup_label}"
        filled += 1
    else:
        line = f'\t\t\t\t{dup_label}'
    out_lines.append(line)
    written += 1

print(f'Duplicates marked: {dup_count}')

with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(out_lines) + '\n')

print(f'\nWritten {OUT} ({written} data rows, {filled} filled, {written - filled} blank)')
print(f'Fill rate: {100 * filled / written:.1f}%')

if unknown_country:
    print(f'\nUnresolved country strings (left blank):')
    for k, n in sorted(unknown_country.items(), key=lambda x: -x[1]):
        print(f'  {n:5d}  {k!r}')
