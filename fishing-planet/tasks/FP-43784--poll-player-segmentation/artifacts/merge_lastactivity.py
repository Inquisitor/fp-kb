import csv, os, sys
from datetime import datetime
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')

ART = r'D:\kb\fishing-planet\tasks\FP-43784--poll-player-segmentation\artifacts'

LA_RAW = {
    'mob': [
        ('DaenerysTargaryen', '2023-11-17 14:58:53'),
        ('DaenerysTargaryen-VII', '2026-05-19 01:40:40'),
        ('FurryNetThief', '2025-05-27 14:00:26'),
        ('GiganticBarnacleKozak', '2026-05-19 15:53:39'),
        ('jacob', '2022-04-02 12:16:28'),
        ('JF_Fishing', '2023-03-12 07:50:45'),
        ('JfFishing', '2022-10-08 19:13:31'),
        ('omarxd', '2026-05-14 04:49:10'),
        ('Quack-Attack83', '2026-05-19 17:08:42'),
        ('Santino', '2023-04-23 15:10:32'),
    ],
    'xb': [
        ('BEYONDxxHELP', '2026-05-19 03:08:15'),
        ('Brazenleader641', '2026-05-19 04:00:47'),
        ('FlouryImp', '2026-05-18 23:57:26'),
        ('Lilstumpy328', '2026-05-19 19:23:43'),
        ('NoahDestroyer18', '2026-05-19 17:41:12'),
        ('Silverwolf1887', '2026-05-16 01:00:14'),
        ('TheShadows4966', '2026-05-17 13:26:44'),
    ],
    'ps': [
        ('Adas_snaj', '2026-04-19 14:00:15'),
        ('argiris-dio', '2026-05-19 17:57:36'),
        ('C_J_92', '2026-05-15 17:07:26'),
        ('fatboy_1954', '2026-05-18 23:58:30'),
        ('FIT_Clavale61', '2026-05-19 18:59:55'),
        ('InCHIweTrust', '2026-05-18 12:43:51'),
        ('jmcostarica', '2026-05-18 23:22:34'),
        ('newish-ferry1234', '2026-05-19 03:41:51'),
        ('quiberon1958', '2026-05-19 15:04:28'),
    ],
    'steam': [
        ('AffableScallopIdol', '2026-05-19 12:20:11'),
        ('Andy', '2022-09-06 14:57:48'),
        ('Bargearse', '2026-05-11 02:30:24'),
        ('Big_T', '2023-05-17 19:38:25'),
        ('BigT', '2016-01-10 10:11:42'),
        ('boika', '2019-10-16 15:25:23'),
        ('BoyKa', '2017-08-25 14:30:29'),
        ('Br00ther7', '2025-12-19 19:09:16'),
        ('BrightPerchBreaker36', '2024-01-27 19:01:59'),
        ('captainwest', '2017-08-20 05:39:14'),
        ('Casadei', '2026-05-19 17:17:30'),
        ('CptCodeye', '2026-05-19 06:41:01'),
        ('D4B0mb', '2026-05-10 02:27:58'),
        ('DeathMachineUA_gaming', '2026-05-19 15:23:42'),
        ('DjabeU', '2024-06-12 16:12:14'),
        ('Djuka99', '2026-05-08 00:10:08'),
        ('DoctorLaw', '2025-02-26 23:33:54'),
        ('DUKA99', '2025-12-13 11:08:29'),
        ('Edupu', '2026-05-18 18:24:08'),
        ('EnlightenedWhitefishPrince', '2026-05-19 03:39:16'),
        ('EnormousGarHunter', '2026-05-19 15:04:59'),
        ('FantasticPerchDaddy62', '2026-05-10 18:49:11'),
        ('far5915', '2026-05-08 20:44:09'),
        ('fishstick123', '2026-05-19 15:18:47'),
        ('FIxieIsMonk', '2026-05-19 12:56:06'),
        ('Ivakis_Solo', '2025-11-27 18:33:39'),
        ('Jekyll_Hyde', '2025-12-17 04:23:27'),
        ('JekyllHyde', '2021-05-07 13:59:19'),
        ('JohnCarl', '2026-05-19 14:33:44'),
        ('KTMO88', '2026-05-19 03:40:56'),
        ('MototasmaFunkeiro', '2026-05-18 21:56:25'),
        ('Mr.Bones', '2015-08-11 20:41:01'),
        ('Mr_Bones', '2021-08-13 02:12:09'),
        ('mrbones', '2017-08-29 00:40:09'),
        ('MrTroyMan', '2026-05-08 08:09:26'),
        ('Niszczycielswiatow123', '2026-05-19 18:45:59'),
        ('nunofrazao', '2026-05-16 07:42:03'),
        ('Nyoraco', '2025-11-04 08:47:07'),
        ('Nyoraco_Twitch', '2026-05-16 19:53:52'),
        ('O.Azeitona', '2026-05-19 19:31:02'),
        ('Paco_Barba', '2026-05-19 10:44:54'),
        ('PacoBarba', '2024-11-12 22:32:03'),
        ('Pasiek', '2019-11-03 17:26:10'),
        ('PILOT_ON_BOARD', '2026-05-16 06:41:55'),
        ('Pizza_slice', '2024-04-28 19:22:39'),
        ('PowerfulCastingMystic', '2026-05-19 05:16:43'),
        ('Prost_Plovs', '2026-05-19 19:06:09'),
        ('PrxmE', '2024-11-02 01:24:38'),
        ('Ranger_Hitam', '2026-02-22 12:49:57'),
        ('rda', '2020-01-03 20:25:41'),
        ('ReggieCarter', '2026-05-19 18:27:16'),
        ('SERFUJE', '2026-05-08 18:45:44'),
        ('Slashy', '2019-04-09 05:55:45'),
        ('SplendidCarpMercenary', '2026-05-19 05:29:52'),
        ('SrPuff', '2026-05-19 03:04:50'),
        ('Tom', '2015-08-11 15:26:46'),
        ('TOYOTAGUY', '2020-08-10 18:50:03'),
        ('twitch_b0rreg0chan', '2026-05-19 06:09:32'),
        ('vanthanh', '2025-03-02 04:42:49'),
        ('Washed', '2022-05-07 05:32:18'),
        ('water', '2015-08-12 15:45:10'),
        ('xVectoRx', '2026-05-16 12:41:17'),
    ],
}

