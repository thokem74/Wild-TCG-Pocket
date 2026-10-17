# Wild TCG Pocket

An original, offline Android card game made with **Godot 4.7.2**. Collect 48 mythical creatures and relics in the First Light set, build 20-card decks, and challenge three AI difficulties.

## Run and build

Open `project.godot` in Godot and press **F6** on `scenes/main.tscn`, or press **F5** from anywhere. The project uses the Compatibility renderer for broad Android support.

```sh
godot --path .
godot --headless --path . --export-debug Android builds/wild-tcg-pocket-debug.apk
```

Android export requires matching Godot export templates, Android SDK, Java 17, and a debug keystore configured in Godot's editor settings. The included preset targets ARM64 with package `org.thokem.wildtcgpocket`. Install the debug APK with `adb install -r builds/wild-tcg-pocket-debug.apk`.

## Play

Choose Flame, Tide, or Gale to receive a ready-to-play starter deck and three free packs. Each pack contains five cards. Win quick battles for **30 coins**, lose for **10**, and spend **60** on a pack. Conceding and draws award no coins. Each unique-card milestone (12, 24, 36, 48) grants a free pack. There are no timers, accounts, advertisements, purchases, or network features.

- **Cards:** filter by element, rarity, ownership, or name. Tap a card for its full attacks and artwork.
- **Decks:** choose or create a deck, tap +/− to edit, then Save. Decks need exactly 20 owned cards, at least one creature, and at most two copies of each card. Unsaved changes remain while inspecting a card; leaving the deck editor otherwise discards the draft.
- **Battle:** select a saved deck and difficulty. Tap your active, benched, or hand cards to open an overview with their legal actions: attack, attach energy, retreat, deploy, or play a support on a chosen target. Enemy overviews are view-only. Deployed creatures show current HP, attached energy, and this-turn damage boosts. Successful actions close the overview; failed saves leave it open with an error. The existing board action panel remains available. The whole battle board and its controls fit on screen without vertical scrolling. Swipe the hand sideways to see more cards. Inspect opens full card rules; History opens paginated past moves. Both pause the AI until you return.
- **Settings:** toggle music, sound effects, reveal animations, and battle effects independently, or review the rules.
- **Scrolling:** scrollbars are hidden to leave more room for cards. Use the mouse wheel or trackpad on desktop. On Android, swipe over cards to scroll; a card opens only after a tap is released without dragging.

### Battle presentation

Attacks use elemental Flame, Tide, and Gale impacts, card lunges, damage numbers,
and brief board shake on heavy hits. Knockouts fade the defeated card and pulse
the score. Energy, support cards, deployment, retreat, promotion, turn changes,
and match results have their own feedback. Battle music crossfades from the menu
track. The **Battle effects** setting removes animated effects and their delays;
music and sound effects remain controlled by their separate settings.

Actions save before presentation begins. Leaving the screen or backgrounding the
app cancels presentation; resuming displays the committed battle without replay.

### Rules

Both players start with five cards, including a guaranteed creature automatically placed active. Each has three bench slots. The first player skips their initial draw, energy, and attack. All later turns draw a card and provide one universal energy orb to attach manually.

Attack energy is a requirement, not a payment; attached energy stays after attacking. Attacking ends the turn. One support and one retreat are allowed per turn; retreat discards the printed energy cost. Healing targets a friendly creature. Energy-transfer supports move the exact printed amount from a chosen bench creature to the active creature. Damage boosts expire at the end of the turn, even after retreating.

Flame beats Gale, Gale beats Tide, and Tide beats Flame for **+20 damage**. Knockouts score one point regardless of rarity. Choose a replacement from the bench after a knockout. Three points wins; no replacement or inability to draw loses. Finishing turn 60 is a draw. AI uses the same legal actions as the player and cannot inspect hidden cards.

### Pack odds

Slots 1–4 independently have **80% Common / 20% Uncommon** odds. Slot 5 has **90% Rare / 10% Legendary** odds. Each card within the selected rarity is equally likely. Duplicates are kept; there is no automatic conversion or pity system. The set has 24 Common, 12 Uncommon, 9 Rare, and 3 Legendary cards.

## Project structure

