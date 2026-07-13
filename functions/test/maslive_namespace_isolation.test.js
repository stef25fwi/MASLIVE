'use strict';

const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../..');
const foreignBrand = ['ili', 'presto'].join('');
const obsoleteWidget = ['presto', '_bottom_nav.dart'].join('');

test('MASLIVE reste isole des noms et comptes de test d autres produits', () => {
  const seed = fs.readFileSync(
    path.join(root, 'functions/scripts/seed-test-profile-accounts.js'),
    'utf8',
  );
  const docs = fs.readFileSync(
    path.join(root, 'docs/TEST_PROFILE_ACCOUNTS.md'),
    'utf8',
  );
  const bloom = fs.readFileSync(
    path.join(
      root,
      'app/lib/features/bloom_art/presentation/pages/bloom_art_je_me_lance_form_page.dart',
    ),
    'utf8',
  );

  assert.equal(seed.toLowerCase().includes(foreignBrand), false);
  assert.equal(docs.toLowerCase().includes(foreignBrand), false);
  assert.equal(bloom.toLowerCase().includes(foreignBrand), false);
  assert.equal(
    fs.existsSync(path.join(root, 'app/lib/widgets', obsoleteWidget)),
    false,
  );
});
