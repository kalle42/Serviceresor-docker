const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

require('./local-env').loadLocalEnvironment(__dirname);

const ROOT = __dirname;
const PLAN_FILE = path.join(ROOT, 'todays-trips.json');

function localDateKey(date = new Date()) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function log(msg) {
    console.log(`[scheduler] ${new Date().toLocaleString('sv-SE')} ${msg}`);
}

function runPlanner() {
    return new Promise((resolve, reject) => {
        log('Kör planeraren...');
        const child = spawn('node', ['tracking-service.js'], { cwd: ROOT, stdio: 'inherit' });
        child.on('close', (code) => {
            if (code === 0) resolve();
            else reject(new Error(`Planeraren avslutades med kod ${code}`));
        });
    });
}

function scheduleTrip(userId, url, time, minutes) {
    const now = Date.now();
    const [h, m] = time.split(':').map(Number);
    const d = new Date();
    d.setHours(h, m, 0, 0);

    const checkAt = d.getTime() - 60 * 60000;
    const trackAt = d.getTime() - 10 * 60000;
    const logTime = time.replace(':', '');

    if (checkAt > now) {
        const delay = checkAt - now;
        log(`Kontroll av ${time} om ${Math.round(delay / 60000)} min`);
        setTimeout(() => {
            log(`Kontrollerar om ${time} är bokad...`);
            const child = spawn('node', ['tracking-service.js', 'check', userId, url, time], {
                cwd: ROOT, stdio: ['ignore',
                    fs.openSync(path.join(ROOT, 'logs', `trip-${logTime}-status.log`), 'a'),
                    fs.openSync(path.join(ROOT, 'logs', `trip-${logTime}-status-error.log`), 'a')
                ]
            });
            child.on('close', (code) => {
                if (code === 10) log(`Resan ${time} är avbokad.`);
                else log(`Resan ${time} är fortfarande bokad.`);
            });
        }, delay);
    }

    if (trackAt > now) {
        const delay = trackAt - now;
        log(`Spårning av ${time} om ${Math.round(delay / 60000)} min`);
        setTimeout(() => {
            log(`Startar spårning av ${time}...`);
            spawn('node', ['tracking-service.js', 'track', userId, url, time, String(minutes)], {
                cwd: ROOT, detached: true, stdio: ['ignore',
                    fs.openSync(path.join(ROOT, 'logs', `trip-${logTime}.log`), 'a'),
                    fs.openSync(path.join(ROOT, 'logs', `trip-${logTime}-error.log`), 'a')
                ]
            }).unref();
        }, delay);
    }
}

async function scheduleTodaysTrips() {
    if (!fs.existsSync(PLAN_FILE)) {
        log('Ingen reseplan. Kör planeraren...');
        await runPlanner();
    }

    const plan = JSON.parse(fs.readFileSync(PLAN_FILE, 'utf8'));
    if (plan.date !== localDateKey()) {
        log('Reseplanen är inaktuell. Uppdaterar...');
        await runPlanner();
        return scheduleTodaysTrips();
    }

    let count = 0;
    for (const userPlan of plan.users) {
        for (const trip of userPlan.trips) {
            scheduleTrip(userPlan.userId, trip.url, trip.time, trip.minutes);
            count++;
        }
    }
    log(`${count} resor schemalagda.`);
}

function msUntilNext(checkHour, checkMinute) {
    const now = new Date();
    const target = new Date();
    target.setHours(checkHour, checkMinute, 0, 0);
    if (target <= now) target.setDate(target.getDate() + 1);
    return target.getTime() - now.getTime();
}

async function main() {
    fs.mkdirSync(path.join(ROOT, 'logs'), { recursive: true });
    log('Schemaläggare startad.');

    await scheduleTodaysTrips();

    const dailyDelay = msUntilNext(5, 0);
    log(`Nästa dagliga planering om ${Math.round(dailyDelay / 3600000)} timmar.`);
    setInterval(async () => {
        try {
            await scheduleTodaysTrips();
        } catch (error) {
            log(`Fel vid schemaläggning: ${error.message}`);
        }
    }, 24 * 60 * 60 * 1000);
}

main().catch((error) => {
    console.error('Schemaläggaren avslutades med fel:', error);
    process.exitCode = 1;
});