#!/usr/bin/env python3
"""Retourne le temps de fonctionnement de la station au format lisible (ex: 5 days, 3:12:45)."""
import datetime
u = float(open('/proc/uptime').read().split()[0])
print(str(datetime.timedelta(seconds=int(u))))
