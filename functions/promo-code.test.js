/**
 * Test suite for promo code validation
 * Run: npm test -- promo-code.test.js
 */

const assert = require('assert');

// Mock Firestore config
const mockPromoConfig = {
  codes: {
    'MAS10': {
      type: 'percentage',
      value: 10,
      maxDiscountCents: null,
      minSubtotalCents: 5000,
      disabled: false,
    },
    'MEDIA5': {
      type: 'fixed',
      value: 500,
      minSubtotalCents: 2000,
      disabled: false,
    },
    'WELCOME20': {
      type: 'percentage',
      value: 20,
      maxDiscountCents: 2000,
      minSubtotalCents: null,
      disabled: false,
    },
    'EXPIRED_CODE': {
      type: 'percentage',
      value: 50,
      expiresAt: new Date('2020-01-01'), // Past date
      disabled: false,
    },
    'INACTIVE_CODE': {
      type: 'percentage',
      value: 50,
      disabled: true,
    },
  },
};

// Helper functions (mimic server-side logic)
function clampPositiveAmount(value) {
  return Math.max(0, Number(value) || 0);
}

function validatePromoLogic(promoCode, subtotalCents) {
  const codes = mockPromoConfig.codes || {};
  const codeData = codes[promoCode];

  // Code not found
  if (!codeData) {
    return { valid: false, discountCents: 0, message: 'Code promo invalide' };
  }

  // Check if disabled
  if (codeData.disabled === true) {
    return { valid: false, discountCents: 0, message: 'Code promo désactivé' };
  }

  // Check expiration
  if (codeData.expiresAt) {
    const expiresAtMs = (typeof codeData.expiresAt === 'object' && typeof codeData.expiresAt.toMillis === 'function')
      ? codeData.expiresAt.toMillis()
      : (typeof codeData.expiresAt === 'number') ? codeData.expiresAt : 0;
    
    const expiresAtDate = new Date(codeData.expiresAt);
    if (expiresAtDate && Date.now() > expiresAtDate.getTime()) {
      return { valid: false, discountCents: 0, message: 'Code promo expiré' };
    }
  }

  // Check minimum order value
  if (codeData.minSubtotalCents && subtotalCents < codeData.minSubtotalCents) {
    return {
      valid: false,
      discountCents: 0,
      message: `Minimum commande: ${(codeData.minSubtotalCents / 100).toFixed(2)}€`,
    };
  }

  // Calculate discount
  let discountCents = 0;
  if (codeData.type === 'percentage') {
    const pct = clampPositiveAmount(codeData.value);
    discountCents = Math.floor((subtotalCents * pct) / 100);
    // Cap by maxDiscountCents if specified
    if (codeData.maxDiscountCents && discountCents > codeData.maxDiscountCents) {
      discountCents = codeData.maxDiscountCents;
    }
  } else if (codeData.type === 'fixed') {
    discountCents = Math.trunc(codeData.value || 0);
  }

  if (discountCents <= 0) {
    return { valid: false, discountCents: 0, message: 'Réduction invalide' };
  }

  return {
    valid: true,
    discountCents,
    message: `Réduction appliquée: -${(discountCents / 100).toFixed(2)}€`,
  };
}

// Test cases
describe('Promo Code Validation', () => {
  describe('Percentage discounts', () => {
    test('MAS10: 10% off €50 merch + €20 media', () => {
      const subtotalCents = 7000; // 70€
      const result = validatePromoLogic('MAS10', subtotalCents);
      assert.strictEqual(result.valid, true);
      assert.strictEqual(result.discountCents, 700); // 10% of 7000
      assert.strictEqual(result.message, 'Réduction appliquée: -7.00€');
    });

    test('WELCOME20: 20% off capped at €20', () => {
      const subtotalCents = 15000; // 150€
      const result = validatePromoLogic('WELCOME20', subtotalCents);
      assert.strictEqual(result.valid, true);
      assert.strictEqual(result.discountCents, 2000); // 20% would be 3000, capped at 2000
      assert.strictEqual(result.message, 'Réduction appliquée: -20.00€');
    });

    test('MAS10: Minimum order not met', () => {
      const subtotalCents = 4000; // 40€ < 50€ minimum
      const result = validatePromoLogic('MAS10', subtotalCents);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
      assert(result.message.includes('Minimum commande: 50.00€'));
    });
  });

  describe('Fixed discounts', () => {
    test('MEDIA5: €5 fixed discount', () => {
      const subtotalCents = 5000; // 50€
      const result = validatePromoLogic('MEDIA5', subtotalCents);
      assert.strictEqual(result.valid, true);
      assert.strictEqual(result.discountCents, 500); // 5€ = 500 cents
    });

    test('MEDIA5: Minimum order not met', () => {
      const subtotalCents = 1000; // 10€ < 20€ minimum
      const result = validatePromoLogic('MEDIA5', subtotalCents);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
    });
  });

  describe('Invalid codes', () => {
    test('Non-existent code', () => {
      const result = validatePromoLogic('INVALID_CODE', 5000);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
      assert.strictEqual(result.message, 'Code promo invalide');
    });

    test('Disabled code', () => {
      const result = validatePromoLogic('INACTIVE_CODE', 5000);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
      assert.strictEqual(result.message, 'Code promo désactivé');
    });

    test('Expired code', () => {
      const result = validatePromoLogic('EXPIRED_CODE', 5000);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
      assert.strictEqual(result.message, 'Code promo expiré');
    });
  });

  describe('Edge cases', () => {
    test('Zero subtotal', () => {
      const result = validatePromoLogic('MAS10', 0);
      assert.strictEqual(result.valid, false);
      assert.strictEqual(result.discountCents, 0);
      assert(result.message.includes('Minimum commande'));
    });

    test('Empty code', () => {
      const result = validatePromoLogic('', 5000);
      assert.strictEqual(result.valid, false);
    });

    test('Case insensitive code matching', () => {
      // Note: Client must uppercase before sending
      const result = validatePromoLogic('mas10', 7000);
      assert.strictEqual(result.valid, false); // Will fail without uppercase
    });
  });
});

// Run tests
if (require.main === module) {
  console.log('Running promo code tests...\n');

  const tests = [
    { name: 'MAS10: 10% off €70', fn: () => {
      const result = validatePromoLogic('MAS10', 7000);
      assert(result.valid && result.discountCents === 700);
    }},
    { name: 'MAS10: Minimum not met', fn: () => {
      const result = validatePromoLogic('MAS10', 4000);
      assert(!result.valid);
    }},
    { name: 'MEDIA5: €5 fixed', fn: () => {
      const result = validatePromoLogic('MEDIA5', 5000);
      assert(result.valid && result.discountCents === 500);
    }},
    { name: 'WELCOME20: Capped at €20', fn: () => {
      const result = validatePromoLogic('WELCOME20', 15000);
      assert(result.valid && result.discountCents === 2000);
    }},
    { name: 'Invalid code', fn: () => {
      const result = validatePromoLogic('INVALID', 5000);
      assert(!result.valid);
    }},
    { name: 'Disabled code', fn: () => {
      const result = validatePromoLogic('INACTIVE_CODE', 5000);
      assert(!result.valid && result.message.includes('désactivé'));
    }},
  ];

  let passed = 0;
  for (const test of tests) {
    try {
      test.fn();
      console.log(`✅ ${test.name}`);
      passed++;
    } catch (e) {
      console.log(`❌ ${test.name}: ${e.message}`);
    }
  }

  console.log(`\n${passed}/${tests.length} tests passed`);
  process.exit(passed === tests.length ? 0 : 1);
}

module.exports = { validatePromoLogic, mockPromoConfig };
