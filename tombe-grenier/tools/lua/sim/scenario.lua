local function check(cond, label)
  if not cond then error("ÉCHEC : " .. label, 2) end
  print("ok  " .. label)
end
local function find(list, pat)
  for _, t in ipairs(list) do
    local a, b = string.match(t, pat)
    if a then return a, b or true end
  end
  return nil
end

local Quests = require({ __path = "src/server/Quests.lua" })
local Locks = require({ __path = "src/server/Locks.lua" })

-- Monde : une seule maison simulée avec les points nécessaires
local function build()
  H.tagged = {}
  for k in pairs(H.tagged) do H.tagged[k] = nil end
end
local function world()
  local tagged = {}
  local parts = {}
  local function add(tag, x, y, z, name, attrs)
    local p = H.part(tag, x, y, z, name)
    for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
    parts[#parts + 1] = p
    return p
  end
  local w = {}
  w.note = add("CodeNote", 10, 0, 10, "papier")
  w.coffret = add("Coffret", 95, 27, 73, "coffret")
  w.chest = add("Chest", 70, 27, 60, "malle")
  w.tomb = add("Tombe", 90, 26, 42, "cercueil")
  w.mirror = add("Mirror", 119, 31, 30, "miroir")
  w.box = add("MusicBox", 20, 0, 20, "boîte")
  w.books = {}
  for i = 1, 6 do w.books[i] = add("Livre", 40 + i, 1, 5, "livre " .. i) end
  w.statues = {}
  for i = 1, 3 do w.statues[i] = add("Statue", 2 + 30 * i, 1, 2, "statue " .. i) end
  w.docs = {}
  for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
    w.docs[kind] = add("Interactable", 30, 1, 30, kind, { Kind = kind })
  end
  w.gramophone = add("Interactable", 25, 1, 25, "gramophone", { Kind = "gramophone ancien" })
  w.respire = add("Respire", 38, 1, 36, "mur")
  w.mannequin = add("Mannequin", 42, 13, 46, "mannequin")
  w.horloge = add("Horloge", 60, 4.5, 1.1, "horloge du hall")
  w.etiquette = add("Interactable", 118, 3, 14, "étiquette de la réserve", { Kind = "étiquette de la réserve" })
  w.compteur = add("Compteur", 118, 3, 30, "compteur de la cuisine")
  return w
end
local w = world()
local alice = H.player("Alice", 95, 27, 73)
H.players = { alice }

local function root(p) return p.Character:FindFirstChild("HumanoidRootPart") end
local function moveTo(p, x, y, z) root(p).Position = H.v3(x, y, z) end

-- 1. Installation de la partie : aucune erreur d'exécution
Quests.setup(12345)
Quests.init(function(reason) H.endReason = reason end)
check(true, "setup + init s'exécutent")

-- 2. Papier, miroir et coffret : le code se reconstitue et ouvre le coffret
H.log = {}
H.trigger(w.note, "QuestPrompt", alice)
local prefix = find(H.msgs(alice), "chiffres : (%d%d)%.")
check(prefix ~= nil, "le papier donne deux chiffres")
H.log = {}
H.trigger(w.mirror, "QuestPromptReflet", alice)
local shown = find(H.msgs(alice), "« (%d%d) »")
check(shown ~= nil, "le miroir montre deux chiffres à l'envers")
local last2 = string.reverse(shown)
local code = prefix .. last2
H.log = {}
local wrong = (code == "0000") and "1111" or "0000"
Quests.submitCode(alice, wrong)
check(find(H.msgs(alice), "(Ce n'est pas le bon code)") ~= nil, "mauvais code refusé")
H.log = {}
Quests.submitCode(alice, code)
check(find(H.msgs(alice), "(Le couvercle se soulève)") ~= nil, "le bon code ouvre le coffret")

-- 3. Gramophone puis boîte à musique : la mélodie se rejoue
H.log = {}
H.trigger(w.gramophone, "QuestPrompt", alice)
local melodyText = find(H.msgs(alice), "trois notes : ([^%.]+)%.")
check(melodyText ~= nil, "le gramophone donne sa mélodie")
local names = { ["do"] = 1, ["ré"] = 2, ["mi"] = 3, ["sol"] = 4 }
local notes = {}
for n in string.gmatch(melodyText, "[^,%s]+") do notes[#notes + 1] = names[n] end
check(#notes == 3, "trois notes lues")
for _, idx in ipairs(notes) do H.trigger(w.box, "QuestPromptNote" .. idx, alice) end
check(Locks.isOpen("salle de bain"), "la mélodie complète ouvre la salle de bain")

-- 4. Bibliothèque : marque-pages dans l'ordre, puis mauvais ordre
Quests.setup(777)
local marked = {}
for _, b in ipairs(w.books) do
  local m = b:GetAttribute("Mark")
  if m then marked[m] = b end
end
check(marked[1] and marked[2] and marked[3], "trois marque-pages posés")
H.log = {}
H.trigger(marked[2], "QuestPromptLivre", alice)
check(find(H.msgs(alice), "(se mélangent)") ~= nil, "mauvais ordre réinitialise")
for i = 1, 3 do H.trigger(marked[i], "QuestPromptLivre", alice) end
check(H.lastObjective() == "Ouvre la malle du grenier", "petite clé par la bibliothèque : objectif passe à la malle")

-- 5. Statues : une orientation par statue, tirée par la seed (on retrouve une solution)
local found = nil
for a = 0, 3 do for b = 0, 3 do for c = 0, 3 do
  Quests.setup(999)
  H.log = {}
  local combo = { a, b, c }
  for i = 1, 3 do
    for _ = 1, combo[i] do H.trigger(w.statues[i], "QuestPromptStatue", alice) end
  end
  if find(H.msgs(alice), "(Les trois statues se figent)") then found = combo end
end end end
check(found ~= nil, "les statues ont une solution")

-- 6. Mur qui respire : refusé avant les statues, pile après
Quests.setup(999)
H.log = {}
H.trigger(w.respire, "QuestPromptRespire", alice)
check(find(H.msgs(alice), "(Rien ne se passe)") ~= nil, "mur muet avant les statues")

-- 7. Documents, date de la plaque et fin vérité
Quests.setup(12345)
H.endReason = nil
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
  H.trigger(w.docs[kind], "QuestPrompt", alice)
end
local plaqueDate = nil
H.log = {}
H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
plaqueDate = find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)")
check(plaqueDate ~= nil, "la plaque donne une date")
moveTo(alice, 90, 26, 43)
H.log = {}
H.trigger(w.tomb, "QuestPrompt", alice)
check(find(H.msgs(alice), "(Entre%-la au clavier)") ~= nil, "le cercueil demande la date")
H.log = {}
Quests.submitCode(alice, "1111")
check(find(H.msgs(alice), "(Ce n'est pas la date gravée)") ~= nil, "mauvaise date refusée")
Quests.onFreed = function() H.freed = true end
local mm, dd = string.match(plaqueDate, "(%d%d)/(%d%d)")
Quests.submitCode(alice, mm .. dd)
check(H.freed == true and H.endReason == nil, "bonne date : enfant libéré, la partie continue")

-- 7sexies. Fin 4 (piège) : la date du cahier, fausse, scelle le cercueil
Quests.setup(12345)
H.endReason = nil
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
  H.trigger(w.docs[kind], "QuestPrompt", alice)
end
H.log = {}
H.trigger(w.docs["cahier d'écolier"], "QuestPrompt", alice)
local wrongMM, wrongDD = string.match(find(H.msgs(alice), "En marge, une date : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
H.log = {}
H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
local plaqueMM, plaqueDD = string.match(find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
check(plaqueMM ~= nil and (plaqueMM .. plaqueDD) ~= (wrongMM or "") .. (wrongDD or ""), "la plaque donne la date juste, lisible avant le cercueil")
check(wrongMM ~= nil, "le cahier donne une date fausse")
moveTo(alice, 90, 26, 43)
H.trigger(w.tomb, "QuestPrompt", alice)
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == nil, "une seule saisie de la date du cahier ne scelle pas (avertissement)")
check(find(H.msgs(alice), "(Tu ne pourras pas revenir en arrière)") ~= nil, "avertissement affiché avant confirmation")
Quests.submitCode(alice, "1111")
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == nil, "une saisie différente entre-temps annule l'armement")
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == "sealed", "la date du cahier confirmée scelle le cercueil (fin 4)")
check(string.find(Quests.endingText("sealed"), "/4%.") ~= nil, "le total des fins compte 4")

-- 7bis. Indication à la demande : une fois, puis limitée par le délai
Quests.setup(12345)
H.log = {}
Quests.hintFor(alice)
local hintSent = false
for _, e in ipairs(H.log) do if e.name == "Hint" and e.payload.text then hintSent = true end end
check(hintSent, "la touche H envoie une indication")
H.log = {}
Quests.hintFor(alice)
local hintAgain = false
for _, e in ipairs(H.log) do if e.name == "Hint" then hintAgain = true end end
check(not hintAgain and find(H.msgs(alice), "(Attends)") ~= nil, "indication limitée par le délai")

-- 7ter. Progression V2 : l'horloge du hall se règle avec la date de la plaque, pour chaque graine
local function solveHorloge(seed)
  Quests.setup(seed)
  H.log = {}
  H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
  local mm, dd = string.match(find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
  if not mm then return false, "plaque illisible" end
  H.log = {}
  H.trigger(w.horloge, "QuestPromptHorloge", alice)
  if find(H.msgs(alice), "(Entre la date de la plaque)") == nil then return false, "horloge muette" end
  H.log = {}
  Quests.submitCode(alice, "1111")
  if find(H.msgs(alice), "(ne bougent pas)") == nil then return false, "mauvaise date acceptée" end
  H.log = {}
  Quests.submitCode(alice, mm .. dd)
  if find(H.msgs(alice), "(se remet en marche)") == nil then return false, "bonne date refusée" end
  if H.lastObjective() == "Règle l'horloge du hall sur la date gravée sur la plaque du cercueil" then return false, "objectif non avancé" end
  return true
end
local okH, whyH = solveHorloge(12345)
check(okH, "horloge résolue avec la date de la plaque" .. (whyH and (" (" .. whyH .. ")") or ""))
for seed = 1, 60 do
  local ok, why = solveHorloge(seed)
  check(ok, ("horloge solvable, graine %d%s"):format(seed, why and (" : " .. why) or ""))
end

-- 7quater. Progression d'origine (ProgressionV2 = false) : l'horloge n'existe pas dans l'enchaînement
local Config = require({ __path = "src/shared/Config.lua" })
Config.Design.ProgressionV2 = false
for seed = 1, 60 do
  Quests.setup(seed)
  H.log = {}
  H.trigger(w.horloge, "QuestPromptHorloge", alice)
  check(find(H.msgs(alice), "(Entre la date de la plaque)") == nil, ("V1 : horloge inerte, graine %d"):format(seed))
  check(H.lastObjective() ~= "Règle l'horloge du hall sur la date gravée sur la plaque du cercueil", ("V1 : pas d'objectif horloge, graine %d"):format(seed))
  H.log = {}
  Quests.submitCode(alice, "0000")
  check(find(H.msgs(alice), "(ne bougent pas)") == nil, ("V1 : pas de saisie d'horloge, graine %d"):format(seed))
end
Config.Design.ProgressionV2 = true

-- 7quinquies. Énigme optionnelle de la cuisine : l'étiquette donne le code, le compteur l'accepte, une pile à la clé
local function solveCompteur(seed)
  Quests.setup(seed)
  H.log = {}
  H.trigger(w.etiquette, "QuestPromptEtiquette", alice)
  local digits = string.match(find(H.msgs(alice), "Réserve — (%d%d%d)") or "", "(%d%d%d)")
  if not digits then return false, "étiquette illisible" end
  H.log = {}
  H.trigger(w.compteur, "QuestPromptCompteur", alice)
  if find(H.msgs(alice), "(Trois chiffres)") == nil then return false, "compteur muet" end
  H.log = {}
  Quests.submitCode(alice, "9999" == digits and "1234" or "9999")
  if find(H.msgs(alice), "(pile neuve)") ~= nil then return false, "mauvais code accepté" end
  H.log = {}
  Quests.submitCode(alice, digits)
  if find(H.msgs(alice), "(pile neuve)") == nil then return false, "bon code refusé" end
  return true
end
local okC, whyC = solveCompteur(12345)
check(okC, "compteur de la cuisine résolu" .. (whyC and (" (" .. whyC .. ")") or ""))
for seed = 1, 60 do
  local ok, why = solveCompteur(seed)
  check(ok, ("compteur solvable, graine %d%s"):format(seed, why and (" : " .. why) or ""))
end

-- 8. Robustesse : toutes les graines de la partie tiennent sans erreur
for seed = 1, 60 do Quests.setup(seed) end
check(true, "60 graines sans erreur")
print("TOUT PASSE")
