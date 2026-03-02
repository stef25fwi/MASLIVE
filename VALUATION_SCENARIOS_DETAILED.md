# 📊 VALUATION SCENARIOS & COMPARATIVES

**Date**: Mars 2026
**Version**: Final

---

## 1️⃣ TROIS SCÉNARIOS VALUATION

### SCENARIO A: Conservative (85% confidence)

```
Éléments comptabilisés           Montant
─────────────────────────────────────────
Code (42k lines)                 €390,000
Infrastructure & DevOps          €120,000
Documentation                    €90,000
Architecture                     €150,000
Intégrations                     €200,000
IP Propriétaire (IP)             €250,000
─────────────────────────────────────────
SOUS-TOTAL                       €1,200,000

Fonctionnalités Implémentées (13) €825,000
─────────────────────────────────────────
TOTAL CONSERVATIVE               €2,025,000
```

**Use Case**: Achat IP, Évaluation fiscale, Levée de fonds amorçage

---

### SCENARIO B: Base Case (60% confidence)

```
Conservative value               €2,025,000
+ Patent potential (30% prob)    €100,000
+ first-year revenue (SaaS)      €60,000 (ARR)
  × 3x multiple                  €180,000
─────────────────────────────────────────
TOTAL BASE CASE                  €2,305,000
```

**Use Case**: Valorisation de marché, Business valuation, Achat par entrepreneur

---

### SCENARIO C: Optimistic (35% confidence)

```
Base Case                        €2,305,000
+ IP licensing (€500k potential) €100,000
+ Market traction (2x growth)    €180,000
+ Network effects (50% uplift)   €300,000
+ Breach partnerships            €150,000
─────────────────────────────────────────
TOTAL OPTIMISTIC                 €3,035,000
```

**Use Case**: Acquisition technologique, Levée Series A, Hypothèse croissance agressive

---

## 2️⃣ VALUATION BY INCOME APPROACH (SaaS)

### Scénario Croissance Modérée

#### Assumptions
```
Year 1: 150 paying customers × €400/year = €60k ARR
Year 2: 600 customers (4x) × €400/year = €240k ARR
Year 3: 1,500 customers (2.5x) × €400/year = €600k ARR
Year 4: 2,200 customers (1.5x) × €400/year = €880k ARR
Year 5: 2,800 customers (1.3x) × €400/year = €1.12M ARR

Assumptions:
- Churn rate: 5% monthly
- CAC (Customer Acquisition Cost): €50
- LTV (Lifetime Value): €2,000
- Gross Margin: 85%
```

#### Valuation Formulas

**DCF (Discounted Cash Flow)**
```
Year 1: €60k / 1.15^1 = €52k
Year 2: €240k / 1.15^2 = €181k
Year 3: €600k / 1.15^3 = €395k
Year 4: €880k / 1.15^4 = €502k
Year 5: €1.12M / 1.15^5 = €556k
Terminal Value (Year 5 × 4x): €556k × 4 = €2.224M

TOTAL DCF VALUE: €4.31M
```

**Multiple Approach**
```
Year 5 ARR: €1.12M
SaaS Multiple: 5x (conservative) to 10x (growth)

Conservative: €1.12M × 5 = €5.6M
Growth:      €1.12M × 10 = €11.2M
Average:     €8.4M
```

**Result**: Year 5 valuation could be **€4.3M - €11.2M**

---

## 3️⃣ COMPARABLE COMPANY VALUATION

### Comparable Companies (Similar Size/Stage)

| Company | Size | Funding | Valuation | Stage |
|---------|------|---------|-----------|-------|
| **Supabase** | 50 devs | $80M Series B | $540M | 2023 |
| **Clerk** | 35 devs | $20M Series A | $150M | 2023 |
| **Cursor** | 20 devs | $60M Series A | $400M+ | 2024 |
| **Retool** | 200 devs | Series C | $1.9B | 2022 |
| **MAS'LIVE** | 1 dev eq. | Pre-seed | **? €** | 2026 |

### Valuation On Revenue Multiples

