#!/usr/bin/env bash
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT"

LOCKFILE="/tmp/fardtjanst-daily.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "Planeraren körs redan."; exit 0; }

node tracking-service.js >> logs/daily-trips.log 2>&1

if [ ! -f todays-trips.json ]; then
    echo "Ingen reseplan hittades." >> logs/daily-trips.log
    exit 0
fi

DATE=$(node -e "console.log(JSON.parse(require('fs').readFileSync('todays-trips.json','utf8')).date)")
TODAY=$(date +%Y-%m-%d)

if [ "$DATE" != "$TODAY" ]; then
    echo "Reseplanen är inaktuell ($DATE, idag $TODAY)." >> logs/daily-trips.log
    exit 1
fi

pkill -f 'node.*tracking-service.js.*track' 2>/dev/null || true

nohup node -e "
const fs = require('fs');
const { spawn } = require('child_process');
const plan = JSON.parse(fs.readFileSync('todays-trips.json','utf8'));
const now = Date.now();
let count = 0;
for (const up of plan.users) {
    for (const trip of up.trips) {
        const [h, m] = trip.time.split(':').map(Number);
        const d = new Date(); d.setHours(h, m, 0, 0);
        const trackAt = d.getTime() - 10*60000;
        const checkAt = d.getTime() - 60*60000;
        const logTime = trip.time.replace(':','');
        const log = (msg) => console.log('['+new Date().toLocaleString('sv-SE')+'] '+msg);
        if (checkAt > now) {
            const delay = Math.round((checkAt - now) / 60000);
            log('Kontroll av '+trip.time+' om '+delay+' min');
            setTimeout(() => {
                log('Kontrollerar '+trip.time+'...');
                spawn('node', ['tracking-service.js','check',up.userId,trip.url,trip.time], {
                    cwd: process.cwd(), stdio: ['ignore',
                        fs.openSync('logs/trip-'+logTime+'-status.log','a'),
                        fs.openSync('logs/trip-'+logTime+'-status-error.log','a')
                    ]
                });
            }, checkAt - now);
        }
        if (trackAt > now) {
            const delay = Math.round((trackAt - now) / 60000);
            log('Spårning av '+trip.time+' om '+delay+' min');
            setTimeout(() => {
                log('Startar spårning av '+trip.time+'...');
                spawn('node', ['tracking-service.js','track',up.userId,trip.url,trip.time,String(trip.minutes)], {
                    cwd: process.cwd(), detached: true, stdio: ['ignore',
                        fs.openSync('logs/trip-'+logTime+'.log','a'),
                        fs.openSync('logs/trip-'+logTime+'-error.log','a')
                    ]
                }).unref();
            }, trackAt - now);
            count++;
        }
    }
}
console.log(count+' resor schemalagda.');
" >> logs/daily-trips.log 2>&1 &

disown

echo "Planering klar. Bakgrundsprocesser startade." >> logs/daily-trips.log