- `scenes/screens/`: editor-visible composition of every screen. `scenes/main.tscn` holds navigation, overlays, and the AI timer. Battle has a dedicated fixed container outside the shared page scroller.
- `scenes/ui/`: reusable card, compact battle card, board slot, deck row, and action scenes. `scenes/audio.tscn` authors the audio players.
- `scripts/data/` and `data/cards/`: typed card, attack, effect, and deck resources; the catalog autoload loads the explicit ID list in `data/catalog.json`.
- `scripts/battle/`: serializable battle rules, legal-action validation, and public-information AI scoring.
- `scripts/profile.gd`: local collection, deck editing, pack transactions, milestones, settings, and exactly-once match rewards.
- `scripts/ui/`: screen orchestration and card presentation. Visual objects are instantiated from reusable scenes rather than constructed in gameplay code.
- `assets/cards/`: imagegen illustrations and `prompts.json`, recording the final prompt for each image. Art was generated using the built-in imagegen tool, one illustration per card. Frames and text are native Godot UI.
- `assets/audio/`: original synthesized music and interaction cues. Regenerate the battle track and cues with `python3 tools/create_battle_audio.py` (Python standard library only).
- `scripts/presentation/` and `scenes/ui/battle_effects.tscn`: disposable battle presentation, authored impact shapes, and a bounded particle emitter.

### Add or edit a card

Duplicate an existing `.tres` card resource in the Godot editor, set a unique ID, name, element, rarity, art path, and mechanics, then add its ID to `data/catalog.json`. Use `AttackDefinition` resources for attacks and `EffectDefinition` for `DAMAGE`, `HEAL`, `DRAW`, `MOVE_ENERGY`, or `BOOST`. Add its illustration to `assets/cards/`. Deck recipes are editable resources in `data/decks/`.

`tools/create_catalog.py` and `tools/create_scenes.py` record how the initial resources and scenes were authored. Running them **replaces** their generated files; normal editing should happen directly in Godot. Update those authoring scripts too if you intend to regenerate later.

## Saves and interruptions

Progress lives in Godot's `user://progress.json`, with `progress.backup.json` as recovery. Saves write a temporary file and atomically replace the primary. Validated backups recover malformed primary files. Unknown schema versions are not loaded. This is a local save system, not an anti-cheat or cloud-sync service.

Pack payment, generated contents, collection updates, and milestone grants commit before the reveal. Relaunching resumes pending reveals. Battle state is committed after every action and resumes from Home. Each persisted match ID can award its result once. An interrupted AI turn resumes through the same legal-action interface.

## Verification

Use isolated save folders so tests cannot overwrite player progress:

```sh
XDG_DATA_HOME=/tmp/wild-tcg-tests godot --headless --path . tests/test_runner.tscn
XDG_DATA_HOME=/tmp/wild-effects-tests godot --headless --path . tests/effects_runner.tscn
XDG_DATA_HOME=/tmp/wild-tcg-ui-tests godot --headless --path . tests/ui_runner.tscn
XDG_DATA_HOME=/tmp/wild-scroll-tests godot --headless --path . tests/scroll_runner.tscn
XDG_DATA_HOME=/tmp/wild-overview-tests godot --headless --path . tests/overview_runner.tscn
XDG_DATA_HOME=/tmp/wild-tcg-visual godot --path . tests/visual_runner.tscn
# Add -- --tall for 720×1560, or -- --desktop for exact 450×800 previews.
```

The rules suite covers deck validation, opening hands, turn restrictions, actions, support effects, victory conditions, save/pack recovery, reward idempotence, and 180 deterministic AI matches. The overview suite checks own-card taps, legal actions, live stats, view-only enemy cards, AI pausing, and recovery from stale actions or failed saves. The visual runner writes portrait previews into `builds/previews/`. Android smoke-test evidence and final validation notes are recorded in `builds/VALIDATION.md`; the fixed battle layout and hidden-scrollbar update are documented in `builds/FIXED-BATTLE-VALIDATION.md`. Interactive card overview checks are recorded in `builds/OVERVIEW-VALIDATION.md`.

Battle presentation checks and Android evidence are recorded in `builds/EFFECTS-VALIDATION.md`. Run `tests/effects_runner.tscn` without `--headless` for effect captures; `-- --tall` and `-- --desktop` select the preview sizes.
