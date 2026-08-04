# Default Duty Sets — Research

Findings to feed into the seed data for ADR 0008 (default-duty seed data on first
launch). The goal is a curated ~40–60 duty set, slotted into the 6 checklists
defined by **Area × (Cadence/Phase)**, with primary-source backing wherever
possible.

Vocabulary follows `CONTEXT.md` — FOH, BOH, Area, Phase (Opening/Closing),
Cadence (daily/weekly), Business Day, Duty. Banned synonyms avoided.

---

## Methodology

Sources were gathered and triaged against a fixed hierarchy (highest authority
first):

1. **Regulatory / food-safety code** — FDA Food Code 2022 (the model code that
   nearly all US state and local health departments adopt). Cited by section
   number against the FDA's canonical landing page, because the authoritative
   text is a ~700-page PDF and section citation is the standard way to reference
   it.
2. **Industry-association / operations manuals** — National Restaurant
   Association's ServSafe, state restaurant associations. (See gaps below — much
   of this material is behind paid certification paywalls and could not be
   fetched directly.)
3. **Operations textbooks / published handbooks** — (could not be fetched; see
   gaps).
4. **First-party operations guides** — published checklists from hospitality
   vendors (TouchBistro). Used for the operations-level duties the Food Code
   does not cover (lights, tables, POS). Flagged as secondary / commercially
   motivated, used for cross-reference only.

**What "primary" means in this document:** for **mandated** duties, the primary
source is the FDA Food Code (a regulatory document). For **standard-practice**
duties (mostly FOH and weekly cadence), there is no single regulator; primary
sourcing collapses and I rely on convergence across multiple published
operations checklists. Where that convergence is strong I mark *standard
practice*; where I could only find a single weak source, I either omit the duty
or mark it *common* and flag it.

**Scope limitations:**
- The FDA Food Code is a **model** code. It becomes law only when a state/county
  adopts it. ~all US jurisdictions have adopted some version, so a "mandated"
  mark here means *"mandated by your local health code, which is almost
  certainly based on this Food Code section."* The developer should not treat
  any duty as legal advice — local codes vary (e.g., some counties require
  hotter hot-water sanitization, different ppm limits, additional daily temp
  logs).
- The Food Code regulates **BOH food safety** heavily. It has almost nothing to
  say about **FOH operations** (lights, music, table settings) beyond restroom
  supplies and lighting minimums. FOH duties are therefore *standard practice*,
  not *mandated*.
- **Weekly cadence day-binding has essentially no primary source.** No regulator
  or authoritative body specifies which weekday knife-sharpening or
  fryer-oil-change belongs on. Day assignments below are **industry convention**
  and are flagged as such — the developer should treat them as manager-curated.

**One honesty caveat on Food Code citations:** the document contents
(temperature thresholds, ppm ranges, section locations) reflect the 2022 Food
Code as I know it; the FDA landing page and document existence were verified, but
the developer should spot-check section numbers against the official PDF
(`Food Code 2022`, linked from the FDA page) before locking `defaults.json`.

---

## Source quality assessment

Read this first — it tells you how much to trust each section.

| Slot | Source strength | Notes |
| --- | --- | --- |
| **BOH Daily — Opening** | **Strong (primary)** | Heavily regulated. FDA Food Code mandates temperature verification, sanitizer concentration, hand-sink stocking, date-marking. High confidence. |
| **BOH Daily — Closing** | **Strong (primary)** | Cooling procedure, date-mark disposition, sanitizer of food-contact surfaces, cold-holding verification all mandated. High confidence. |
| **BOH Weekly** | **Mixed.** The *duties* (delime ice machine, deep clean walk-in, change fryer oil, clean grease trap) are well-grounded in Food Code §4-501/§6-501 and equipment specs. The **day-binding** is convention only — no primary source. Flagged heavily. |
| **FOH Daily — Opening** | **Weak (secondary).** No regulator governs "turn on the lights." Drawn from published operations checklists (TouchBistro). Convergence across vendors is strong, so *standard practice* is defensible, but these are not legally mandated. |
| **FOH Daily — Closing** | **Weak (secondary)** for most duties; **mandated** only for restroom supplies and trash (pest control). POS/cash duties are standard practice. |
| **FOH Weekly** | **Weak.** Same convention problem as BOH weekly, with even thinner sourcing. Recommend manager-curated; the defaults here are plausible placeholders only. |

