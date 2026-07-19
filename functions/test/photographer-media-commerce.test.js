const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

function read(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", relativePath), "utf8")
}

test("photographer plans keep the approved commercial quotas", () => {
  const source = read("src/media-marketplace-media.js")

  assert.match(source, /discovery:[\s\S]*maxPublishedPhotos: 250[\s\S]*maxStorageBytes: 3 \* GiB[\s\S]*commissionRate: 0\.30/)
  assert.match(source, /pro:[\s\S]*monthlyPrice: 19\.90[\s\S]*maxPublishedPhotos: 3000[\s\S]*maxStorageBytes: 30 \* GiB[\s\S]*commissionRate: 0\.25/)
  assert.match(source, /studio:[\s\S]*monthlyPrice: 39\.90[\s\S]*maxPublishedPhotos: 10000[\s\S]*maxStorageBytes: 120 \* GiB[\s\S]*commissionRate: 0\.20/)
  assert.match(source, /agency:[\s\S]*monthlyPrice: 79\.90[\s\S]*maxPublishedPhotos: 30000[\s\S]*maxStorageBytes: 400 \* GiB[\s\S]*commissionRate: 0\.15/)
})

test("buyer pack ladder keeps the conversion prices", () => {
  const source = read("src/media-marketplace-media.js")

  assert.match(source, /title: "1 photo souvenir"[\s\S]*pickCount: 1[\s\S]*price: 6\.90/)
  assert.match(source, /title: "Pack Duo"[\s\S]*pickCount: 2[\s\S]*price: 10\.90/)
  assert.match(source, /title: "Pack Essentiel"[\s\S]*pickCount: 5[\s\S]*price: 19\.90[\s\S]*recommended: true/)
  assert.match(source, /title: "Pack Expérience"[\s\S]*pickCount: 10[\s\S]*price: 29\.90/)
  assert.match(source, /title: "Galerie personnelle"[\s\S]*pickCount: 20[\s\S]*price: 44\.90/)
})

test("upload reservation atomically protects photo and storage quotas", () => {
  const source = read("src/media-marketplace-media.js")

  assert.match(source, /const reservePhotographerMediaUploads = onCall/)
  assert.match(source, /db\.runTransaction\(async \(transaction\) => \{[\s\S]*reservedStorageBytes/)
  assert.match(source, /publishedPhotos \+ reservedPhotos \+ uploads\.length/)
  assert.match(source, /status: "reserved"[\s\S]*expiresAt/)
  assert.match(source, /maxFileBytes: plan\.maxFileBytes/)
  assert.match(source, /maxMegapixels: plan\.maxMegapixels/)
})

test("gallery publication requires photographer approval and payable Stripe Connect", () => {
  const source = read("src/media-marketplace-media.js")

  assert.match(source, /const publishPhotographerMediaGallery = onCall/)
  assert.match(source, /Le profil photographe doit être validé avant publication/)
  assert.match(source, /photographer\.data\.stripe\?\.chargesEnabled !== true/)
  assert.match(source, /photographer\.data\.stripe\?\.payoutsEnabled !== true/)
  assert.match(source, /ensureDefaultPacksInternal/)
  assert.match(source, /retentionExpiresAt/)
})

test("storage cleanup preserves purchased photos", () => {
  const source = read("src/media-marketplace-media.js")

  assert.match(source, /const cleanupPhotographerMediaStorage = onSchedule/)
  assert.match(source, /hasActiveEntitlementForPhoto/)
  assert.match(source, /Une photo déjà achetée doit être conservée/)
  assert.match(source, /deleteAfter/)
})

test("storage rules require an active server reservation", () => {
  const rules = read("../storage.rules")

  assert.match(rules, /media_upload_reservations/)
  assert.match(rules, /reservation\.status == 'reserved'/)
  assert.match(rules, /reservation\.ownerUid == request\.auth\.uid/)
  assert.match(rules, /reservation\.photoId == request\.resource\.metadata\.photoId/)
  assert.match(rules, /reservation\.originalPath == storagePath/)
  assert.match(rules, /allow read: if canManageMarketplaceMedia\(photographerId\);/)
  assert.match(rules, /galleries\/\{galleryId\}\/thumbs\/\{fileName\}[\s\S]*allow read: if true;/)
})

test("Firebase keeps the historical index entrypoint", () => {
  const packageJson = JSON.parse(read("package.json"))
  assert.equal(packageJson.main, "index.js")
})
