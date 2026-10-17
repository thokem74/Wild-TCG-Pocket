"""Author scene composition with explicit, editable Godot nodes."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def q(s):return json.dumps(s, ensure_ascii=False)
class Scene:
 def __init__(self,name,typ='VBoxContainer',script=None):
  self.lines=['[gd_scene load_steps=%d format=3]'%(2 if script else 1)]
  if script:self.lines += ['[ext_resource type="Script" path="res://'+script+'" id="1"]']
  self.lines += [f'[node name="{name}" type="{typ}"]']
  if typ=='VBoxContainer':self.lines+=['theme_override_constants/separation = 16','size_flags_horizontal = 3']
  if script:self.lines+=['script = ExtResource("1")']
 def node(self,name,typ,parent='.',**props):
  self.lines.append(f'\n[node name="{name}" type="{typ}" parent="{parent}"]')
  self.lines+=['%s = %s'%(k,v) for k,v in props.items()]
 def label(self,name,text,parent='.',size=24,**props):
  self.node(name,'Label',parent,mouse_filter=2,text=q(text),**{'theme_override_font_sizes/font_size':size,'autowrap_mode':3,**props})
 def button(self,name,text,parent='.',**props):
  self.node(name,'Button',parent,text=q(text),custom_minimum_size='Vector2(0, 64)',**props)
 def row(self,name,parent='.',**props):self.node(name,'HBoxContainer',parent,**{'theme_override_constants/separation':12,**props})
 def save(self,path):(ROOT/path).write_text('\n'.join(self.lines)+'\n')
# Bright porcelain surfaces, ink text and lilac/gold accents.
styles=[]
for name,bg,border in [('Panel','ffffff','e1e6f2'),('Button','eae9fa','dedcf3'),('Hover','ddd9f7','a79ad8'),('Pressed','b9b0e8','8b7ac7'),('Disabled','edf0f6','e1e6f2')]:
 def color(h):return 'Color('+', '.join(str(int(h[i:i+2],16)/255) for i in [0,2,4])+', 1)'
 styles.append(f'''[sub_resource type="StyleBoxFlat" id="{name}"]
bg_color = {color(bg)}
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = {color(border)}
corner_radius_top_left = 18
corner_radius_top_right = 18
corner_radius_bottom_left = 18
corner_radius_bottom_right = 18
content_margin_left = 18.0
content_margin_right = 18.0
content_margin_top = 12.0
content_margin_bottom = 12.0
''')
# Separate axis-specific margins give each handle an 80 px minimum length,
# while retaining a generous 36 px hit area across the scrolling direction.
for axis in ('Vertical', 'Horizontal'):
 for state, shade in [('Track', 'e4e8f3'), ('Handle', '7b65cf'), ('HandleHover', '6b56b8'), ('HandlePressed', '554091')]:
  width = 36 if axis == 'Vertical' or state == 'Track' else 80
  height = 36 if axis == 'Horizontal' or state == 'Track' else 80
  styles.append(f'''[sub_resource type="StyleBoxFlat" id="{axis}{state}"]
bg_color = {color(shade)}
corner_radius_top_left = 18
corner_radius_top_right = 18
corner_radius_bottom_left = 18
corner_radius_bottom_right = 18
content_margin_left = {width / 2}
content_margin_right = {width / 2}
content_margin_top = {height / 2}
content_margin_bottom = {height / 2}
''')
(ROOT/'assets/theme.tres').write_text('''[gd_resource type="Theme" load_steps=14 format=3]
'''+ '\n'.join(styles)+'''
[resource]
default_font_size = 24
Label/colors/font_color = Color(0.12, 0.17, 0.28, 1)
Button/colors/font_color = Color(0.19, 0.18, 0.35, 1)
Button/colors/font_hover_color = Color(0.16, 0.12, 0.3, 1)
Button/colors/font_pressed_color = Color(0.12, 0.08, 0.25, 1)
Button/colors/font_disabled_color = Color(0.56, 0.59, 0.66, 1)
Button/styles/normal = SubResource("Button")
Button/styles/hover = SubResource("Hover")
Button/styles/pressed = SubResource("Pressed")
Button/styles/disabled = SubResource("Disabled")
Button/styles/focus = SubResource("Hover")
PanelContainer/styles/panel = SubResource("Panel")
OptionButton/styles/normal = SubResource("Button")
OptionButton/styles/hover = SubResource("Hover")
OptionButton/styles/pressed = SubResource("Pressed")
OptionButton/colors/font_color = Color(0.12, 0.17, 0.28, 1)
LineEdit/colors/font_color = Color(0.12, 0.17, 0.28, 1)
LineEdit/styles/normal = SubResource("Panel")
CheckButton/colors/font_color = Color(0.12, 0.17, 0.28, 1)
ScrollContainer/constants/scrollbar_h_separation = 0
ScrollContainer/constants/scrollbar_v_separation = 0
VScrollBar/styles/scroll = SubResource("VerticalTrack")
VScrollBar/styles/scroll_focus = SubResource("VerticalTrack")
VScrollBar/styles/grabber = SubResource("VerticalHandle")
VScrollBar/styles/grabber_highlight = SubResource("VerticalHandleHover")
VScrollBar/styles/grabber_pressed = SubResource("VerticalHandlePressed")
HScrollBar/styles/scroll = SubResource("HorizontalTrack")
HScrollBar/styles/scroll_focus = SubResource("HorizontalTrack")
HScrollBar/styles/grabber = SubResource("HorizontalHandle")
HScrollBar/styles/grabber_highlight = SubResource("HorizontalHandleHover")
HScrollBar/styles/grabber_pressed = SubResource("HorizontalHandlePressed")
''')
s=Scene('Card','PanelContainer','scripts/ui/card_view.gd')
s.lines+=['custom_minimum_size = Vector2(200, 300)','mouse_filter = 1']
s.node('Content','VBoxContainer',mouse_filter=2,**{'theme_override_constants/separation':6})
s.row('Header','Content',mouse_filter=2,**{'theme_override_constants/separation':4})
s.label('Name','Emberlyn','Content/Header',18,size_flags_horizontal=3)
s.label('HP','70','Content/Header',16,autowrap_mode=0)
s.node('Art','TextureRect','Content',custom_minimum_size='Vector2(0, 158)',size_flags_vertical=3,expand_mode=1,stretch_mode=6,mouse_filter=2)
s.label('Element','FLAME • COMMON','Content',13)
s.label('Rules','1 energy • 20 damage','Content',16)
s.label('Footer','WILD  /  001','Content',12)
s.save('scenes/ui/card.tscn')
# Battle cards use the same input/presentation script, with an authored compact composition.
s=Scene('BattleCard','PanelContainer','scripts/ui/card_view.gd')
s.lines+=['custom_minimum_size = Vector2(184, 160)','mouse_filter = 1']
s.node('Content','VBoxContainer',mouse_filter=2,**{'theme_override_constants/separation':3})
s.row('Header','Content',mouse_filter=2,**{'theme_override_constants/separation':4})
s.label('Name','Emberlyn','Content/Header',18,size_flags_horizontal=3,autowrap_mode=0,text_overrun_behavior=3)
s.label('HP','70 HP','Content/Header',16,autowrap_mode=0)
s.node('Art','TextureRect','Content',custom_minimum_size='Vector2(0, 64)',size_flags_vertical=3,expand_mode=1,stretch_mode=6,mouse_filter=2)
s.label('Element','FLAME','Content',13,visible='false')
s.label('Rules','','Content',16,visible='false')
s.label('Footer','0 E · RETREAT 1','Content',16,autowrap_mode=0,text_overrun_behavior=3)
s.save('scenes/ui/battle_card.tscn')

s=Scene('Action','Button');s.lines+=['custom_minimum_size = Vector2(0, 58)','size_flags_horizontal = 3','autowrap_mode = 3'];s.save('scenes/ui/action.tscn')
s=Scene('DeckRow','HBoxContainer')
s.button('Card','Card name',size_flags_horizontal=3)
s.button('Remove','−',custom_minimum_size='Vector2(64, 64)') if False else None
s.node('Remove','Button',text=q('−'),custom_minimum_size='Vector2(64, 64)')
s.node('Add','Button',text=q('+'),custom_minimum_size='Vector2(64, 64)')
s.save('scenes/ui/deck_row.tscn')
s=Scene('BoardSlot','Button')
s.lines+=['custom_minimum_size = Vector2(0, 64)','size_flags_horizontal = 3','autowrap_mode = 3']
s.save('scenes/ui/board_slot.tscn')
# Home
s=Scene('Home')
s.label('Eyebrow','THE SKYBOUND COLLECTION',size=17)
s.label('Title','A little wonder.\nA wild new world.',size=48)
s.node('Hero','PanelContainer',custom_minimum_size='Vector2(0, 380)')
s.node('Art','TextureRect','Hero',expand_mode=1,stretch_mode=6,mouse_filter=2)
s.node('Shade','ColorRect','Hero',color='Color(0.06, 0.09, 0.22, 0.38)',mouse_filter=2)
s.node('Overlay','VBoxContainer','Hero',**{'alignment':2,'theme_override_constants/separation':5})
s.label('Tag','  FIRST LIGHT  /  48 CARDS','Hero/Overlay',18,**{'theme_override_colors/font_color':'Color(1, 0.9, 0.65, 1)'})
s.label('Name','  Guardians of the Wild','Hero/Overlay',32,**{'theme_override_colors/font_color':'Color(1, 1, 1, 1)'})
s.label('Stats','0 / 48 discovered  ·  0 coins',size=22)
s.label('StarterTitle','Choose your first guardians',size=28)
s.label('StarterNote','Your starter deck is ready to play. Every guardian can use universal energy.',size=20)
s.row('Starters')
for element in ['Flame','Tide','Gale']:s.button(element,element,'Starters',size_flags_horizontal=3)
s.button('Packs','Open a pack  →')
s.button('Battle','Enter the arena  →')
s.button('Resume','Resume battle  →')
s.label('Hint','Collect 12, 24, 36 and 48 unique cards to earn bonus packs.',size=19)
s.save('scenes/screens/home.tscn')
# Pack
s=Scene('Packs');s.label('Title','A spark of possibility',size=38)
s.label('Description','FIRST LIGHT • Five cards per pack\n60 coins, or use a free pack.',size=22)
s.label('Odds','Slots 1–4: 80% Common · 20% Uncommon\nSlot 5: 90% Rare · 10% Legendary\nEach card within its rarity is equally likely.',size=18)
s.label('Balance','3 free packs',size=24)
s.button('Open','Open pack  →')
s.label('Counter','Your cards are ready',size=20)
s.node('Reveal','CenterContainer',custom_minimum_size='Vector2(0, 540)')
s.button('Next','Reveal next card')
s.button('Skip','Reveal all / skip animation')
s.button('Done','Add to collection  →')
s.save('scenes/screens/packs.tscn')
s=Scene('Collection');s.label('Title','Your field of wonders',size=38)
s.label('Count','0 / 48 discovered',size=20)
s.row('Filters')
for name in ['Element','Rarity','Ownership']:s.node(name,'OptionButton','Filters',custom_minimum_size='Vector2(0, 60)',size_flags_horizontal=3)
s.node('Search','LineEdit',**{'theme_override_colors/font_placeholder_color':'Color(0.45, 0.48, 0.57, 1)'},placeholder_text=q('Search creatures and relics…'),custom_minimum_size='Vector2(0, 60)')
s.node('Grid','GridContainer',columns=3,**{'theme_override_constants/h_separation':12,'theme_override_constants/v_separation':14})
s.save('scenes/screens/collection.tscn')
s=Scene('Detail');s.button('Back','← Back');s.node('Card','CenterContainer',custom_minimum_size='Vector2(0, 650)')
s.label('Description','',size=24);s.label('Lore','',size=22);s.save('scenes/screens/detail.tscn')
s=Scene('Decks');s.label('Title','Shape your strategy',size=38)
s.node('Selector','OptionButton',custom_minimum_size='Vector2(0, 64)')
s.row('Tools');s.button('New','New deck','Tools',size_flags_horizontal=3);s.button('Save','Save deck','Tools',size_flags_horizontal=3)
s.node('Name','LineEdit',placeholder_text=q('Deck name'),custom_minimum_size='Vector2(0, 60)')
s.label('Validation','20 / 20 cards',size=20)
s.label('Hint','Tap + to add an owned card, − to remove it. Tap its name to inspect.',size=18)
s.node('Rows','VBoxContainer',**{'theme_override_constants/separation':8});s.save('scenes/screens/decks.tscn')
s=Scene('Setup');s.label('Title','Meet your next rival',size=38)
s.label('Note','Win: 30 coins • Loss: 10 coins\nConceding and draws award no coins.',size=22)
s.label('DeckTitle','Your deck',size=24);s.node('Deck','OptionButton',custom_minimum_size='Vector2(0, 68)')
s.label('DifficultyTitle','Rival difficulty',size=24);s.node('Difficulty','OptionButton',custom_minimum_size='Vector2(0, 68)')
s.label('Rules','20 cards. Three points to win.\nFlame beats Gale • Gale beats Tide • Tide beats Flame\nWeakness adds 20 damage. All creatures use universal energy.',size=22)
s.button('Start','Begin battle  →');s.save('scenes/screens/setup.tscn')
s=Scene('Battle');s.lines += ['theme_override_constants/separation = 4','size_flags_vertical = 3']
s.label('Status','YOUR TURN',size=22,max_lines_visible=1)
s.label('Score','You 0  ·  Rival 0  /  3',size=20,max_lines_visible=1)
s.label('EnemyInfo','Rival',size=18,max_lines_visible=1);s.row('EnemyBench')
s.row('Actives',size_flags_vertical=3)
for side,title in [('EnemyActive','RIVAL ACTIVE'),('YourActive','YOUR ACTIVE')]:
 s.node(side,'VBoxContainer','Actives',size_flags_horizontal=3,**{'theme_override_constants/separation':2})
 s.label('Label',title,'Actives/'+side,16,max_lines_visible=1)
 s.node('Card','VBoxContainer','Actives/'+side,size_flags_vertical=3)
s.row('YourBench');s.label('Resources','',size=18,max_lines_visible=1)
s.label('HandTitle','YOUR HAND · swipe sideways',size=16,max_lines_visible=1)
s.node('HandScroll','ScrollContainer',custom_minimum_size='Vector2(0, 160)',horizontal_scroll_mode=3,vertical_scroll_mode=0,scroll_deadzone=12)
s.row('Hand','HandScroll')
s.row('Selection')
s.label('Prompt','Choose a creature or hand card.','Selection',18,size_flags_horizontal=3,autowrap_mode=0,text_overrun_behavior=3)
s.button('Inspect','Inspect','Selection',**{'theme_override_font_sizes/font_size':20})
s.button('History','History','Selection',**{'theme_override_font_sizes/font_size':20})
s.node('Actions','GridContainer',columns=2,custom_minimum_size='Vector2(0, 128)',**{'theme_override_constants/h_separation':8,'theme_override_constants/v_separation':4})
for i in range(4):s.node('Action'+str(i),'Button','Actions',custom_minimum_size='Vector2(0, 62)',size_flags_horizontal=3,disabled='true',autowrap_mode=3,**{'theme_override_font_sizes/font_size':18})
s.row('Attacks',custom_minimum_size='Vector2(0, 64)')
for i in range(2):s.button('Attack'+str(i),'','Attacks',size_flags_horizontal=3,disabled='true',autowrap_mode=3,**{'theme_override_font_sizes/font_size':18})
s.row('Bottom');s.button('End','End turn','Bottom',size_flags_horizontal=3);s.button('Concede','Concede','Bottom',size_flags_horizontal=3)
s.save('scenes/screens/battle.tscn')
s=Scene('Results');s.label('Eyebrow','THE ARENA FALLS QUIET',size=17);s.label('Title','Victory',size=54);s.label('Reason','',size=26);s.label('Reward','+30 coins',size=38);s.label('Note','Your guardians await their next adventure.',size=24);s.button('Again','Play again  →');s.button('Home','Return home');s.save('scenes/screens/results.tscn')
s=Scene('Settings');s.label('Title','Make yourself at home',size=38)
for name,text in [('Music','Music'),('SFX','Sound effects'),('Animations','Reveal animations')]:s.node(name,'CheckButton',text=q(text),custom_minimum_size='Vector2(0, 72)')
s.label('Rules','HOW TO PLAY\n\nDeploy creatures from your hand onto your bench. Tap a guardian to attach your one energy orb each turn. Attacking ends your turn; energy stays attached.\n\nUse one support and retreat once per turn. Retreat discards the active creature’s listed energy cost.\n\nKnockouts score one point. Choose a replacement from your bench after a knockout. Reach three points to win.\n\nThe first player skips their first draw, energy and attack. Failing to draw loses; 60 turns is a draw.',size=22)
s.label('About','WILD TCG POCKET • FIRST LIGHT\nOriginal creatures. Offline adventures.\nProgress is saved on this device.',size=18);s.save('scenes/screens/settings.tscn')
# Root contains each screen instance, a fixed header/nav and reusable authored modal.
paths=['home','packs','collection','detail','decks','setup','battle','results','settings']
lines=['[gd_scene load_steps=12 format=3]','[ext_resource type="Script" path="res://scripts/ui/main.gd" id="1"]','[ext_resource type="Theme" path="res://assets/theme.tres" id="2"]']
for i,p in enumerate(paths,3):lines.append(f'[ext_resource type="PackedScene" path="res://scenes/screens/{p}.tscn" id="{i}"]')
lines+=['''[node name="Wild" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2")
script = ExtResource("1")
[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.945, 0.96, 0.985, 1)
mouse_filter = 2
[node name="Safe" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/margin_left = 24
theme_override_constants/margin_right = 24
theme_override_constants/margin_top = 18
theme_override_constants/margin_bottom = 14
[node name="Layout" type="VBoxContainer" parent="Safe"]
theme_override_constants/separation = 14
[node name="Header" type="HBoxContainer" parent="Safe/Layout"]
[node name="Brand" type="Label" parent="Safe/Layout/Header"]
size_flags_horizontal = 3
theme_override_font_sizes/font_size = 34
text = "W I L D"
[node name="Balance" type="Label" parent="Safe/Layout/Header"]
theme_override_font_sizes/font_size = 20
text = "TCG POCKET"
[node name="Toast" type="Label" parent="Safe/Layout"]
visible = false
autowrap_mode = 3
theme_override_font_sizes/font_size = 20
theme_override_colors/font_color = Color(0.7, 0.2, 0.2, 1)
[node name="Scroll" type="ScrollContainer" parent="Safe/Layout"]
size_flags_vertical = 3
horizontal_scroll_mode = 0
vertical_scroll_mode = 3
scroll_deadzone = 12
[node name="Screens" type="VBoxContainer" parent="Safe/Layout/Scroll"]
size_flags_horizontal = 3
''']
for i,p in enumerate(paths,3):
 if p!='battle':lines.append(f'[node name="{p.title()}" parent="Safe/Layout/Scroll/Screens" instance=ExtResource("{i}")]\nvisible = false\n')
lines.append('[node name="Battle" parent="Safe/Layout" instance=ExtResource("9")]\nvisible = false\n')
lines+=['[node name="Nav" type="HBoxContainer" parent="Safe/Layout"]\ntheme_override_constants/separation = 8']
for name,text in [('Home','Home'),('Collection','Cards'),('Decks','Decks'),('Setup','Battle'),('Settings','Settings')]:lines.append(f'[node name="{name}" type="Button" parent="Safe/Layout/Nav"]\ncustom_minimum_size = Vector2(0, 72)\nsize_flags_horizontal = 3\ntheme_override_font_sizes/font_size = 19\ntext = "{text}"')
lines+=['''[node name="ModalBlocker" type="ColorRect" parent="."]
visible = false
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.1, 0.14, 0.25, 0.35)
mouse_filter = 0
[node name="Modal" type="PanelContainer" parent="."]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -310.0
offset_top = -240.0
offset_right = 310.0
offset_bottom = 240.0
grow_horizontal = 2
grow_vertical = 2
[node name="Content" type="VBoxContainer" parent="Modal"]
theme_override_constants/separation = 20
[node name="Title" type="Label" parent="Modal/Content"]
theme_override_font_sizes/font_size = 32
text = "Welcome to the arena"
[node name="Text" type="Label" parent="Modal/Content"]
autowrap_mode = 3
size_flags_vertical = 3
text = "Tap cards to deploy guardians or use supports. Tap your active or benched guardian to attach energy. Choose an attack below your hand.\n\nAttacking ends your turn. Knock out three guardians to win, or leave your rival without a replacement."
[node name="Buttons" type="HBoxContainer" parent="Modal/Content"]
[node name="Cancel" type="Button" parent="Modal/Content/Buttons"]
custom_minimum_size = Vector2(0, 64)
size_flags_horizontal = 3
text = "Cancel"
[node name="OK" type="Button" parent="Modal/Content/Buttons"]
custom_minimum_size = Vector2(0, 64)
size_flags_horizontal = 3
text = "Let’s play"
[node name="AITimer" type="Timer" parent="."]
wait_time = 0.55
one_shot = true
''']
lines.append('''[node name="BattleOverlay" type="PanelContainer" parent="."]
visible = false
layout_mode = 1
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -310.0
offset_top = -440.0
offset_right = 310.0
offset_bottom = 440.0
[node name="Content" type="VBoxContainer" parent="BattleOverlay"]
theme_override_constants/separation = 12
[node name="Title" type="Label" parent="BattleOverlay/Content"]
theme_override_font_sizes/font_size = 28
autowrap_mode = 3
[node name="Art" type="TextureRect" parent="BattleOverlay/Content"]
custom_minimum_size = Vector2(0, 220)
expand_mode = 1
stretch_mode = 5
mouse_filter = 2
[node name="Text" type="Label" parent="BattleOverlay/Content"]
size_flags_vertical = 3
theme_override_font_sizes/font_size = 22
autowrap_mode = 3
[node name="Pages" type="HBoxContainer" parent="BattleOverlay/Content"]
[node name="Previous" type="Button" parent="BattleOverlay/Content/Pages"]
text = "Previous"
custom_minimum_size = Vector2(0, 64)
size_flags_horizontal = 3
[node name="Next" type="Button" parent="BattleOverlay/Content/Pages"]
text = "Next"
custom_minimum_size = Vector2(0, 64)
size_flags_horizontal = 3
[node name="Close" type="Button" parent="BattleOverlay/Content"]
text = "Back to battle"
custom_minimum_size = Vector2(0, 64)
''')
(ROOT/'scenes/main.tscn').write_text('\n'.join(lines)+'\n')
print('Created editable UI scenes')
