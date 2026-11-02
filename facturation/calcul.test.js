'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('./calcul.js');

const espaces = (s) => s.replace(/[  ]/g, ' ');

test('eurosToCents convertit les saisies françaises sans erreur de flottant', () => {
  assert.equal(C.eurosToCents('12,50'), 1250);
  assert.equal(C.eurosToCents('1 000,05'), 100005);
  assert.equal(C.eurosToCents(0.1 + 0.2), 30);
  assert.equal(C.eurosToCents(1.005), 101);
  assert.equal(C.eurosToCents(''), 0);
});

test('eurosToCents refuse les montants à plus de deux décimales ou non numériques', () => {
  assert.throws(() => C.eurosToCents('12.345'), TypeError);
  assert.throws(() => C.eurosToCents('abc'), TypeError);
  assert.throws(() => C.eurosToCents(NaN), TypeError);
});

test('computeInvoice calcule HT, TVA et TTC', () => {
  const r = C.computeInvoice([{ description: 'Prestation', qty: 2, unitPrice: '10,00', tvaRate: 20 }]);
  assert.equal(r.totalHT, 2000);
  assert.equal(r.totalTVA, 400);
  assert.equal(r.totalTTC, 2400);
});

test('computeInvoice arrondit au centime par ligne', () => {
  // 3 x 0,33 = 0,99 HT ; TVA 20 % de 99 centimes = 19,8 -> 20 centimes
  const r = C.computeInvoice([{ description: 'x', qty: 3, unitPrice: '0,33', tvaRate: 20 }]);
  assert.equal(r.lines[0].ht, 99);
  assert.equal(r.lines[0].tva, 20);
  assert.equal(r.totalTTC, 119);
});

test('computeInvoice accepte une quantité décimale', () => {
  const r = C.computeInvoice([{ description: 'Heures', qty: 1.5, unitPrice: '40', tvaRate: 20 }]);
  assert.equal(r.totalHT, 6000);
});

test('computeInvoice regroupe la TVA par taux', () => {
  const r = C.computeInvoice([
    { description: 'a', qty: 1, unitPrice: '100', tvaRate: 20 },
    { description: 'b', qty: 1, unitPrice: '50', tvaRate: 5.5 },
    { description: 'c', qty: 1, unitPrice: '50', tvaRate: 20 }
  ]);
  assert.deepEqual(r.byRate, [
    { rate: 5.5, base: 5000, tva: 275 },
    { rate: 20, base: 15000, tva: 3000 }
  ]);
  assert.equal(r.totalTVA, 3275);
});

test('en franchise en base, la TVA est forcée à zéro', () => {
  const r = C.computeInvoice(
    [{ description: 'x', qty: 1, unitPrice: '100', tvaRate: 20 }],
    { franchise: true }
  );
  assert.equal(r.totalTVA, 0);
  assert.equal(r.totalTTC, 10000);
  assert.equal(r.franchise, true);
});

test('computeInvoice rejette quantité nulle ou taux inconnu', () => {
  assert.throws(() => C.computeInvoice([{ description: 'x', qty: 0, unitPrice: '1', tvaRate: 20 }]), RangeError);
  assert.throws(() => C.computeInvoice([{ description: 'x', qty: 1, unitPrice: '1', tvaRate: 19.6 }]), RangeError);
});

test('une facture vide donne des totaux nuls', () => {
  const r = C.computeInvoice([]);
  assert.equal(r.totalTTC, 0);
  assert.deepEqual(r.byRate, []);
});

test('formatNumero produit un numéro sur quatre chiffres', () => {
  assert.equal(C.formatNumero('fa', 2026, 3), 'FA-2026-0003');
  assert.equal(C.formatNumero('', 2026, 12), 'FA-2026-0012');
  assert.equal(C.formatNumero('ab c!', 2026, 1234), 'ABC-2026-1234');
});

test('prochaineSequence incrémente dans l’année et repart à 1 au changement d’année', () => {
  assert.deepEqual(C.prochaineSequence(null, 2026), { year: 2026, seq: 1 });
  assert.deepEqual(C.prochaineSequence({ year: 2026, seq: 8 }, 2026), { year: 2026, seq: 9 });
  assert.deepEqual(C.prochaineSequence({ year: 2025, seq: 7 }, 2026), { year: 2026, seq: 1 });
});

test('formatEuros utilise le format français', () => {
  assert.equal(espaces(C.formatEuros(123456)), '1 234,56 €');
  assert.equal(espaces(C.formatEuros(-50)), '-0,50 €');
});
