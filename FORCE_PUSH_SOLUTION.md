# 🔄 Force Push - Résolution

Erreur : `! [rejected] main -> main (stale info)`

**Cause** : `git filter-branch` a reecrit l'historique localement, mais GitHub a une version obsolète en cache.

---

## ✅ Solution immédiate

### Copier-coller ces commandes :

```bash
cd /workspaces/MASLIVE

# 1. Mettre à jour les infos GitHub
git fetch origin

# 2. Force push (écrase l'historique GitHub)
git push --force origin main
```

Ou exécuter le script :
```bash
bash /workspaces/MASLIVE/force_push_now.sh
```

---

## ✅ Vérifier que c'est ok

```bash
# Vérifier les commits locaux
git log --oneline -5

# Vérifier sur GitHub
git log --oneline -5 origin/main

# Ils doivent afficher les mêmes commits avec les mêmes IDs
```

---

## 📢 Notifier les collaborateurs

Si d'autres travaillent sur le projet :

```bash
# Ils doivent faire :
git pull --rebase

# Ou si ça fail :
git fetch origin
git reset --hard origin/main
git pull
```

---

## 🚀 Après force push réussi

```bash
cd /workspaces/MASLIVE/app
flutter clean
flutter pub get
flutter build web --release

cd ..
firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
```

---

## 🔐 Vérifier que la clé a disparu

```bash
# Chercher la clé dans l'historique
git log -p | grep -i "sk_test_" | head -5

# Ne rien afficher = succès ✅
```

---

## ⚠️ Si le force push échoue encore

```bash
# Option 1: Vérifier le statut
git status

# Option 2: Réinitialiser complètement
git fetch origin
git reset --hard HEAD

# Option 3: Vérifier qu'on est bien sur main
git branch -a

# Option 4: Débloquer via GitHub (voir UNLOCK_GITHUB_PUSH.md)
# Puis retenter : git push origin main (sans force)
```