**Where primary sources were scarce and I declined to pad:**
- Specific weekday assignments for weekly duties — I provide a defensible
  convention but no duty in the weekly sections carries a primary-source
  day-binding citation.
- Bar / beverage program duties (ice-well sanitizing, draft-line cleaning,
  garnish rotation) — real and mandated-ish (Food Code treats ice and garnishes
  as food), but concept-specific. Excluded from the generic set; flagged in
  "Concept-specific" notes.
- Quick-service-specific duties (warming-cabinet temp logs, drive-thru headset
  checks) — real but concept-specific. Excluded; flagged.
- Manager / owner-only duties (bank deposit, scheduling, P&L review) — out of
  scope for a line-staff checklist app; excluded.

---

## Concept-specific tag legend

Per ADR 0008 the app ships a single "generic" set. Many duties only apply to
some concepts. I tag each duty where relevant:

- **(FSR)** — full-service restaurant only (table settings, silverware rolling).
- **(QSR)** — quick-service / fast-casual only (holding-cabinet temps).
- **(bar)** — beverage program only (excluded from generic set, noted for the
  developer).
- **(no tag)** — applies to any restaurant with a kitchen + dining area.

The generic set below leans FSR (table settings included) because that's the
broader case; the developer can prune the tagged FSR duties for a QSR
deployment.

---

## BOH Daily — Opening

| Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- |
| Log walk-in cooler and freezer temperatures (cooler ≤41°F / freezer ≤0°F) | Cold-holding TCS food out of range is the #1 health-code violation; verifies the unit held safe temp overnight. | **Mandated** | FDA Food Code 2022 §3-501.16 (cold holding ≤41°F), §4-204.112 (ambient thermometer required in each refrigerated unit) — https://www.fda.gov/food/fda-food-code/food-code-2022 |
| Log reach-in and prep-rail cooler temperatures (≤41°F) | Same cold-holding rule for line units holding proteins/dairy during service. | **Mandated** | FDA Food Code 2022 §3-501.16, §4-204.112 |
| Test chemical sanitizer concentration at the three-compartment sink and in wiping-cloth buckets (chlorine 50–100 ppm; quat per label) | Wrong sanitizer strength = unsanitized surfaces; a standard health-inspection check. | **Mandated** | FDA Food Code 2022 §4-501.114 (sanitizer concentration/temperature/pH by chemical), §3-304.14 (wiping cloths held in sanitizer between uses) |
| Stock and verify handwashing sinks (warm water, soap, paper towels, unobstructed) | Hand sinks must be usable at all times; the most-cited violation category. | **Mandated** | FDA Food Code 2022 §5-205.11 (hand sink used only for handwashing, accessible), §5-205.15 (maintained), §6-301.12 (soap), §6-301.14 (drying) |
| Sanitize all food-contact surfaces and cutting boards before prep begins | Food-contact surfaces must be cleaned then sanitized before use. | **Mandated** | FDA Food Code 2022 §4-701.11 (sanitize after cleaning), §4-602.11 (cleaning frequency) |
| Verify date marks on ready-to-eat TCS foods and discard anything past day 7 | RTE TCS held >24 hr must be date-marked and discarded at 7 days (at ≤41°F). | **Mandated** | FDA Food Code 2022 §3-501.17 (date marking), §3-501.18 (disposition) |
| Confirm hot-holding units are holding ≥135°F before food goes in | Hot holding below 135°F permits pathogen growth. | **Mandated** | FDA Food Code 2022 §3-501.16 (hot holding ≥135°F) |
| Stock prep stations from walk-in and dry storage (ice down the cold line) | Operational readiness; also satisfies cold-holding for line ingredients. | Standard practice | TouchBistro opening checklist — https://www.touchbistro.com/blog/restaurant-opening-checklist/ |
| Turn on and preheat cooking equipment (ovens, fryers, grills, exhaust hood) | Equipment preservation + hood must run during cooking (fire/code). | Standard practice | TouchBistro opening checklist (BOH "kitchen stations are stocked") |

