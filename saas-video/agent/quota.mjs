// Gestion des quotas en secondes et du plafond quotidien.
// Le store est en mémoire ici ; en production, remplacer par une table Postgres (Supabase).
import { PLANS } from './config.mjs';

export class QuotaError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

export class InMemoryUsageStore {
  constructor() { this.users = new Map(); }

  get(userId) {
    if (!this.users.has(userId)) {
      this.users.set(userId, { month: null, seconds: {}, day: null, count: 0 });
    }
    return this.users.get(userId);
  }
}

const monthKey = (d) => `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}`;
const dayKey = (d) => `${monthKey(d)}-${d.getUTCDate()}`;

export class QuotaManager {
  constructor({ store = new InMemoryUsageStore(), now = () => new Date() } = {}) {
    this.store = store;
    this.now = now;
  }

  remaining(userId, plan) {
    const cfg = PLANS[plan];
    if (!cfg) throw new QuotaError('unknown_plan', `Offre inconnue : ${plan}`);
    const u = this.#current(userId);
    const out = {};
    for (const [tier, max] of Object.entries(cfg.quota)) {
      out[tier] = Math.max(0, max - (u.seconds[tier] || 0));
    }
    return { seconds: out, generationsToday: u.count, maxPerDay: cfg.maxPerDay };
  }

  // Vérifie sans consommer. Lève QuotaError si la demande dépasse le quota.
  check(userId, plan, tier, seconds) {
    const cfg = PLANS[plan];
    if (!cfg) throw new QuotaError('unknown_plan', `Offre inconnue : ${plan}`);
    if (!(tier in cfg.quota)) {
      throw new QuotaError('tier_not_in_plan', `Le tier « ${tier} » n'est pas inclus dans l'offre ${plan}.`);
    }
    const u = this.#current(userId);
    if (u.count >= cfg.maxPerDay) {
      throw new QuotaError('daily_cap', `Plafond quotidien atteint (${cfg.maxPerDay} générations).`);
    }
    const left = cfg.quota[tier] - (u.seconds[tier] || 0);
    if (seconds > left) {
      throw new QuotaError('quota_exceeded', `Quota ${tier} insuffisant : ${left} s restantes, ${seconds} s demandées.`);
    }
  }

  // Consomme après une génération réussie.
  consume(userId, tier, seconds) {
    const u = this.#current(userId);
    u.seconds[tier] = (u.seconds[tier] || 0) + seconds;
    u.count += 1;
  }

  #current(userId) {
    const d = this.now();
    const u = this.store.get(userId);
    if (u.month !== monthKey(d)) { u.month = monthKey(d); u.seconds = {}; }
    if (u.day !== dayKey(d)) { u.day = dayKey(d); u.count = 0; }
    return u;
  }
}
