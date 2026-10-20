---
tags: [design, prototype, spec]
version: 0.1
updated: 2026-10-19
---
# Prototype v0.1 Spec


**The prototype has to prove one thing:** clicking → getting stronger → punching harder beasts → loot → faster cultivation is fun for 10 minutes.

**Pacing targets** (all tunable):
- First major breakthrough (Qi Condensation 9 → Foundation Establishment 1): **~10–15 minutes**
- First rebirth available (Foundation Establishment 9): **~30–40 minutes**

Everything is grey blocks. No real models, no saving.

---

## 1. Clicking (the core input)
- **Every click or tap, anywhere on screen: +qi.**
- If a beast is within punching range, the same click **also punches the nearest beast**. The server picks the target from the character's position.
- **Rate limit: 5 clicks per second, enforced on the server.** Extra clicks are ignored. This is the basic auto-clicker guard.

## 2. Qi (the only stat)
- Qi is both your **progress** and your **damage**.
- **Active:** qi per click.
- **Training (idle):** standing on a training platform auto-punches its dummy for qi (see section 8). There is no other always-on idle qi.
- Qi is never spent. Stages are qi thresholds.

## 3. Realms & breakthroughs (xianxia names)

| Realm | Stages | How you advance |
|---|---|---|
| Qi Condensation | 1–9 | **Automatic** when qi reaches the next stage's requirement |
| *Major breakthrough* | QC 9 → FE 1 | **Glowing Breakthrough button.** Free, but the player presses it. Triggers tribulation lightning (added after the test). |
| Foundation Establishment | 1–9 | **Automatic** |
| *Rebirth* | at FE 9 | See section 9 |

- Every stage-up gives a **multiplier** to qi per click and training qi.
- Stage-ups get a flash, a sound and a "Stage X!" popup.
- The major breakthrough is a much bigger multiplier jump.
- **No bottleneck gates and no failure** in v0.1. Breakthroughs are kid-easy.

## 4. Combat
- **Damage per punch = qi + fist technique bonuses**
- Beasts have health bars, die, drop loot, and respawn after a few seconds.
- **Beasts don't fight back.** It's a pure stat check.
- Damage numbers pop up on hits.

## 5. Spirit beasts (one hunting ground, 3 tiers)

| Tier | Location | Role |
|---|---|---|
| 1 | Forest edge (closest) | Killable right away; steady small loot |
| 2 | Middle | Needs mid Qi Condensation; more loot |
| 3 | Deepest | Needs late Qi Condensation / Foundation; big payouts |

Deeper means stronger, so where you're standing shows how strong you are.

## 6. Loot
Spirit stones and beast cores **drop together** from every beast and are **collected automatically** when it dies.

| Loot | Only use (v0.1) |
|---|---|
| **Spirit stones** | Buy and upgrade **cultivation techniques** |
| **Beast cores** | Buy and upgrade **fist techniques** |

Each currency has exactly one job in v0.1, so the playtest tests the loop and not a shop.

## 7. Techniques (4 total, each upgradeable by level)
Learned at the **Technique Pavilion**. Walk up and a ProximityPrompt opens the menu.

**Cultivation techniques (bought with spirit stones)**
- **Cultivation Method 1:** + qi per click
- **Cultivation Method 2:** + training platform qi (boosts the auto-punches)

**Fist techniques (bought with beast cores)**
- **Fist Technique 1:** + punch damage
- **Fist Technique 2: Heavy Strike.** Every Nth punch lands a big hit with a bigger damage number. This is the first feel-good moment.

Names and flavor are placeholders. Use original demon-fist-style names inspired by Northern Blade, not copied ones.

## 8. Training platforms (spirit veins, the idle zone)
*Changed 2026-10-20: replaces the single spirit vein and always-on idle qi.*
- A row of platforms in the hub, each with a practice dummy. **Standing on one auto-punches its dummy for qi** (an automatic click).
- Each platform is a higher-grade spirit vein with a bigger **qi multiplier** (placeholder: x1.5 / x2 / x4 / x6).
- Better platforms **unlock by rebirth count** (placeholder: 0 / 1 / 2 / 3). This gives rebirth a visible reward.
- Manual taps still add qi on top while you train, so active play is always better.
- Platforms give qi but no loot, so you still have to hunt for spirit stones and beast cores.

## 9. Rebirth
- **Unlocks at Foundation Establishment 9.** A Rebirth button appears.
- **Resets:** qi, realm/stage, spirit stones, beast cores, technique levels (reset everything for v0.1; revisit after playtesting)
- **Keeps:** rebirth count
- **Gives:** a permanent multiplier on qi gain per rebirth
- The rebirth count shows on the overhead tag.

## 10. Map (greybox)
*Changed 2026-10-20: circular hub layout.*
- **Circular walled hub** with spawn in the middle. Everything you need to progress is one short walk away: the training platform row along the back wall and the Technique Pavilion on one side.
- **One gate** in the hub wall leads out to the Hunting Ground: Tier 1 → Tier 2 → Tier 3 in a line, in the same world (no teleports).

Small and dense, with short walks. Tier zones should be clearly separated, using different colored blocks for now.

## 11. UI (ugly but working, mobile-sized)
- Qi bar: progress toward the next stage requirement
- Realm + stage name ("Qi Condensation 6")
- Spirit stones / beast cores counters
- Major Breakthrough button (shows at QC 9)
- Rebirth button (shows at FE 9)
- Technique Pavilion menu (4 techniques, cost, level, buy button)
- Damage numbers and stage-up popup

## 12. Lobby presence
- **Overhead tag on every player:** realm + stage + rebirth count, so others can see who's ahead.

---

## 13. Skills (added 2026-10-21)
Active moves bought and upgraded at the Technique Pavilion with beast cores. Keyboard Q / R / F, on-screen buttons on phones, each with a cooldown.
- **Thunderstep Rush (Q):** dash forward and hit everything in your path.
- **Earthshatter Stomp (R):** slam the ground and hit everything around you.
- **Heaven-Piercing Palm (F):** a wave of qi that hits everything in a line.
Skill damage is a multiple of your punch damage. Skills reset on rebirth like techniques.

## 14. Tribulation lightning (added 2026-10-21)
Pressing Breakthrough at QC9 darkens the sky and lightning strikes the player 3 times (the whole lobby sees it), then the player reaches Foundation Establishment 1.

## Not in v0.1 (on purpose)
Saving, pills, bottleneck gates, failure states, sword and other paths, spiritual roots, sects, shops, temporary boosts, pocket capacity, game passes, leaderboards. See Parked Ideas.

## First thing to add after it passes the 10-minute test
**Tribulation lightning** on the QC 9 → FE 1 breakthrough: the sky darkens, lightning strikes the player, and the whole lobby sees it.

## Build order (test + git commit after each)
1. Map greybox (circular hub + training platforms)
2. Clicking → qi (active + training platforms + 5/sec cap)
3. Realm stages + auto-breakthrough + major breakthrough button
4. Beasts: health, punching, respawn
5. Loot drops (spirit stones + beast cores)
6. Technique Pavilion + 4 techniques
7. Rebirth
8. UI polish pass + overhead tags + damage numbers
9. Tune numbers → **10-minute test** with a real person
10. Tribulation lightning (the reward for passing)
