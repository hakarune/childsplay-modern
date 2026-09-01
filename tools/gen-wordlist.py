#!/usr/bin/env python3
"""gen-wordlist.py - build godot/assets/data/wordlist.json for Word Maker.

The master list lives here. Add words to WORDS (any whitespace/newlines
are fine) and re-run:  python3 tools/gen-wordlist.py

Output rules: lowercased, a-z only, length 2..8, de-duplicated, sorted.
Keep it kid-safe (ages 2-7) and avoid proper nouns.
"""
import json
import os
import re
import sys

WORDS = """
a an as at be by do go he hi if in is it me my no of on or so to up us we
ax ox pi ok ma pa
the and for you are was not but all can had her his one our out day get has
him how man new now old see two way who did its let put say she too use

ant ape bat bear bee bird bug cat cow crab deer dog duck eel elk fish fox
frog goat hen hippo horse lamb lion mole moose mouse mule newt owl ox panda
pig pony pup rat seal shark sheep snail snake swan tiger toad turtle wasp
whale wolf worm zebra chick chimp cub calf colt fawn kitten puppy piglet
bison camel donkey ferret gecko hamster iguana jaguar koala lemur llama
otter parrot rabbit robin shrimp spider walrus beetle cattle rooster monkey
kitten donkey

apple bread butter cake candy carrot cheese cherry corn cream egg fig
grape jam juice lemon lime meat melon milk mint nut oat onion peach pea
pear pie plum rice roll salad salt soup stew sugar toast bean beans berry
honey lunch snack water bacon bagel donut fruit olive syrup waffle yogurt
apricot biscuit cabbage muffin noodle nugget peanut pepper pickle popcorn
potato pretzel pumpkin raisin sausage spinach cracker cookie dinner

arm back beard belly bone brain cheek chest chin ear elbow eye face finger
foot hair hand head heel hip jaw knee leg lip lung mouth nail neck nose
palm rib shin skin thumb toe tooth waist wrist ankle brow spine tongue
tummy

bed book box broom brush chair clock cloth couch cup desk dish door fan
fork glass jar key lamp mat mirror mug pan pen pillow plate pot rug shelf
sink soap sofa spoon stove table towel tray vase wall window basket bottle
bucket button candle carpet closet cradle drawer hanger kettle ladder
napkin pencil pillow saucer

autumn beach breeze cave cliff cloud coast creek dawn desert dew dirt dusk
earth fern field fire flame fog forest frost grass hail hill ice island
lake leaf light lightning meadow mist moon moss mountain mud ocean path
plant pond puddle rain rainbow river rock root sand sea seed shade shore
sky snow soil star stone storm stream summer sun swamp thunder tide tree
valley vine water wave weed wind winter wood world spring flower petal
pebble planet

blue black brown gold gray green orange pink purple red silver tan white
yellow bright dark light pale rosy shiny

add ask bake bark bat beg bend bite blink blow boil bounce bow brush build
bump burn buy call carry catch chase cheer chew chop clap clean climb
close cook count crawl cry cut dance dig dip dive drag draw dream drink
drip drive drop dry eat fall feed feel fetch fill find fish fix flap flip
float flow fly fold follow give glow grab grin grow hang help hide hike
hold hop hug hum hunt jog join joke jump keep kick kiss knock knit knew
land laugh leap learn lift like listen look love make march melt mix move
nap nod open pack paint park pass pat peek pick play plant point pour pull
push race read rest ride ring roll row rub run sail save saw say scoop
scrub see sew shake share shine shout show shut sing sink sip sit skate
skip sleep slice slide slip smell smile snap sniff snore soak sort speak
spell spin splash spray sprint stack stand stare start stay step stir stop
stretch swap sweep swim swing take talk tap taste teach tear tell think
throw tie tickle tie toss touch trace trade trip trot try turn twist wag
wait wake walk want wash watch wave wear weep whisper wiggle wink wipe
wish wonder work wrap write yawn yell zip zoom drum

bag ball balloon band bat bead bell bike blanket block boat bone boot bow
bubble cap car card cart cat cape clay coat coin crayon crown doll dress
drum flag flute game glove glue hat helmet hoop hose jacket jeans kite
marble mask net paint pants patch pen present prize puppet puzzle ribbon
ring robot rope scarf shirt shoe shorts skirt sled slide sock stick swing
sword tent tie top toy train truck van vest wagon wand wheel whistle yo

acorn arrow ball bark barn basket bath boat brick bridge castle chimney
church city clay coin dock dome fence flag flame float fort gate glass hut
igloo lane maze nest oven porch road roof room shed shop sign silo stair
step store street tent tile tower town truck tube tunnel wall well yard
church

happy sad glad mad calm brave kind nice mean shy proud silly tired scared
angry funny lucky quiet loud fast slow soft hard warm cold hot cool wet
dry big small tall short long wide fat thin new old clean dirty full empty
loud quiet dark bright heavy light rough smooth sharp sticky fresh sweet
sour salty tasty yummy smelly fuzzy shiny bumpy round square curly straight
lazy busy early late high low deep shallow near far young little large
tiny giant huge

one two three four five six seven eight nine ten zero half dozen first
second third last many few some none all more most less

day week month year hour minute morning noon night today tonight monday
tuesday spring summer autumn winter birthday holiday

baby boy girl kid mom dad mama papa aunt uncle gran nana pal friend
family class team crowd doctor nurse baker farmer pilot king queen prince
clown chef guest hero coach mayor sailor singer artist dancer helper
teacher

able about above across after again along also always among angel angry
apron begin below best bird black blank blast blaze blend blink bloom
board boast bonus booth brave bread break brick brief bring brisk broad
broke brook broom brush build built bunch burst cabin cable camel candy
canoe carol charm chart cheer chess chief child chill chirp chose chunk
clash class clean clear cleat clerk click cliff climb cloak clock close
cloth cloud clown clump coach coast could crack craft crane crash crawl
crazy cream creek crisp cross crowd crown crumb crush daily dairy daisy
dance dandy dizzy dodge dough dozen draft drain drama drank drape dream
dress drift drill drink drive droop drove drown eagle early earth easel
enjoy equal every extra fable fairy faith fancy feast fence ferry field
fiery fifty final flair flame flash fleet flick fling float flock flood
floor flour flower fluff flung flush focus foggy force forge forty found
frame frank fresh front frost fruit funny giant given glass gleam glide
globe gloom glory glove going grace grade grain grand grape graph grass
great greed green greet grill grim grind groan groom group grove growl
grown gruff guard guess guest guide happy harsh heart heavy hobby honey
horse house human humid ivory jelly jewel jolly juice jumbo kayak kitty
knock label lemon lucky lunch magic major maple march match maybe merry
metal might mind minor mixed model money month moral mound mount mouth
movie music never noble north novel ocean often onion order otter ought
owner paint panda paper party pasta patch pause peace peach pearl penny
piano pilot pinch pizza plain plane plant plate plaza pluck plump point
polar porch pound power press pride prime print prize proud puppy quick
quiet quilt radio raise ranch reach ready relax reply river roast robot
rocky round royal rugby salad sandy sauce scale scarf scene scoop scout
scrap scrub sense shade shake shape share shark sharp sheep sheet shelf
shell shine shiny shirt shock shore short shout shove shown shrub shy
silly since skate skill skunk sleep slice slide slime slope small smart
smell smile smoke snack snail snake sneak sniff snore snowy solar solid
sorry sound south space spare spark speak spear speed spell spend spice
spike spill spine spoke spoon sport spray sprig squad stack staff stage
stair stamp stand stare start steam steel steep stem stick stiff still
sting stink stir stone stood stool storm story stove strap straw stray
strip study stuff sugar sunny super sweet swing sword table taste teach
teeth thank thick thing think third those three throw thumb tiger tight
timid tired title toast today tooth topic torch touch tough towel tower
trace track trade trail train tramp trap trash tray tread treat tribe
trick tried tromp troop trout truck true trunk trust truth tulip tummy
tumor tunic turf twin twist ugly uncle under unite until upon upper urban
usual value vapor video villa vinyl visit vivid vocal voice wagon waist
waltz waste watch water weary weave weird whale wheat wheel where which
while white whole windy witch woman world worry worse worth would wound
woven wrist write wrong yacht yeast young youth zebra zesty
ship shut skip slug swan swap swing step stew stir
"""


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "godot", "assets", "data", "wordlist.json")
    seen = set()
    words = []
    for tok in re.split(r"\s+", WORDS.strip()):
        w = tok.lower()
        if not re.fullmatch(r"[a-z]{2,8}", w):
            continue
        if w in seen:
            continue
        seen.add(w)
        words.append(w)
    words.sort()
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump({"_comment": "Word Maker dictionary. Regenerate with tools/gen-wordlist.py (edit WORDS there).",
                   "words": words}, f, separators=(",", ":"))
        f.write("\n")
    print(f"wrote {out}: {len(words)} words")
    return 0


if __name__ == "__main__":
    sys.exit(main())
