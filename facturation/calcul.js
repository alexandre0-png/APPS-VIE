/*
 * Calculs de facturation. Aucune dépendance, aucun accès au DOM.
 * Tous les montants internes sont en centimes (entiers) pour éviter les erreurs de flottants.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  } else {
    root.Calcul = api;
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // Taux de TVA français applicables (en %).
  const TAUX_VALIDES = [0, 2.1, 5.5, 10, 20];

  // Montant saisi (nombre ou texte "1 234,56") vers centimes entiers.
  function eurosToCents(valeur) {
    if (typeof valeur === 'number') {
      if (!Number.isFinite(valeur)) throw new TypeError('Montant invalide');
      return Math.round(Number((valeur * 100).toFixed(6)));
    }
    const texte = String(valeur ?? '').trim().replace(/\s/g, '').replace(',', '.');
    if (texte === '') return 0;
    if (!/^-?\d+(\.\d{1,2})?$/.test(texte)) {
      throw new TypeError('Montant invalide : ' + valeur);
    }
    return Math.round(parseFloat(texte) * 100);
  }

  // Calcule les lignes, la TVA par taux et les totaux.
  // lignes : [{ description, qty, unitPrice, tvaRate }]
  // options : { franchise: boolean } — en franchise en base, la TVA est 0 et non facturée.
  function computeInvoice(lignes, options) {
    const franchise = !!(options && options.franchise);
    const calculees = (lignes || []).map(function (l) {
      const qty = Number(l.qty);
      if (!Number.isFinite(qty) || qty <= 0) throw new RangeError('Quantité invalide');
      const unit = eurosToCents(l.unitPrice);
      const rate = franchise ? 0 : Number(l.tvaRate ?? 20);
      if (!TAUX_VALIDES.includes(rate)) throw new RangeError('Taux de TVA invalide : ' + rate);
      const ht = Math.round(qty * unit);
      const tva = Math.round((ht * rate) / 100);
      return {
        description: String(l.description || '').trim(),
        qty: qty,
        unit: unit,
        rate: rate,
        ht: ht,
        tva: tva,
        ttc: ht + tva
      };
    });

    const parTaux = {};
    calculees.forEach(function (l) {
      if (!parTaux[l.rate]) parTaux[l.rate] = { rate: l.rate, base: 0, tva: 0 };
      parTaux[l.rate].base += l.ht;
      parTaux[l.rate].tva += l.tva;
    });
    const byRate = Object.keys(parTaux)
      .map(Number)
      .sort(function (a, b) { return a - b; })
      .map(function (r) { return parTaux[r]; });

    const totalHT = calculees.reduce(function (s, l) { return s + l.ht; }, 0);
    const totalTVA = calculees.reduce(function (s, l) { return s + l.tva; }, 0);

    return {
      lines: calculees,
      byRate: byRate,
      totalHT: totalHT,
      totalTVA: totalTVA,
      totalTTC: totalHT + totalTVA,
      franchise: franchise
    };
  }

  // Numéro de type FA-2026-0001 : préfixe alphanumérique, année, séquence sur 4 chiffres.
  function formatNumero(prefixe, annee, seq) {
    const p = String(prefixe || 'FA').trim().toUpperCase().replace(/[^A-Z0-9-]/g, '') || 'FA';
    return p + '-' + annee + '-' + String(seq).padStart(4, '0');
  }

  // Séquence suivante. Remise à 1 au changement d'année, sans jamais réutiliser un numéro.
  // etat : { year, seq } ou null
  function prochaineSequence(etat, annee) {
    const dernier = etat && etat.year === annee ? etat.seq : 0;
    return { year: annee, seq: dernier + 1 };
  }

  // Centimes vers texte "1 234,56 €" (fr-FR).
  function formatEuros(cents) {
    const signe = cents < 0 ? '-' : '';
    const texte = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' })
      .format(Math.abs(cents) / 100);
    return signe + texte;
  }

  // Mentions obligatoires selon la situation. Textes à faire valider avant usage professionnel.
  const MENTIONS = {
    franchise: 'TVA non applicable, art. 293 B du CGI.',
    penalites: 'En cas de retard de paiement, pénalités exigibles au taux de trois fois le taux d’intérêt légal.',
    indemnite: 'Indemnité forfaitaire pour frais de recouvrement en cas de retard de paiement : 40 €.'
  };

  return {
    TAUX_VALIDES: TAUX_VALIDES,
    MENTIONS: MENTIONS,
    eurosToCents: eurosToCents,
    computeInvoice: computeInvoice,
    formatNumero: formatNumero,
    prochaineSequence: prochaineSequence,
    formatEuros: formatEuros
  };
});