NOW = datetime(2026, 5, 19, 20, 0, 0)

# Save raw lastactivity for record
for b, items in LA_RAW.items():
    p = os.path.join(ART, f'02c_lastactivity_{b}.csv')
    with open(p, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        w.writerow(['MatchedUsername', 'LastActivityDate'])
        for n, d in items:
            w.writerow([n, d])

la_map = {}
for b, items in LA_RAW.items():
    for n, d in items:
        la_map[(b, n.lower())] = datetime.strptime(d, '%Y-%m-%d %H:%M:%S')


def time_ago(dt):
    if not dt:
        return ''
    delta = NOW - dt
    secs = delta.total_seconds()
    if secs < 60:
        return f'{int(secs)}s'
    mins = secs / 60
    if mins < 60:
        return f'{int(mins)}m'
    hours = mins / 60
    if hours < 24:
        return f'{int(hours)}h'
    days = hours / 24
    if days < 30:
        return f'{int(days)}d'
    months = days / 30
    if months < 12:
        return f'{int(months)}mo'
    years = months / 12
    return f'{years:.1f}y'


def parse_level(s):
    s = (s or '').strip()
    try:
        return int(s)
    except Exception:
        return -1


orig_category = {}
for b in ['steam', 'ps', 'xb', 'mob', 'nx']:
    p = os.path.join(ART, f'04_variants_{b}_fixed.tsv')
    with open(p, encoding='utf-8', newline='') as f:
        for r in csv.DictReader(f, delimiter='\t'):
            orig_category[(b, r['original_nickname'])] = r.get('category', '')


best_per_orig = {}
for b in ['mob', 'xb', 'ps', 'steam']:
    p = os.path.join(ART, f'02b_prod_result_{b}_pass2.csv')
    with open(p, encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f))
    by_orig = defaultdict(list)
    for r in rows:
        if r['MatchedUsername'].strip():
            la = la_map.get((b, r['MatchedUsername'].lower()))
            r['LastActivityDate'] = la
            r['TimeAgo'] = time_ago(la)
            by_orig[r['OriginalNick']].append(r)
    for orig, cands in by_orig.items():
        best = max(cands, key=lambda r: (
            r['LastActivityDate'] or datetime.min,
            parse_level(r['Level']),
            r['IsPayer'] == '1',
        ))
        best_per_orig[(b, orig)] = {'best': best, 'all': cands}


