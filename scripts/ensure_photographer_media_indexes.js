const fs = require('node:fs')
const path = require('node:path')

const indexPath = path.join(__dirname, '..', 'firestore.indexes.json')
const document = JSON.parse(fs.readFileSync(indexPath, 'utf8'))
document.indexes = Array.isArray(document.indexes) ? document.indexes : []

const required = [
  {
    collectionGroup: 'media_upload_reservations',
    queryScope: 'COLLECTION',
    fields: [
      { fieldPath: 'status', order: 'ASCENDING' },
      { fieldPath: 'expiresAt', order: 'ASCENDING' },
    ],
  },
  {
    collectionGroup: 'media_galleries',
    queryScope: 'COLLECTION',
    fields: [
      { fieldPath: 'status', order: 'ASCENDING' },
      { fieldPath: 'deleteAfter', order: 'ASCENDING' },
    ],
  },
  {
    collectionGroup: 'media_entitlements',
    queryScope: 'COLLECTION',
    fields: [
      { fieldPath: 'assetId', order: 'ASCENDING' },
      { fieldPath: 'isActive', order: 'ASCENDING' },
    ],
  },
  {
    collectionGroup: 'media_entitlements',
    queryScope: 'COLLECTION',
    fields: [
      { fieldPath: 'photoIds', arrayConfig: 'CONTAINS' },
      { fieldPath: 'isActive', order: 'ASCENDING' },
    ],
  },
]

function signature(index) {
  return JSON.stringify({
    collectionGroup: index.collectionGroup,
    queryScope: index.queryScope,
    fields: index.fields,
  })
}

const existing = new Set(document.indexes.map(signature))
let added = 0
for (const index of required) {
  const key = signature(index)
  if (existing.has(key)) continue
  document.indexes.push(index)
  existing.add(key)
  added += 1
}

if (added > 0) {
  fs.writeFileSync(indexPath, `${JSON.stringify(document, null, 2)}\n`)
  console.log(`Added ${added} photographer media index(es).`)
} else {
  console.log('Photographer media indexes are already present.')
}