| Multiple | ARR Y1 | Valuation |
|----------|--------|-----------|
| 3x (Bootstrapped) | €60k | €180k |
| 5x (Healthy SaaS) | €60k | €300k |
| 10x (Growth SaaS) | €60k | €600k |
| 25x (High Growth) | €60k | €1.5M |

*Year 1 ARR is €60k, so even conservative multiples give €180k-€1.5M*

### Adjusted for Development Cost

**Precedent Transactions**:
- Small SaaS acquired at 1-2x annual revenue
- Developer tools at 2-3x
- Location/marketplace at 3-5x
- Early-stage pre-revenue IP at 0.5-1x dev cost

**MAS'LIVE equivalent**:
```
Dev Cost (€2M) × 0.75x (early stage) = €1.5M (minimum)
Dev Cost (€2M) × 1x (standard) = €2M
Dev Cost (€2M) × 1.5x (IP premium) = €3M
Dev Cost (€2M) × 2x (if market traction) = €4M
```

---

## 4️⃣ ASSET-BASED VALUATION

### Tangible Assets

```
Servers/Infrastructure annually deprecated: €5k
Development tools/licenses:              €3k
Committed to marketing:                   €0k
────────────────────────────────────────────
TANGIBLE ASSETS (Fair Value):            €8k
```

### Intangible Assets

```
Code (proprietary algorithms):     €400k
Architecture (reusable):           €150k
Documentation & IP:               €90k
Customer relationships (0 yet):    €0
Brand/Market position:             €50k
Patents (potential):               €250k
────────────────────────────────────────────
INTANGIBLE ASSETS:                €940k
```

### Total Asset Value
```
Tangible:                          €8k (not material)
Intangible:                        €940k
─────────────────────────────────────────
ASSET-BASED VALUE:                €948k
```

*Note: Asset-based gives lower value because intangibles high but cash flow not yet proven*

---

## 5️⃣ MARKET COMP ADJUSTED

### TAM (Total Addressable Market) Analysis

```
Geographic Markets:
- France: €50M SaaS market (location/tracking)
- EU: €300M (regional market)
- Global: €1.5B (global marketplace/maps)

Our TAM (Location + Commerce):
- Conservative: €10M EU serviceable market
- Optimistic: €100M+ global

Market Capture Scenarios:
0.5% TAM capture (year 5): €50k - €500k revenue
1% TAM capture: €100k - €1M revenue
2% TAM capture: €200k - €2M revenue
5% TAM capture: €500k - €5M revenue (très optimiste)
```

### Valuation by TAM × Penetration

```
EU Market (€50M) × 2% (our target) = €1M potential market
× 60% penetration (year 5) = €600k ARR
× 5x multiple = €3M valuation

Global Market (€1.5B) × 0.1% = €1.5M potential
× 30% penetration = €450k ARR
× 5x multiple = €2.25M valuation
```

---

## 6️⃣ WATERFALL VALUATION MODEL

### Starting from Comparable

```
Comparable SaaS (pure dev cost multiple): €2M
Adjustments:
  - No revenue yet (pre-market): -30%  = €600k
  + IP quality (8.3/10 arch):   +15%  = €300k
  + Patent potential:           +10%  = €200k
  - Execution risk (1 dev):     -20%  = €400k
  + Market size (€100M TAM):    +25%  = €500k
  ─────────────────────────────────────────
ADJUSTED VALUE:                       €2.4M
```

---

## 7️⃣ FINANCING SCENARIOS

### If Raising Seed Round

**Target**: €500k seed (runway 18 months)
**Valuation options**:

```
SAFE (No valuation cap):
- Investors get equity later

Pre-Money Valuation: €2M
- Seed €500k
- Investor gets 20% (€500k / €2.5M total)
- Post-money: €2.5M

Hybrid:
- Convertible note + equity
- On Series A, convert with 20% discount
```

### Post-Money Scenarios

**Series A (€3M raise at Series A)**
```
At €10M Series A (5x Seed)
     You raised €500k at €2M pre-money
     → You own 16.7% (€1.67M worth)
     + €500k operating for 2 years
     = €2.17M net value at Series A

Dilution: Seed to Series A = 33-40%
```

