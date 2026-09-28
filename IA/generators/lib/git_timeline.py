#!/usr/bin/env python3
"""
git_timeline.py — frise HTML de l'historique d'un dépôt git (commits par mois +
jalons), capturée ensuite en plan "screen" par generate_scene.sh.

Usage : git_timeline.py <dépôt> <sortie.html> [--title T] [--from AAAA-MM] [--to AAAA-MM]
                        [--milestone "AAAA-MM-JJ|texte"]... [--width 1280] [--height 720]
Les mois hors de --from/--to restent visibles mais estompés ; les jalons de la
période sont listés sous la frise.
"""

import argparse
import collections
import html
import subprocess


def monthly_counts(repo):
    out = subprocess.run(["git", "-C", repo, "log", "--format=%ad", "--date=format:%Y-%m"],
                         capture_output=True, text=True, check=True).stdout.split()
    counts = collections.Counter(out)
    months = []
    y, m = map(int, min(counts).split("-"))
    last = max(counts)
    while f"{y:04d}-{m:02d}" <= last:
        months.append(f"{y:04d}-{m:02d}")
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return months, counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo")
    parser.add_argument("out")
    parser.add_argument("--title", default="")
    parser.add_argument("--from", dest="start", default="0000-00")
    parser.add_argument("--to", dest="end", default="9999-99")
    parser.add_argument("--milestone", action="append", default=[])
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    args = parser.parse_args()

    months, counts = monthly_counts(args.repo)
    peak = max(counts.values())
    total = sum(counts[m] for m in months if args.start <= m <= args.end)
    w, h = args.width, args.height
    chart_h = int(h * 0.42)
    bar_w = (w * 0.9) / len(months)

    bars = []
    for i, month in enumerate(months):
        c = counts.get(month, 0)
        bh = max(2, int(chart_h * c / peak)) if c else 0
        active = args.start <= month <= args.end
        label = f'<div class="ml">{month[2:4]}/{month[5:]}</div>' if month.endswith(("-01", "-07")) or i == 0 else ""
        count = f'<div class="c">{c}</div>' if active and c >= peak * 0.08 else ""
        bars.append(f'<div class="b{"" if active else " off"}" style="left:{i * bar_w:.1f}px;width:{bar_w * 0.8:.1f}px">'
                    f'{count}<div class="bar" style="height:{bh}px"></div>{label}</div>')

    items = []
    for ms in args.milestone:
        date, _, text = ms.partition("|")
        if args.start <= date[:7] <= args.end:
            items.append(f'<li><b>{html.escape(date)}</b> {html.escape(text)}</li>')

    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;width:{w}px;height:{h}px;background:#0b1118;color:#e8e4d8;font-family:"DejaVu Sans Mono",monospace;overflow:hidden}}
h1{{margin:{h // 24}px 0 0 {w // 20}px;font-size:{h // 18}px;color:#f5c542}}
.sub{{margin:4px 0 0 {w // 20}px;font-size:{h // 40}px;opacity:.7}}
.chart{{position:relative;margin:{h // 30}px auto 0;width:{w * 0.9:.0f}px;height:{chart_h + 40}px;border-bottom:1px solid #34506a}}
.b{{position:absolute;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;height:100%}}
.bar{{width:100%;background:linear-gradient(#5fd3a0,#1f7a5a);border-radius:3px 3px 0 0}}
.off .bar{{background:#24313d}}
.c{{font-size:{h // 52}px;color:#5fd3a0;margin-bottom:3px}}
.ml{{position:absolute;bottom:-{h // 30}px;font-size:{h // 60}px;opacity:.6;white-space:nowrap}}
ul{{margin:{h // 18}px {w // 20}px 0;padding:0;list-style:none;font-size:{h // 34}px;line-height:1.55;columns:2}}
li b{{color:#f5c542;margin-right:.5em}}
</style></head><body>
<h1>{html.escape(args.title)}</h1>
<div class="sub">{total} commits sur la période · {sum(counts.values())} au total</div>
<div class="chart">{''.join(bars)}</div>
<ul>{''.join(items)}</ul>
</body></html>"""
    with open(args.out, "w") as f:
        f.write(page)


if __name__ == "__main__":
    main()
