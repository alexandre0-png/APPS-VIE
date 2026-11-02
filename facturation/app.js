(function () {
  'use strict';
  const C = window.Calcul;

  const CLE_BROUILLON = 'facturation.brouillon.v1';
  const CLE_EMETTEUR = 'facturation.emetteur.v1';
  const CLE_NUMEROS = 'facturation.numeros.v1';

  const $ = function (sel) { return document.querySelector(sel); };
  const form = $('#formulaire');
  const feuille = $('#feuille');
  const avis = $('#avis');
  const lignesEl = $('#lignes');
  const tpl = $('#tpl-ligne');

  // ---------- Stockage local, toujours protégé ----------
  function lire(cle, defaut) {
    try {
      const v = localStorage.getItem(cle);
      return v ? JSON.parse(v) : defaut;
    } catch (e) {
      return defaut;
    }
  }
  function ecrire(cle, valeur) {
    try {
      localStorage.setItem(cle, JSON.stringify(valeur));
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------- Utilitaires ----------
  function dateLocale(d) {
    const p = function (n) { return String(n).padStart(2, '0'); };
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
  }
  function dateAffichee(iso) {
    if (!iso) return '';
    const d = new Date(iso + 'T12:00:00');
    if (isNaN(d)) return iso;
    return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  }
  function montrerAvis(message, genre) {
    avis.textContent = message || '';
    avis.className = 'avis' + (message ? ' visible ' + (genre || 'info') : '');
  }

  // ---------- Lignes ----------
  function ajouterLigne(donnees) {
    const noeud = tpl.content.firstElementChild.cloneNode(true);
    const d = donnees || {};
    noeud.querySelector('[data-champ="description"]').value = d.description || '';
    noeud.querySelector('[data-champ="qty"]').value = d.qty != null ? d.qty : '1';
    noeud.querySelector('[data-champ="unitPrice"]').value = d.unitPrice || '';
    noeud.querySelector('[data-champ="tvaRate"]').value = d.tvaRate != null ? String(d.tvaRate) : '20';
    lignesEl.appendChild(noeud);
    return noeud;
  }
  function lireLignes() {
    return Array.prototype.map.call(lignesEl.querySelectorAll('.ligne'), function (l) {
      const v = function (c) { return l.querySelector('[data-champ="' + c + '"]').value; };
      return {
        description: v('description'),
        qty: v('qty').trim().replace(',', '.'),
        unitPrice: v('unitPrice'),
        tvaRate: parseFloat(v('tvaRate'))
      };
    });
  }

  // ---------- État du formulaire ----------
  function lireFormulaire() {
    const f = new FormData(form);
    const t = function (k) { return String(f.get(k) || '').trim(); };
    return {
      type: t('type') || 'facture',
      prefixe: t('prefixe'),
      date: t('date'),
      echeance: t('echeance'),
      emetteur: { nom: t('emetteurNom'), siret: t('siret'), email: t('emetteurEmail'), adresse: t('emetteurAdresse') },
      franchise: f.get('franchise') === 'on',
      client: { nom: t('clientNom'), adresse: t('clientAdresse') },
      paiement: t('paiement'),
      notes: t('notes'),
      lignes: lireLignes()
    };
  }

  function appliquerFormulaire(d) {
    if (!d) return;
    $('#type').value = d.type || 'facture';
    $('#prefixe').value = d.prefixe || 'FA';
    $('#date').value = d.date || dateLocale(new Date());
    $('#echeance').value = d.echeance || '';
    const e = d.emetteur || {};
    $('#emetteurNom').value = e.nom || '';
    $('#siret').value = e.siret || '';
    $('#emetteurEmail').value = e.email || '';
    $('#emetteurAdresse').value = e.adresse || '';
    $('#franchise').checked = !!d.franchise;
    const c = d.client || {};
    $('#clientNom').value = c.nom || '';
    $('#clientAdresse').value = c.adresse || '';
    $('#paiement').value = d.paiement || '';
    $('#notes').value = d.notes || '';
    lignesEl.innerHTML = '';
    (d.lignes && d.lignes.length ? d.lignes : [{}]).forEach(ajouterLigne);
  }

  function tauxFr(taux) { return String(taux).replace('.', ',') + ' %'; }

  // ---------- Aperçu (construit sans innerHTML pour éviter toute injection) ----------
  function el(tag, classe, texte) {
    const n = document.createElement(tag);
    if (classe) n.className = classe;
    if (texte != null) n.textContent = texte;
    return n;
  }
  function ligneTotal(libelle, valeur, classe) {
    const d = el('div', classe || '');
    d.appendChild(el('span', '', libelle));
    d.appendChild(el('span', '', valeur));
    return d;
  }

  function rendreApercu(d, numero, totaux, erreur) {
    feuille.textContent = '';
    if (erreur) {
      feuille.appendChild(el('p', 'vide', erreur));
      return;
    }
    const titre = d.type === 'devis' ? 'Devis' : 'Facture';
    const tete = el('div', 'deux');
    const gauche = el('div');
    gauche.appendChild(el('h3', '', titre));
    gauche.appendChild(el('div', 'discret', numero || 'Numéro attribué à la finalisation'));
    const droite = el('div');
    droite.style.textAlign = 'right';
    droite.appendChild(el('div', '', 'Émise le ' + (dateAffichee(d.date) || '—')));
    if (d.echeance) droite.appendChild(el('div', '', 'Échéance : ' + dateAffichee(d.echeance)));
    if (!numero) droite.appendChild(el('span', 'statut', 'Brouillon'));
    tete.appendChild(gauche);
    tete.appendChild(droite);
    feuille.appendChild(tete);

    const emet = el('div', 'deux');
    emet.style.marginTop = '26px';
    const bloc1 = el('div', 'bloc-adresse');
    bloc1.appendChild(el('strong', '', d.emetteur.nom || 'Votre nom'));
    bloc1.appendChild(document.createTextNode('\n' + [d.emetteur.adresse, d.emetteur.siret ? 'SIRET : ' + d.emetteur.siret : '', d.emetteur.email].filter(Boolean).join('\n')));
    const bloc2 = el('div', 'bloc-adresse');
    bloc2.appendChild(el('strong', 'discret', 'Destinataire'));
    bloc2.appendChild(document.createTextNode('\n' + [d.client.nom, d.client.adresse].filter(Boolean).join('\n')));
    emet.appendChild(bloc1);
    emet.appendChild(bloc2);
    feuille.appendChild(emet);

    const table = el('table');
    const thead = el('thead');
    const trh = el('tr');
    ['Description', 'Qté', 'PU HT', 'TVA', 'Total HT'].forEach(function (h, i) {
      const th = el('th', i > 0 ? 'num' : '', h);
      trh.appendChild(th);
    });
    thead.appendChild(trh);
    table.appendChild(thead);
    const tbody = el('tbody');
    totaux.lines.forEach(function (l) {
      const tr = el('tr');
      tr.appendChild(el('td', '', l.description || '—'));
      tr.appendChild(el('td', 'num', String(l.qty).replace('.', ',')));
      tr.appendChild(el('td', 'num', C.formatEuros(l.unit)));
      tr.appendChild(el('td', 'num', tauxFr(l.rate)));
      tr.appendChild(el('td', 'num', C.formatEuros(l.ht)));
      tbody.appendChild(tr);
    });
    if (!totaux.lines.length) {
      const tr = el('tr');
      const td = el('td', 'vide', 'Aucune ligne');
      td.colSpan = 5;
      tr.appendChild(td);
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    feuille.appendChild(table);

    const tot = el('div', 'totaux');
    tot.appendChild(ligneTotal('Total HT', C.formatEuros(totaux.totalHT)));
    if (totaux.franchise) {
      tot.appendChild(ligneTotal('TVA', 'Non applicable'));
    } else {
      totaux.byRate.forEach(function (r) {
        tot.appendChild(ligneTotal('TVA ' + tauxFr(r.rate), C.formatEuros(r.tva)));
      });
    }
    tot.appendChild(ligneTotal('Total TTC', C.formatEuros(totaux.totalTTC), 'ttc'));
    feuille.appendChild(tot);

    const pied = [];
    if (d.paiement) pied.push('Paiement : ' + d.paiement);
    if (d.notes) pied.push(d.notes);
    if (d.type === 'facture') {
      if (totaux.franchise) pied.push(C.MENTIONS.franchise);
      pied.push(C.MENTIONS.penalites);
      pied.push(C.MENTIONS.indemnite);
    }
    if (pied.length) feuille.appendChild(el('div', 'pied-facture', pied.join('\n')));
  }

  // ---------- Validation et calcul ----------
  function calculer(d) {
    const erreurs = [];
    if (!d.emetteur.nom) erreurs.push('Renseignez votre nom ou raison sociale.');
    if (d.emetteur.siret && !/^\d{14}$/.test(d.emetteur.siret.replace(/\s/g, ''))) {
      erreurs.push('Le SIRET doit comporter 14 chiffres.');
    }
    if (!d.client.nom) erreurs.push('Renseignez le nom du client.');
    if (!d.date) erreurs.push('Renseignez la date d’émission.');
    if (!d.lignes.length) erreurs.push('Ajoutez au moins une ligne.');
    let totaux = null;
    try {
      totaux = C.computeInvoice(d.lignes, { franchise: d.franchise });
      d.lignes.forEach(function (l, i) {
        if (!l.description) erreurs.push('Ligne ' + (i + 1) + " : ajoutez une description.");
      });
    } catch (e) {
      erreurs.push('Vérifiez quantités et prix : ' + e.message + '.');
    }
    return { erreurs: erreurs, totaux: totaux };
  }

  // ---------- Rendu principal ----------
  function rafraichir() {
    const d = lireFormulaire();
    const { erreurs, totaux } = calculer(d);
    montrerAvis(erreurs.length ? erreurs.join(' ') : '', 'erreur');
    ecrire(CLE_BROUILLON, d);
    if (d.emetteur.nom || d.emetteur.siret || d.emetteur.adresse || d.emetteur.email) {
      ecrire(CLE_EMETTEUR, d.emetteur);
    }
    if (!totaux || !d.lignes.length) {
      rendreApercu(d, null, totaux || { lines: [], byRate: [], totalHT: 0, totalTVA: 0, totalTTC: 0, franchise: d.franchise }, 'Ajoutez une ligne pour voir l’aperçu.');
      return;
    }
    rendreApercu(d, null, totaux, null);
  }

  // ---------- Finalisation ----------
  function finaliser() {
    const d = lireFormulaire();
    const { erreurs, totaux } = calculer(d);
    if (erreurs.length || !totaux) {
      montrerAvis(erreurs.join(' ') || 'Le document est incomplet.', 'erreur');
      return;
    }
    const annee = new Date(d.date + 'T12:00:00').getFullYear();
    const etat = lire(CLE_NUMEROS, {});
    const cle = d.type + '-' + (d.prefixe || 'FA');
    const suivant = C.prochaineSequence(etat[cle], annee);
    const numero = C.formatNumero(d.prefixe, suivant.year, suivant.seq);

    // La séquence est enregistrée avant l’impression : un numéro sorti n’est jamais réattribué.
    etat[cle] = suivant;
    if (!ecrire(CLE_NUMEROS, etat)) {
      montrerAvis('Impossible d’enregistrer la numérotation dans ce navigateur. Document non finalisé.', 'erreur');
      return;
    }
    rendreApercu(d, numero, totaux, null);
    montrerAvis('Document finalisé : ' + numero + '. Choisissez « Enregistrer au format PDF ».', 'info');
    window.print();
  }

  // ---------- Événements ----------
  form.addEventListener('input', rafraichir);
  form.addEventListener('change', rafraichir);

  lignesEl.addEventListener('click', function (e) {
    const bouton = e.target.closest('.retirer');
    if (!bouton) return;
    const ligne = bouton.closest('.ligne');
    if (lignesEl.querySelectorAll('.ligne').length > 1) {
      ligne.remove();
    } else {
      ligne.querySelectorAll('input').forEach(function (i) { i.value = ''; });
      ligne.querySelector('[data-champ="qty"]').value = '1';
    }
    rafraichir();
  });

  $('#ajouter').addEventListener('click', function () {
    const l = ajouterLigne({});
    l.querySelector('[data-champ="description"]').focus();
    rafraichir();
  });

  $('#finaliser').addEventListener('click', finaliser);

  $('#reinitialiser').addEventListener('click', function () {
    if (!window.confirm('Commencer un nouveau document ? Le brouillon actuel sera effacé.')) return;
    try { localStorage.removeItem(CLE_BROUILLON); } catch (e) { /* stockage indisponible */ }
    const emetteur = lire(CLE_EMETTEUR, null);
    appliquerFormulaire({ emetteur: emetteur || {}, date: dateLocale(new Date()), prefixe: $('#prefixe').value || 'FA', lignes: [{}] });
    rafraichir();
  });

  // ---------- Démarrage ----------
  (function init() {
    const brouillon = lire(CLE_BROUILLON, null);
    const emetteur = lire(CLE_EMETTEUR, null);
    if (brouillon) {
      appliquerFormulaire(brouillon);
    } else {
      appliquerFormulaire({
        emetteur: emetteur || {},
        date: dateLocale(new Date()),
        echeance: dateLocale(new Date(Date.now() + 30 * 86400000)),
        prefixe: 'FA',
        lignes: [{}]
      });
    }
    rafraichir();
  })();
})();