---

## 8️⃣ BREAK-EVEN & PAYBACK ANALYSIS

### Cost to Maintain (Annual)

```
Cloud Infrastructure:    €16,400
Dev time (1 FTE):        €84,000 (20h/week maintenance)
Security/Monitoring:     €6,000
Support:                 €12,000
─────────────────────────────────────
TOTAL ANNUAL (Ops):      €118,400

Break-even MRR: €118,400 / 12 = €9,867
Customers needed: €9,867 / €33 (avg MRR) = 299 customers

TODAY: We need 300 paying customers to break-even
= ~2% conversion from 15k target users
= Achievable in 6-12 months with modest marketing
```

### Payback on Development Investment

```
If valuation: €2M
If generates €60k ARR year 1
Payback period: €2M / €60k = 33 years (long!)

BUT:
If reaches €1M ARR (year 5)
Payback period: €2M / €1M = 2 years (healthy)

Or if acquired at €3M after 2 years:
Net gain: €3M - €2M cost = €1M profit (50% ROI)
```

---

## 9️⃣ SENSITIVITY ANALYSIS

### Variables Impacting Valuation

| Variable | -25% | Base | +25% | Impact |
|----------|------|------|------|--------|
| Time-to-Market | +3mo | Base | -3mo | ±€300k |
| Customer Growth | 2x/yr | 4x/yr | 6x/yr | ±€800k |
| Churn Rate | 8% | 5% | 2% | ±€600k |
| Pricing | €250 | €400 | €600 | ±€400k |
| Development Cost | €2.5M | €2M | €1.5M | ±€300k |

**Most sensitive**: Customer growth rate (±€800k impact)

---

## 🔟 FINAL RECOMMENDATION

### Best Valuation Range for Negotiations

```
MINIMUM FLOOR:
= Development cost (€2M) × 75% (pre-revenue discount)
= €1.5M

FAIR VALUE:
= €2M (based on comparable SaaS at 1x dev cost)

AGGRESSIVE:
= €2.5-3M (with upside for IP + growth potential)

EXCEPTIONAL:
= €4M+ (if immediate traction + acquisition interest)
```

### By Use Case

| Scenario | Valuation | Rationale |
|----------|-----------|-----------|
| **Self-valuation** | €2M | Fair market |
| **Investor pitch** | €2.5M - €3M | Growth potential |
| **Acquisition** | €1.8M - €2.2M | Conservative |
| **IP licensing** | €250k - €500k | Patent value only |
| **MSNY (if SaaS)** | €4M - €6M | Year 5 DCF |

---

## 📈 TIMELINE TO VALUE REALIZATION

```
TODAY (Mar 2026)
    Valuation: €1.8M - €2.5M (technical asset)
    ↓

6 MONTHS (Sep 2026)
    100+ users acquired
    Valuation: €2.5M - €3.5M (+IP proof)
    ↓

12 MONTHS (Mar 2027)
    €60k ARR (150 customers)
    Valuation: €3M - €5M (revenue-backed)
    ↓

24 MONTHS (Mar 2028)
    €300k - €500k ARR
    Valuation: €5M - €10M (SaaS multiple)
    ↓

36 MONTHS (Mar 2029)
    €1M+ ARR (acquisition interest likely)
    Valuation: €10M - €20M+ (strategic buyer premium)
```

---

## ✅ CONCLUSION

### Current Fair Valuation: **€2,000,000**

**With 5-Year Exit:**
- SaaS play: €4M - €8M
- Acquisition: €2.5M - €5M
- IP licensing: €250k - €500k (annual)

**Key Value Drivers**:
1. Market adoption (biggest lever)
2. Recurring revenue (SaaS model)
3. IP patents (defensibility)
4. Team execution (ability to scale)

**Decision Points**:
- Sell now at €2M? (Good exit for solo dev)
- Raise seed at €2.5M pre? (3-5x upside potential)
- Bootstrap to profitability? (Avoid dilution, lower upside)
- Target acquisition? (Google/Mapbox interest possible)

---

**Fin de l'analyse**

*Pour ajustements: contacter développeur principal*
