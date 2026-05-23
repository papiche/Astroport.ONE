#!/usr/bin/env python3
"""Retourne l'historique des sessions de démarrage via journalctl, en JSON."""
import subprocess, json, re, datetime

TS_RE = re.compile(r'(\w{3} \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \w+)')

def parse_ts(s):
    try:
        parts = s.rsplit(' ', 1)
        return datetime.datetime.strptime(parts[0], '%a %Y-%m-%d %H:%M:%S').isoformat()
    except Exception:
        return s

try:
    result = subprocess.run(['journalctl', '--list-boots'], capture_output=True, text=True, timeout=5)
    boots = []
    for line in result.stdout.strip().splitlines():
        if line.startswith('IDX') or not line.strip():
            continue
        m = re.match(r'^\s*(-?\d+)\s+(\S+)\s+(.*)', line.strip())
        if not m:
            continue
        idx, boot_id, rest = m.group(1), m.group(2), m.group(3)
        timestamps = TS_RE.findall(rest)
        running = (int(idx) == 0)
        start_ts = parse_ts(timestamps[0]) if timestamps else ''
        end_ts = parse_ts(timestamps[1]) if len(timestamps) > 1 and not running else None
        dur = 0
        if start_ts:
            try:
                st = datetime.datetime.fromisoformat(start_ts)
                if end_ts:
                    en = datetime.datetime.fromisoformat(end_ts)
                    dur = int((en - st).total_seconds())
                else:
                    dur = int((datetime.datetime.utcnow() - st).total_seconds())
            except Exception:
                dur = 0
        boots.append({'idx': int(idx), 'boot_id': boot_id, 'start': start_ts,
                      'end': end_ts, 'duration': dur, 'running': running})
    print(json.dumps(boots))
except Exception:
    print('[]')