**9 duties.** Strong primary backing on items 1–7.

---

## BOH Daily — Closing

| Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- |
| Cool cooked TCS foods rapidly (135°F → 70°F within 2 hr; → 41°F within 6 hr total) using shallow pans or ice bath | Improper cooling is a leading cause of foodborne illness; the rule is explicit and a top inspection focus. | **Mandated** | FDA Food Code 2022 §3-501.14 (cooling), §3-501.15 (cooling methods) |
| Label and date all stored prep, leftovers, and opened containers | Anything held >24 hr needs a date mark so the 7-day limit is enforceable. | **Mandated** | FDA Food Code 2022 §3-501.17 (date marking) |
| Discard ready-to-eat TCS food past its date mark | Past-day-7 RTE food is adulterated and must not be served. | **Mandated** | FDA Food Code 2022 §3-501.18 (disposition) |
| Sanitize all food-contact surfaces (prep tables, cutting boards, slicer, can opener) | TCS-contact surfaces must be cleaned + sanitized at least every 4 hr; final sanitize at close. | **Mandated** | FDA Food Code 2022 §4-602.11 (every 4 hr for TCS contact), §4-701.11 |
| Empty, clean, and sanitize the three-compartment sink | Sink itself is a food-contact surface for warewashing; soil accumulates through service. | **Mandated** | FDA Food Code 2022 §4-501.115 (warewashing equipment cleaning frequency) |
| Cover, label, and store all food off the floor (≥6 in.) and in cook-temp order (poultry below beef below produce) | Cross-contamination prevention + physical barrier rule. | **Mandated** | FDA Food Code 2022 §3-305.11 (stored ≥6 in., covered, protected), §3-302.11 (raw separated, by final cook temp) |
| Filter/strain fryer oil; cover fryers (deep change is weekly — see BOH Weekly) | Oil quality affects food safety + cost; straining removes carbonized debris. | Standard practice | TouchBistro closing checklist ("changing fryer oil") — https://www.touchbistro.com/blog/restaurant-closing-checklist/ |
| Mop kitchen floors and clean floor drains | Physical facilities must be cleaned as often as necessary; drains harbor pests/odors. | **Mandated** | FDA Food Code 2022 §6-501.12 (cleaning physical facilities), §5-402.13/§5-403 (drains) |
| Take out trash and recycling; clean and sanitize receptacles | Food residue and trash attract pests; indoor receptacles must be cleanable. | **Mandated** | FDA Food Code 2022 §6-501.111 (pest control), §5-502.13 (receptacles), §6-501.114 (litter-free) |
| Log closing walk-in and line-cooler temperatures (≤41°F) | Confirms units will hold safe temp through the overnight close. | **Mandated** | FDA Food Code 2022 §3-501.16 |
| Run the dish machine; confirm final sanitizing rinse (temp or chemical) | Warewashing must achieve sanitization each cycle. | **Mandated** | FDA Food Code 2022 §4-501.112 (hot-water sanitization), §4-501.113, §4-703.11 |
| Walk pest-control perimeter; check bait stations and door seals | Establishments must be kept pest-free; nightly detection limits infestations. | **Mandated** | FDA Food Code 2022 §6-501.111 (controlling pests) |

**12 duties.** Strong primary backing on 10 of 12.

---

## BOH Weekly

> **Day-binding honesty:** No primary source dictates *which weekday* any of
> these belong on. The assignments below follow industry convention (deep
> cleaning on slower days, oil change before the weekend, inventory before the
> next delivery). The **duties themselves** are well-grounded (Food Code
> equipment-maintenance and cleaning-frequency sections, plus manufacturer
> specs); the **weekday** is the developer's call. See "Open questions."