def classify(b, orig, info):
    best = info['best']
    cands = info['all']
    la = best['LastActivityDate']
    if not la:
        return 'no_date'
    days_ago = (NOW - la).days
    if days_ago > 365:
        return 'drop_stale'
    if days_ago > 30:
        return 'review_stale'
    if len(cands) > 1:
        fresh_others = [
            c for c in cands
            if c is not best and c['LastActivityDate']
            and (NOW - c['LastActivityDate']).days <= 30
        ]
        if fresh_others:
            return 'review_ambiguous_both_fresh'
    return 'keep'


categorized = defaultdict(list)
for key, info in best_per_orig.items():
    cls = classify(key[0], key[1], info)
    categorized[cls].append((key, info))

print('=== Classification (with freshness) ===')
for cls in ['keep', 'review_ambiguous_both_fresh', 'review_stale', 'drop_stale', 'no_date']:
    items = categorized.get(cls, [])
    print(f'  {cls}: {len(items)}')

# manual_review.csv: only review/drop cases
out = os.path.join(ART, '06_manual_review.csv')
with open(out, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f)
    w.writerow([
        'bucket', 'original', 'reason', 'category', 'best_variant', 'source',
        'matched', 'level', 'country', 'ispayer', 'last_activity', 'time_ago',
        'candidates'
    ])
    for cls in ['drop_stale', 'review_stale', 'review_ambiguous_both_fresh', 'no_date']:
        for (b, orig), info in categorized.get(cls, []):
            best = info['best']
            cands = info['all']
            cand_str = ' | '.join(
                f"{c['Variant']}->{c['MatchedUsername']} (Lvl {c['Level']}, {c['Country']}, P={c['IsPayer']}, last {c['TimeAgo']})"
                for c in cands
            )
            cat = orig_category.get((b, orig), '')
            la_str = best['LastActivityDate'].strftime('%Y-%m-%d') if best['LastActivityDate'] else ''
            w.writerow([
                b, orig, cls, cat, best['Variant'], best['Source'],
                best['MatchedUsername'], best['Level'], best['Country'],
                best['IsPayer'], la_str, best['TimeAgo'], cand_str
            ])

# auto-keep
out_auto = os.path.join(ART, '06_pass2_auto.csv')
with open(out_auto, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f)
    w.writerow([
        'bucket', 'original', 'best_variant', 'source', 'matched', 'level',
        'country', 'ispayer', 'last_activity', 'time_ago', 'category'
    ])
    for (b, orig), info in categorized.get('keep', []):
        best = info['best']
        cat = orig_category.get((b, orig), '')
        la_str = best['LastActivityDate'].strftime('%Y-%m-%d') if best['LastActivityDate'] else ''
        w.writerow([
            b, orig, best['Variant'], best['Source'], best['MatchedUsername'],
            best['Level'], best['Country'], best['IsPayer'], la_str,
            best['TimeAgo'], cat
        ])

print(f'\nWrote:')
print(f'  {out_auto}')
print(f'  {out}')
