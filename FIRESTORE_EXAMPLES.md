# 📝 Exemples de données Firestore pour Media Galleries

## Structure complète d'un document

```json
{
  "title": "Carnaval Pointe-à-Pitre 2026",
  "subtitle": "Défilé principal - Groupe Akiyo",
  "coverUrl": "https://storage.googleapis.com/maslive.appspot.com/galleries/akiyo-2026/cover.jpg",
  "images": [
    "https://storage.googleapis.com/maslive.appspot.com/galleries/akiyo-2026/photo1.jpg",
    "https://storage.googleapis.com/maslive.appspot.com/galleries/akiyo-2026/photo2.jpg",
    "https://storage.googleapis.com/maslive.appspot.com/galleries/akiyo-2026/photo3.jpg"
  ],
  "photoCount": 45,
  
  "country": "Guadeloupe",
  "date": "2026-02-02T10:00:00.000Z",
  "eventName": "Défilé Pointe-à-Pitre",
  "groupName": "Akiyo",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0,
  
  "groupId": "akiyo",
  "createdAt": "2026-01-23T14:30:00.000Z",
  "updatedAt": "2026-01-23T14:30:00.000Z",
  
  "isPublished": true,
  "views": 0,
  "downloads": 0
}
```

## Exemples par pays

### 🇬🇵 Guadeloupe

```json
{
  "title": "Akiyo - Carnaval 2026",
  "subtitle": "Défilé des groupes à peau",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 52,
  "country": "Guadeloupe",
  "date": "2026-02-02T10:00:00.000Z",
  "eventName": "Défilé Pointe-à-Pitre",
  "groupName": "Akiyo",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0,
  "groupId": "akiyo",
  "createdAt": "2026-01-23T14:30:00.000Z"
}
```

```json
{
  "title": "Voukoum - Pré-carnaval",
  "subtitle": "Parade nocturne",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 38,
  "country": "Guadeloupe",
  "date": "2026-01-28T20:00:00.000Z",
  "eventName": "Pré-carnaval",
  "groupName": "Voukoum",
  "photographerName": "Mo Pictures",
  "pricePerPhoto": 10.0,
  "groupId": "voukoum",
  "createdAt": "2026-01-20T16:00:00.000Z"
}
```

```json
{
  "title": "Mass Moule - Dimanche Gras",
  "subtitle": "Grand défilé",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 67,
  "country": "Guadeloupe",
  "date": "2026-02-08T14:00:00.000Z",
  "eventName": "Dimanche Gras",
  "groupName": "Mass Moule",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0,
  "groupId": "mass-moule",
  "createdAt": "2026-02-09T10:00:00.000Z"
}
```

### 🇲🇶 Martinique

```json
{
  "title": "Tanbo - Carnaval FDF",
  "subtitle": "Défilé Fort-de-France",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 43,
  "country": "Martinique",
  "date": "2026-02-09T15:00:00.000Z",
  "eventName": "Carnaval Fort-de-France",
  "groupName": "Tanbo",
  "photographerName": "Léna Shots",
  "pricePerPhoto": 9.0,
  "groupId": "tanbo",
  "createdAt": "2026-02-10T09:00:00.000Z"
}
```

```json
{
  "title": "Vidé - Mardi Gras",
  "subtitle": "Grande parade finale",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 89,
  "country": "Martinique",
  "date": "2026-02-10T16:00:00.000Z",
  "eventName": "Vidé",
  "groupName": "Tanbo",
  "photographerName": "Léna Shots",
  "pricePerPhoto": 7.5,
  "groupId": "tanbo",
  "createdAt": "2026-02-11T11:00:00.000Z"
}
```

### 🇬🇫 Guyane

```json
{
  "title": "Touloulous - Carnaval Cayenne",
  "subtitle": "Nuit des Touloulous",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 56,
  "country": "Guyane",
  "date": "2026-02-05T21:00:00.000Z",
  "eventName": "Nuit des Touloulous",
  "groupName": "Ensemble Touloulous",
  "photographerName": "Jean-Marc Photos",
  "pricePerPhoto": 12.0,
  "groupId": "touloulous",
  "createdAt": "2026-02-06T08:00:00.000Z"
}
```

### 🇷🇪 Réunion

```json
{
  "title": "Carnaval Saint-Denis 2026",
  "subtitle": "Défilé des chars",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 74,
  "country": "Réunion",
  "date": "2026-02-15T14:00:00.000Z",
  "eventName": "Carnaval Saint-Denis",
  "groupName": "Groupe Zarlor",
  "photographerName": "Ti Photos 974",
  "pricePerPhoto": 8.5,
  "groupId": "zarlor",
  "createdAt": "2026-02-16T10:00:00.000Z"
}
```

### 🇫🇷 France métropolitaine