| Weekday | Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- | --- |
| Monday | Count inventory and place supply orders | Most restaurants receive Tue/Thu deliveries; count Monday → order for Tuesday. Convention only. | Standard practice | TouchBistro opening checklist (incoming-inventory handling); day-binding by convention, not cited |
| Monday | Clean and sanitize walk-in cooler shelves and rotate stock (FIFO) | Post-weekend stock pressure; cleaning frequency tied to soil accumulation. | **Mandated** (cleaning), day-binding *convention* | FDA Food Code 2022 §6-501.12 (cleaning), §3-501.18 (rotate/discard by date) |
| Tuesday | Delime and sanitize the ice machine | Ice is food; mineral scale harbors biofilm. Manufacturer-recommended cadence (commonly weekly–biweekly). | **Mandated** (cleaning), day-binding *convention* | FDA Food Code 2022 §4-501.15 (equipment maintained in good repair, clean), §1-201.10(B) (ice is "food") |
| Tuesday | Deep clean prep-cooler gaskets, pan rails, and under-line | Non-food-contact surfaces need a frequency that precludes soil buildup. | **Mandated** (cleaning), day-binding *convention* | FDA Food Code 2022 §4-602.12 (non-food-contact surface cleaning frequency) |
| Wednesday | Sharpen knives and honing rods | Edge maintenance; convention puts it on a mid-week slower day. | Standard practice, day-binding *convention* | No primary source — industry folklore. See "Open questions." |
| Wednesday | Calibrate probe thermometers in ice water (32°F) and boiling water (212°F) | Accurate thermometers are required; calibration cadence is standard practice. | **Mandated** (accuracy), day-binding *standard practice* | FDA Food Code 2022 §4-203.11/§4-203.12 (thermometer accuracy), §4-502.11/§4-502.12 |
| Thursday | Change fryer oil completely and boil out the vat | Before the high-volume weekend; cadence set by volume + manufacturer. | Standard practice, day-binding *convention* | TouchBistro closing checklist; manufacturer specs. Day-binding by convention. |
| Thursday | Clean exhaust-hood filters (interior baffle wash) | Grease buildup is a fire hazard; NFPA 96 sets cadence by cooking volume (filter-only cleaning is commonly weekly). | **Mandated** (fire code), day-binding *standard practice* | NFPA 96 (Standard for Ventilation Control and Fire Protection of Commercial Cooking Operations) — primary fire-safety standard; FDA Food Code §6-303.11/§6-304 (ventilation) |
| Friday | Deep clean oven and range interiors | Before the busiest day; done when volume still permits a cool-down window. | Standard practice, day-binding *convention* | TouchBistro closing checklist (BOH deep-clean group); Food Code §4-501.15/§6-501.12. Day-binding by convention. |
| Saturday | *(Manager-curated — highest-volume day. Recommend only restock/par duties.)* | Sat is the highest-volume day for most full-service; deep cleaning risks service. | — | Convention; no standard weekly duty recommended here. |
| Sunday | Clean grease trap (or per municipal cadence, e.g. when ¼ full) | Pretreatment / plumbing code sets frequency; many municipalities require weekly–monthly logging. | **Mandated** (local plumbing/pretreatment code), cadence *by jurisdiction* | Local FOG (fats/oils/grease) ordinance; varies. Not FDA Food Code. |
| Sunday | Deep clean dish pit, mop-sink area, and floor drains with enzyme | Post-weekend soil load; drains are the top pest/odor vector. | **Mandated** (cleaning), day-binding *convention* | FDA Food Code 2022 §6-501.12, §5-402.13 |

**~10 weekly duties (Sat intentionally light).** Duty content is well-sourced;
**day-binding is not** — every "day-binding *convention*" flag is an honest
admission.

---

## FOH Daily — Opening

> **Honesty note:** FOH operations are largely unregulated. The Food Code
> touches FOH only via restroom supplies (§6-502.13) and lighting minimums
> (§6-303.11). Everything else here is *standard practice*, drawn from published
> operations checklists. Convergence across vendors is strong, so the set is
> defensible as a default — but none of it (except restroom supplies) is legally
> mandated.

| Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- |
| Disarm alarm and unlock the entrance | Security; first-in staff control. | Standard practice | TouchBistro opening checklist; universal industry practice |
| Turn on all dining-room, restroom, and exterior lights | Guest-ready; restroom/self-service lighting has a code minimum. | **Mandated** (restroom/self-service min only), else standard practice | FDA Food Code 2022 §6-303.11 (20 fc in toilets/handwashing/self-service, 10 fc in walk-in/server stations); TouchBistro opening checklist |
| Start background music and set audio zones | Guest experience. | Standard practice | TouchBistro opening checklist; industry convention |
| Boot POS and payment terminals; confirm network and card reader | Cannot ring sales otherwise; TouchBistro lists POS first. | Standard practice | TouchBistro opening checklist ("turning on the POS system") |
| Stock and check the host stand (menus, reservation list, sanitizing wipes) **(FSR)** | First guest touchpoint. | Standard practice | TouchBistro opening checklist (host readiness implied in FOH setup) |
| Reset tables: polish flatware, fold napkins, fill caddies (salt/pepper/sugar) **(FSR)** | Guest-ready setting. | Standard practice | TouchBistro opening checklist ("placing table settings") |
| Stock server stations (roll-ups, glassware, to-go containers, silverware) | Service speed during rush. | Standard practice | TouchBistro opening checklist ("repositioning tables and chairs", server-station readiness) |
| Clean and restock restrooms (toilet paper, soap, paper towels) | **Supplies are mandated**; cleaning cadence is standard practice. | **Mandated** (supplies) / standard practice (cleaning) | FDA Food Code 2022 §6-502.13 (toilet supplies maintained), §5-205.11 (hand supplies); TouchBistro opening checklist |
| Sanitize menus, check presenters, and high-touch surfaces (door handles, host podium) | Post-2020 elevated practice; menus are not food-contact but high-touch. | Standard practice | TouchBistro closing checklist ("wiping down all menus and checkbooks"); elevated post-pandemic |
| Turn on coffee/espresso brewers and tea station; backflush if not done at close | Guest beverage readiness. | Standard practice | TouchBistro closing checklist (coffee-machine care); convention |

**10 duties.** Only restroom supplies carry a mandate; the rest is well-converged
standard practice. FSR-tagged duties (host stand, table reset) can be pruned for
QSR.

---

## FOH Daily — Closing

| Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- |
| Wipe down and sanitize menus and check presenters | High-touch; ready for morning. | Standard practice | TouchBistro closing checklist ("wiping down all menus and checkbooks") |
| Reset all tables (wipe tops, chairs, booths; re-set for morning) **(FSR)** | Morning team inherits a guest-ready room. | Standard practice | TouchBistro closing checklist (FOH reset group) |
| Polish and rack glassware; restock clean glassware | Bar/beverage readiness. | Standard practice | TouchBistro closing checklist ("polishing glasses") |
| Roll silverware / build roll-ups for the next day **(FSR)** | Morning setup acceleration. | Standard practice | TouchBistro closing checklist ("rolling silverware") |
| Clean coffee/espresso machine (backflush group head, purge steam wand, empty grounds) | Equipment preservation; milk residue is a contamination risk. | Standard practice | TouchBistro closing checklist ("cleaning coffee machines") |
| Wipe down bar top, host stand, and service stations; restock for morning | Service-area reset. | Standard practice | TouchBistro closing checklist (FOH cleaning group) |
| Run end-of-day POS report (Z-report); reconcile cash drawer and tips | Daily sales accounting. | Standard practice | TouchBistro closing checklist ("running end-of-day reports in the POS") |
| Count and drop cash to the safe; secure the till | Loss prevention. | Standard practice | TouchBistro closing checklist ("locking up the restaurant") |
| Sweep, vacuum, and spot-mop the dining room | Physical-facility cleaning applies to FOH too. | Standard practice (broadly code-backed) | FDA Food Code 2022 §6-501.12 (physical facilities cleaned as needed); TouchBistro closing checklist |
| Take out FOH trash and recycling; sanitize receptacles | Pest prevention; trash is a pest attractant. | **Mandated** (pest/litter) | FDA Food Code 2022 §6-501.111 (pest control), §6-501.114 (litter-free) |
| Do a final restroom clean and restock | Supplies must be maintained; morning guests use them. | **Mandated** (supplies) / standard practice (cleaning) | FDA Food Code 2022 §6-502.13, §5-205.11 |
| Turn off lights, music, and non-essential equipment; lock all doors and set alarm | Energy, equipment, and physical security. | Standard practice | TouchBistro closing checklist ("locking up the restaurant") |

