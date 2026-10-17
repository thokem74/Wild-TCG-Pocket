"""Rebuild the editable card resources and image prompt manifest."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
creatures = [
 ('Flame', [
 ('Emberlyn','ivory fox spirit with six coral flame tails and obsidian antlers','a field of ember flowers beneath sunlit floating islands'),
 ('Cinderhorn','armored crimson kirin with a molten golden horn','volcanic terraces at sunrise'),
 ('Solwing','golden phoenix with long scarlet ribbon feathers','an immense sun temple above clouds'),
 ('Ashmane','white lion with a living fire mane','shattered marble steps under an orange sky'),
 ('Flarecoil','ruby serpent with floating golden scales','a river of light through a canyon'),
 ('Pyrestag','copper stag with blazing branching antlers','an enchanted autumn forest'),
 ('Coalwyrm','small charcoal dragon with glowing turquoise eyes','a crystal lined volcanic cavern'),
 ('Suncub','playful winged lion cub with amber fur','a sunlit meadow of golden lilies'),
 ('Lavadrake','black glass dragon with molten seams','an erupting mountain above a sea of clouds'),
 ('Dawnmoth','enormous silk moth with fiery stained glass wings','a luminous garden at dawn'),
 ('Blazetail','elegant red panda spirit with comet tails','a pagoda roof under falling stars'),
 ('Aurelion','majestic celestial dragon with gold armor and a radiant solar halo','a vast sky palace bathed in sunlight')]),
 ('Tide', [
 ('Pearlfin','pearl white koi dragon with ribbon fins','a crystal clear lagoon with ancient submerged arches'),
 ('Mistwhale','flying blue whale with luminous constellation markings','a waterfall flowing through clouds'),
 ('Coralisk','coral armored basilisk with pink crystalline fins','a vivid coral kingdom'),
 ('Moonseal','silver seal spirit wearing a crescent moon halo','a moonlit pool full of glowing lotus flowers'),
 ('Riptalon','aquamarine griffin with water feather wings','towering ocean cliffs in brilliant sunshine'),
 ('Frosthart','ice blue stag with translucent crystal antlers','a frozen lake beneath an aurora'),
 ('Tidekit','small turquoise otter spirit with a pearl orb','a sunlit stream in a magical bamboo forest'),
 ('Reefwing','manta ray dragon with shimmering opal wings','an underwater palace with sunbeams'),
 ('Glaciera','elegant white ice serpent with sapphire crown','a glittering glacial cathedral'),
 ('Raincaller','blue heron spirit with flowing water plumage','a rain washed mountain shrine'),
 ('Deepgloom','bioluminescent squid dragon with violet eyes','a mysterious deep ocean with glowing ruins'),
 ('Thaloryx','majestic ancient leviathan with pearl horns and radiant azure fins','a colossal ocean whirlpool beneath a golden sky')]),
 ('Gale', [
 ('Zephyrkit','mint green winged fox with leaf shaped ears','a breezy meadow among floating islands'),
 ('Stormrook','purple raven griffin with lightning threaded feathers','a towering storm cloud with golden sun rays'),
 ('Mossgolem','gentle ancient stone guardian covered in flowers','an enchanted forest with a massive world tree'),
 ('Cloudram','fluffy white ram with spiral jade horns','a floating garden above an emerald valley'),
 ('Thornsprite','small emerald fairy dragon with rose petal wings','a luminous wild rose garden'),
 ('Skyserpent','long turquoise serpent with feathered wings','a spiral of clouds around a mountain peak'),
 ('Breezeling','tiny mischievous green owl spirit with a leafy cloak','a sunlit woodland full of wind chimes'),
 ('Petalgryph','white griffin with pink blossom feather wings','a windswept cherry blossom temple'),
 ('Thunderhart','violet elk with electric branching antlers','a high mountain plain split by lightning'),
 ('Silkwing','jade butterfly dragon with long silk ribbon wings','a bamboo grove with floating motes'),
 ('Verdantail','emerald nine tailed forest spirit with golden eyes','a mossy shrine inside a giant hollow tree'),
 ('Elyndra','majestic celestial wind dragon with silver feathers and emerald horns','a radiant floating world tree above the clouds')])]
supports = [
 ('Dew Vial','HEAL',20,'a delicate crystal vial filled with luminous dew','a sunlit alchemist garden'),
 ('Moon Nectar','HEAL',30,'a silver chalice filled with sparkling blue nectar','a moonlit lotus sanctuary'),
 ('Phoenix Balm','HEAL',40,'a ruby flask crowned with a tiny spectral phoenix','a golden healing altar'),
 ('Sanctuary Bloom','HEAL',50,'an enormous magical lotus emitting healing light','a floating garden pool'),
 ('Scout Feather','DRAW',1,'a glowing turquoise feather floating over an open map','an explorers camp on a floating island'),
 ('Astral Compass','DRAW',2,'an ornate celestial compass projecting star trails','a bright observatory'),
 ('Oracle Scroll','DRAW',3,'a floating enchanted scroll with abstract light patterns','an ancient sky library'),
 ('Memory Prism','DRAW',4,'a faceted violet prism containing miniature galaxies','a crystal shrine'),
 ('Current Relay','MOVE_ENERGY',1,'two luminous crystal orbs linked by a stream of energy','a sunlit aqueduct'),
 ('Spirit Bridge','MOVE_ENERGY',2,'a radiant bridge of magical ribbons connecting floating stones','a vivid cloud filled valley'),
 ('Warcry Sigil','BOOST',20,'a blazing golden battle sigil made of interlocking geometric rings','an ancient arena at sunrise'),
 ('Celestial Banner','BOOST',30,'a magnificent blue and gold banner radiating starlight','a sky citadel in sunlight')]
manifest=[]
all_ids=[]
for element, entries in creatures:
 for i,(name,subject,scene) in enumerate(entries):
  card_id=name.lower()
  rarity = 'Legendary' if i==11 else ('Rare' if i>=8 else ('Uncommon' if i>=6 else 'Common'))
  hp=70+(i%6)*10
  cost=1+i%3
  damage=20+10*(cost-1)+(10 if i%2 else 0)
  # Each card offers a distinct combination of HP, attacks, healing, and retreat cost.
  extra='HEAL' if i%4==0 else ('DRAW' if i%4==1 else 'DAMAGE')
  amount=10 if extra=='HEAL' else (1 if extra=='DRAW' else 0)
  text=f'{cost} energy: {damage} damage'
  if amount: text+=f", {'heal 10' if extra=='HEAL' else 'draw 1'}"
  body=f'''[gd_resource type="Resource" script_class="CardDefinition" load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/data/card_definition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data/attack_definition.gd" id="2"]
[ext_resource type="Script" path="res://scripts/data/effect_definition.gd" id="3"]

[sub_resource type="Resource" id="Effect"]
script = ExtResource("3")
kind = "{extra}"
amount = {amount}

[sub_resource type="Resource" id="Attack1"]
script = ExtResource("2")
display_name = "{['Spark','Surge','Gust'][['Flame','Tide','Gale'].index(element)]} Strike"
energy_cost = {cost}
damage = {damage}
effect = SubResource("Effect")

[sub_resource type="Resource" id="Attack2"]
script = ExtResource("2")
display_name = "{name} Tempest"
energy_cost = {cost+1}
damage = {damage+20}

[resource]
script = ExtResource("1")
id = "{card_id}"
display_name = "{name}"
element = "{element}"
rarity = "{rarity}"
max_hp = {hp}
retreat_cost = {1+i%2}
attacks = Array[Resource]([SubResource("Attack1"), SubResource("Attack2")])
rules_text = "{text}."
lore = "A guardian of {scene.removeprefix('a ').removeprefix('an ')}."
art_path = "res://assets/cards/{card_id}.png"
'''
  (ROOT/f'data/cards/{card_id}.tres').write_text(body)
  manifest.append(dict(id=card_id,name=name,prompt=f'Use case: stylized-concept. Asset type: original mythical creature trading card illustration, square artwork only. Subject: {name}, {subject}. Scene: {scene}. Style: premium dramatic anime fantasy, exquisite clean linework, rich painterly shading, luminous vivid color, cinematic magical lighting, dynamic strong readable silhouette. Bright adventurous atmosphere. Full creature centered with breathing room, detailed landscape. No text, no border, no logo, no watermark. Consistent illustration series for Wild TCG Pocket.'))
  all_ids.append(card_id)
for i,(name,kind,amount,subject,scene) in enumerate(supports):
 card_id=name.lower().replace(' ','_')
 rarity='Common' if i<6 else 'Uncommon'
 description={'HEAL':f'Heal {amount} HP from one of your creatures.','DRAW':f'Draw {amount} cards. Running out of cards loses the battle.','MOVE_ENERGY':f'Move {amount} energy from a chosen ally to your active creature.','BOOST':f'Your active creature deals +{amount} damage this turn.'}[kind]
 (ROOT/f'data/cards/{card_id}.tres').write_text(f'''[gd_resource type="Resource" script_class="CardDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/card_definition.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data/effect_definition.gd" id="2"]

[sub_resource type="Resource" id="Effect"]
script = ExtResource("2")
kind = "{kind}"
amount = {amount}

[resource]
script = ExtResource("1")
id = "{card_id}"
display_name = "{name}"
element = "Support"
rarity = "{rarity}"
effect = SubResource("Effect")
rules_text = "{description}"
lore = "A relic carried by the guardians of the wild."
art_path = "res://assets/cards/{card_id}.png"
''')
 manifest.append(dict(id=card_id,name=name,prompt=f'Use case: stylized-concept. Asset type: original fantasy support trading card illustration, square artwork only. Subject: {subject}. Scene: {scene}. Premium dramatic anime fantasy illustration, exquisite clean linework, painterly shading, luminous vivid color, cinematic magical lighting, strong readable central composition. Bright adventurous atmosphere. No people, no readable text, no border, no logo, no watermark. Consistent Wild TCG Pocket illustration series.'))
 all_ids.append(card_id)
for element,entries in creatures:
 ids=[n.lower() for n,_,_ in entries[:7]]+[x[0].lower().replace(' ','_') for x in supports[:2]]+['warcry_sigil']
 ids=[x for x in ids for _ in range(2)]
 (ROOT/f'data/decks/{element.lower()}.tres').write_text('[gd_resource type="Resource" script_class="DeckRecipe" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/data/deck_recipe.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\ndisplay_name = "'+element+' Guardians"\ncard_ids = PackedStringArray('+', '.join(json.dumps(x) for x in ids)+')\n')
(ROOT/'data/catalog.json').write_text(json.dumps(all_ids,indent=2)+'\n')
# Preserve the exact final prompt used for the first generated illustration.
manifest[0]['prompt'] = 'Use case: stylized-concept. Asset type: original mythical creature trading card illustration, square artwork only. Subject: Emberlyn, a graceful ivory fox spirit with six flowing coral flame tails and obsidian antlers, leaping above a field of glowing ember flowers beneath sunlit floating islands. Style: premium dramatic anime fantasy, exquisite clean linework, rich painterly shading, luminous vivid color, cinematic magical lighting, dynamic strong readable silhouette. Bright adventurous atmosphere. Full creature centered with breathing room, detailed landscape, no text, no border, no logo, no watermark. Consistent illustration series for Wild TCG Pocket.'
(ROOT/'assets/cards/prompts.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Created {len(all_ids)} cards and 3 decks')