```json
{
  "title": "Paris Tropical Carnival",
  "subtitle": "Défilé des communautés",
  "coverUrl": "https://...",
  "images": ["https://...", "https://..."],
  "photoCount": 92,
  "country": "France",
  "date": "2026-02-14T13:00:00.000Z",
  "eventName": "Paris Tropical",
  "groupName": "Mix Antilles",
  "photographerName": "Studio Caraibes",
  "pricePerPhoto": 10.0,
  "groupId": "paris-tropical",
  "createdAt": "2026-02-15T09:00:00.000Z"
}
```

## Exemples par type d'événement

### Pré-carnaval

```json
{
  "title": "Ouverture Carnaval 2026",
  "subtitle": "Parade inaugurale",
  "photoCount": 35,
  "country": "Guadeloupe",
  "date": "2026-01-25T18:00:00.000Z",
  "eventName": "Pré-carnaval",
  "groupName": "Akiyo",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 6.0
}
```

### Dimanche Gras

```json
{
  "title": "Dimanche Gras - Grand défilé",
  "subtitle": "Tous les groupes",
  "photoCount": 128,
  "country": "Guadeloupe",
  "date": "2026-02-08T12:00:00.000Z",
  "eventName": "Dimanche Gras",
  "groupName": "Tous groupes",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0
}
```

### Lundi Gras

```json
{
  "title": "Lundi Gras - Mariages burlesques",
  "subtitle": "Mariages en blanc et noir",
  "photoCount": 67,
  "country": "Guadeloupe",
  "date": "2026-02-09T14:00:00.000Z",
  "eventName": "Lundi Gras",
  "groupName": "Akiyo",
  "photographerName": "Mo Pictures",
  "pricePerPhoto": 8.0
}
```

### Mardi Gras

```json
{
  "title": "Mardi Gras - Vidé final",
  "subtitle": "Grande parade finale",
  "photoCount": 156,
  "country": "Guadeloupe",
  "date": "2026-02-10T15:00:00.000Z",
  "eventName": "Mardi Gras",
  "groupName": "Tous groupes",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 10.0
}
```

### Mercredi des Cendres

```json
{
  "title": "Mercredi des Cendres - Vaval",
  "subtitle": "Crémation de Vaval",
  "photoCount": 45,
  "country": "Guadeloupe",
  "date": "2026-02-11T19:00:00.000Z",
  "eventName": "Mercredi des Cendres",
  "groupName": "Tous groupes",
  "photographerName": "Mo Pictures",
  "pricePerPhoto": 8.0
}
```

## Prix recommandés

| Type de galerie | Nb photos | Prix/photo | Prix total |
|----------------|-----------|------------|------------|
| Mini galerie | 10-20 | 6-8€ | 60-160€ |
| Galerie standard | 30-50 | 8-10€ | 240-500€ |
| Grande galerie | 60-100 | 8-12€ | 480-1200€ |
| Galerie premium | 100+ | 10-15€ | 1000€+ |

## Script d'import en masse

```javascript
// scripts/import_sample_galleries.js
const galleries = [
  {
    title: "Akiyo - Carnaval 2026",
    subtitle: "Défilé des groupes à peau",
    photoCount: 52,
    country: "Guadeloupe",
    date: new Date("2026-02-02"),
    eventName: "Défilé Pointe-à-Pitre",
    groupName: "Akiyo",
    photographerName: "Kris Photo",
    pricePerPhoto: 8.0,
    groupId: "akiyo",
  },
  // ... autres galeries
];

async function importGalleries() {
  const batch = db.batch();
  
  galleries.forEach(gallery => {
    const docRef = db.collection('media_galleries').doc();
    batch.set(docRef, {
      ...gallery,
      date: admin.firestore.Timestamp.fromDate(gallery.date),
      createdAt: admin.firestore.Timestamp.now(),
      coverUrl: 'https://picsum.photos/600/400',
      images: [
        'https://picsum.photos/600/400?1',
        'https://picsum.photos/600/400?2',
        'https://picsum.photos/600/400?3',
      ],
      isPublished: true,
      views: 0,
    });
  });
  
  await batch.commit();
  console.log(`✅ ${galleries.length} galeries importées`);
}
```

## Requêtes Firestore utiles

### Par pays
```javascript
db.collection('media_galleries')
  .where('country', '==', 'Guadeloupe')
  .get()
```

### Par événement
```javascript
db.collection('media_galleries')
  .where('eventName', '==', 'Dimanche Gras')
  .get()
```

### Par photographe
```javascript
db.collection('media_galleries')
  .where('photographerName', '==', 'Kris Photo')
  .get()
```

### Par période
```javascript
db.collection('media_galleries')
  .where('date', '>=', new Date('2026-02-01'))
  .where('date', '<=', new Date('2026-02-28'))
  .get()
```

### Galeries récentes
```javascript
db.collection('media_galleries')
  .orderBy('createdAt', 'desc')
  .limit(10)
  .get()
```

### Galeries populaires (par vues)
```javascript
db.collection('media_galleries')
  .orderBy('views', 'desc')
  .limit(10)
  .get()
```