**12 duties.** Trash + restroom supplies are mandated; the rest is standard
practice.

---

## FOH Weekly

> **Weakest section.** Like BOH weekly, no primary source day-binds FOH weekly
> duties. These are convention; the developer should treat as manager-curated
> and consider shipping fewer of them.

| Weekday | Duty | Rationale | Mandate level | Source |
| --- | --- | --- | --- | --- |
| Monday | Replace or deep-clean worn/laminated menus | Post-weekend wear; Monday typically slower. | Standard practice, day-binding *convention* | TouchBistro (menu care); no primary day-binding |
| Tuesday | Deep clean all glassware backstock and polish stainless bar rails | Mid-week low-volume window. | Standard practice, day-binding *convention* | TouchBistro closing checklist (glass polishing); convention |
| Wednesday | Deep clean dining-room furniture (chair frames, booth seams, baseboards) | Slower mid-week day; periodic detail. | Standard practice, day-binding *convention* | TouchBistro (dining-room readiness); convention |
| Thursday | Inventory and restock server stations and bar backstock (napkins, stirrers, glassware) | Before the weekend rush. | Standard practice, day-binding *convention* | TouchBistro; convention |
| Friday | *(Manager-curated — highest-volume day. Recommend only restock.)* | High-volume day; minimize non-service work. | — | Convention |
| Saturday | *(Manager-curated — highest-volume day. Recommend only restock.)* | High-volume day. | — | Convention |
| Sunday | Deep clean restrooms (grout, fixtures, partitions) and shampoo carpets / clean floor mats | Post-week reset; many restaurants closed or slow Sunday. | Standard practice, day-binding *convention* | TouchBistro; convention. Physical-facility cleaning broadly code-backed (§6-501.12). |

**~5 weekly duties** (Fri/Sat intentionally light). All day-bindings are
convention; flag for manager curation.

---

## Recommended `defaults.json` shape

Per ADR 0008: one file, keyed by `(area, cadence, phase?)`. Daily slots nest
`opening`/`closing`; weekly slots nest by `weekday`. Titles use the researched
imperative voice. `mandate` and `conceptTags` fields let the developer (and
future filtering) distinguish mandated vs standard-practice and FSR-only duties.
Field names are a starting suggestion; the actual `Codable` struct is the
developer's call.

```json
{
  "fOH": {
    "daily": {
      "opening": [
        { "title": "Disarm alarm and unlock the entrance", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Turn on dining-room, restroom, and exterior lights", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Start background music and set audio zones", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Boot POS and payment terminals; confirm network", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Stock and check the host stand", "mandate": "standard-practice", "conceptTags": ["FSR"] },
        { "title": "Reset tables (flatware, napkins, caddies)", "mandate": "standard-practice", "conceptTags": ["FSR"] },
        { "title": "Stock server stations", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Clean and restock restrooms (paper, soap, towels)", "mandate": "mandated", "conceptTags": [] },
        { "title": "Sanitize menus, check presenters, and high-touch surfaces", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Turn on coffee and espresso brewers", "mandate": "standard-practice", "conceptTags": [] }
      ],
      "closing": [
        { "title": "Wipe down and sanitize menus and check presenters", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Reset all tables (wipe tops, chairs, re-set)", "mandate": "standard-practice", "conceptTags": ["FSR"] },
        { "title": "Polish and rack glassware; restock", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Roll silverware / build roll-ups", "mandate": "standard-practice", "conceptTags": ["FSR"] },
        { "title": "Clean coffee and espresso machine (backflush, purge)", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Wipe down bar, host stand, and service stations", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Run end-of-day POS report; reconcile cash and tips", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Count and drop cash to the safe", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Sweep, vacuum, and spot-mop the dining room", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Take out FOH trash and recycling; sanitize cans", "mandate": "mandated", "conceptTags": [] },
        { "title": "Final restroom clean and restock", "mandate": "mandated", "conceptTags": [] },
        { "title": "Turn off lights/music/equipment; lock up and set alarm", "mandate": "standard-practice", "conceptTags": [] }
      ]
    },
    "weekly": {
      "monday":    [{ "title": "Replace or deep-clean worn menus", "conceptTags": [] }],
      "tuesday":   [{ "title": "Deep clean glassware backstock and polish stainless", "conceptTags": [] }],
      "wednesday": [{ "title": "Deep clean dining-room furniture and baseboards", "conceptTags": [] }],
      "thursday":  [{ "title": "Inventory and restock server and bar backstock", "conceptTags": [] }],
      "friday":    [],
      "saturday":  [],
      "sunday":    [{ "title": "Deep clean restrooms and shampoo carpets / floor mats", "conceptTags": [] }]
    }
  },
  "bOH": {
    "daily": {
      "opening": [
        { "title": "Log walk-in cooler and freezer temperatures", "mandate": "mandated", "conceptTags": [] },
        { "title": "Log reach-in and prep-rail cooler temperatures", "mandate": "mandated", "conceptTags": [] },
        { "title": "Test sanitizer concentration at three-comp sink and wiping-cloth buckets", "mandate": "mandated", "conceptTags": [] },
        { "title": "Stock and verify handwashing sinks", "mandate": "mandated", "conceptTags": [] },
        { "title": "Sanitize food-contact surfaces and cutting boards", "mandate": "mandated", "conceptTags": [] },
        { "title": "Verify date marks; discard past day 7", "mandate": "mandated", "conceptTags": [] },
        { "title": "Confirm hot-holding units at 135°F or above", "mandate": "mandated", "conceptTags": [] },
        { "title": "Stock prep stations and ice down the cold line", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Turn on and preheat cooking equipment and hood", "mandate": "standard-practice", "conceptTags": [] }
      ],
      "closing": [
        { "title": "Cool cooked TCS foods rapidly (135→70°F in 2 hr; →41°F in 6 hr)", "mandate": "mandated", "conceptTags": [] },
        { "title": "Label and date all stored prep and leftovers", "mandate": "mandated", "conceptTags": [] },
        { "title": "Discard ready-to-eat TCS food past its date mark", "mandate": "mandated", "conceptTags": [] },
        { "title": "Sanitize all food-contact surfaces", "mandate": "mandated", "conceptTags": [] },
        { "title": "Empty, clean, and sanitize the three-compartment sink", "mandate": "mandated", "conceptTags": [] },
        { "title": "Cover, label, store food off-floor and in cook-temp order", "mandate": "mandated", "conceptTags": [] },
        { "title": "Filter/strain fryer oil and cover fryers", "mandate": "standard-practice", "conceptTags": [] },
        { "title": "Mop kitchen floors and clean floor drains", "mandate": "mandated", "conceptTags": [] },
        { "title": "Take out trash and recycling; sanitize receptacles", "mandate": "mandated", "conceptTags": [] },
        { "title": "Log closing walk-in and line-cooler temperatures", "mandate": "mandated", "conceptTags": [] },
        { "title": "Run dish machine; confirm sanitizing rinse", "mandate": "mandated", "conceptTags": [] },
        { "title": "Walk pest-control perimeter; check bait stations and seals", "mandate": "mandated", "conceptTags": [] }
      ]
    },
    "weekly": {
      "monday":    [
        { "title": "Count inventory and place supply orders", "conceptTags": [] },
        { "title": "Clean and sanitize walk-in shelves; rotate FIFO", "conceptTags": [] }
      ],
      "tuesday":   [
        { "title": "Delime and sanitize the ice machine", "conceptTags": [] },
        { "title": "Deep clean prep-cooler gaskets and under-line", "conceptTags": [] }
      ],
      "wednesday": [
        { "title": "Sharpen knives and honing rods", "conceptTags": [] },
        { "title": "Calibrate probe thermometers (ice/boil)", "conceptTags": [] }
      ],
      "thursday":  [
        { "title": "Change fryer oil and boil out the vat", "conceptTags": [] },
        { "title": "Clean exhaust-hood filters", "conceptTags": [] }
      ],
      "friday":    [
        { "title": "Deep clean oven and range interiors", "conceptTags": [] }
      ],
      "saturday":  [],
      "sunday":    [
        { "title": "Clean grease trap (or per municipal cadence)", "conceptTags": [] },
        { "title": "Deep clean dish pit, mop sink, and drains", "conceptTags": [] }
      ]
    }
  }
}
```

**Duty counts in this skeleton:** FOH opening 10, FOH closing 12, FOH weekly 5,
BOH opening 9, BOH closing 12, BOH weekly 9. **Total ≈ 57** (within the 40–60
target in ADR 0008). Friday FOH/BOH and Saturday FOH are intentionally empty
(highest-volume days; recommend the manager curate).

---

## Concept-specific duties the developer may want to add per deployment

These are real, standard duties I **deliberately excluded from the generic set**
because they apply only to specific concepts. Listed so the developer knows what
the generic set is missing for non-full-service deployments:

- **(QSR)** Warming / holding-cabinet temperature log (hot case ≥135°F, cold
  well ≤41°F) — mandated by §3-501.16. Critical for QSR; redundant for FSR that
  uses the BOH hot-holding line.
- **(QSR)** Drive-thru headset and timer check — operations only.
- **(bar)** Draft-line cleaning (quarterly per manufacturer; weekly flush) —
  Food Code §4-501.15 (equipment); BA-style-specific.
- **(bar)** Ice-well drain and sanitize; garnish tray rotation — Food Code treats
  ice and garnishes as food (§1-201.10(B), §3-501.16, §3-304.13 no bare-hand
  contact on garnishes).
- **(FSR, fine dining)** Daily linen inventory and press — operations only.
- **(any with tableside payment)** Tablet / handheld terminal charge and dock.

---

## Open questions for the developer

1. **Weekly day-binding has no primary source.** I assigned days by convention
   (deep-cleaning Mon–Thu, oil change Thursday before weekend, light Fri/Sat,
   reset Sunday). The developer should decide whether to (a) keep my convention,
   (b) ship weekly duties *unassigned to a day* (let the manager place them), or
   (c) ship fewer weekly duties. The app model binds weekly to a weekday, so (b)
   would require a model change — probably not worth it. I'd recommend (a) with a
   one-line onboarding hint that weekly days are manager-editable.
2. **Food Code is a model code; local codes vary.** The temperature thresholds
   (41°F cold, 135°F hot, 2-hr/6-hr cooling) are the 2022 Food Code defaults but
   some jurisdictions differ (e.g., 45°F cold holding in legacy codes, different
   ppm ranges). The seeded duty *titles* don't embed the numbers, so this is a
   non-issue at the data level — but if the app ever surfaces a "what's the
   threshold?" helper, source it from the local code, not these duties.
3. **Food Code section numbers** were cited from my knowledge of the 2022
   edition. Before locking, spot-check 3–4 (e.g., §3-501.16, §3-501.14,
   §4-501.114, §3-501.17) against the official FDA PDF to confirm numbering
   hasn't shifted.
4. **FSR vs QSR lean in the generic set.** I included FSR-tagged duties (table
   settings, silverware rolling) because FSR is the broader case and the ADR
   ships one set. For a QSR deployment the manager would archive ~4 FSR duties.
   Worth a one-line note in onboarding.
5. **ServSafe / NRA / operations-textbook sources** I could not fetch directly
   (paywalled / JS-rendered). If higher-fidelity sourcing is wanted for the
   FOH/weekly sections, a manager with ServSafe Manager materials on hand should
   cross-check — those are the next tier up from TouchBistro and would upgrade a
   few "standard practice" marks toward authoritative.
6. **Concept-specific exclusions** (bar draft lines, QSR holding cabinets) —
   decide whether to omit entirely (current recommendation) or include as
   pre-archived defaults the manager can restore. ADR 0007's archive/restore
   makes either approach cheap.
