extends RefCounted
## Seeded, bounded variety. A shuffled personality bag prevents long unlucky runs.
const TYPES: Dictionary = {
    "Regular":{"patience":95.0,"line":"The usual, please. No hurry."},
    "Impatient":{"patience":70.0,"line":"My train is soon! Quick service earns extra."},
    "Generous":{"patience":110.0,"line":"Careful craft deserves a lovely tip."},
    "Big Order":{"patience":135.0,"line":"A little feast for me and a friend."},
    "VIP":{"patience":140.0,"line":"A special visit. Excellent service earns double!"}
}
var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var bag: Array[String] = []
var recent: Array[String] = []

func restart(value: int = -1) -> void:
    seed_value = value if value >= 0 else int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system())
    rng.seed = seed_value
    bag.clear()
    recent.clear()

func next(phase: int, sequence: int, practice: bool = false, forced: String = "") -> Dictionary:
    var personality: String = forced
    if not TYPES.has(personality):
        if sequence < 2: personality = "Regular"
        else:
            if bag.is_empty():
                bag.assign(["Regular","Impatient","Generous","Big Order"])
                for i in range(3,0,-1):
                    var j: int = rng.randi_range(0,i)
                    var swap: String = bag[i]
                    bag[i] = bag[j]
                    bag[j] = swap
            personality = bag.pop_back()
    var drinks: Array = ["espresso","coldbrew","chai"] if phase == 0 and not practice else ["espresso","latte","coldbrew","chai","matcha"]
    var foods: Array = ["cookie","croissant"] if phase == 0 and not practice else ["cookie","croissant","brownie","toastie"]
    var recipe: Dictionary = {}
    var fingerprint: String = ""
    for attempt in range(8):
        recipe = {drinks[rng.randi_range(0,drinks.size()-1)]:1}
        if personality in ["Big Order","VIP"]:
            recipe[foods[rng.randi_range(0,foods.size()-1)]] = 2
        elif personality != "Impatient" and (phase > 0 or practice or rng.randf() < 0.35):
            recipe[foods[rng.randi_range(0,foods.size()-1)]] = 1
        fingerprint = JSON.stringify(recipe)
        if recent.size() < 2 or recent[-1] != fingerprint or recent[-2] != fingerprint: break
        # Rotating the drink guarantees a different final attempt, even at extreme RNG seeds.
        if attempt == 7:
            var old: String = str(recipe.keys()[0])
            var quantity: int = int(recipe[old])
            recipe.erase(old)
            recipe[drinks[(drinks.find(old)+1)%drinks.size()]] = quantity
            fingerprint = JSON.stringify(recipe)
    recent.append(fingerprint)
    while recent.size() > 2: recent.pop_front()
    return {"recipe":recipe,"personality":personality,"remark":TYPES[personality]["line"],
        "max_patience":float(TYPES[personality]["patience"]) + (10 if phase == 0 else 0)}

func snapshot() -> Dictionary:
    return {"seed":str(seed_value),"rng":str(rng.state),"bag":bag.duplicate(),"recent":recent.duplicate()}

func restore(data: Dictionary) -> void:
    restart(int(str(data.get("seed","0"))))
    if data.has("rng"): rng.state = int(str(data["rng"]))
    if typeof(data.get("bag")) == TYPE_ARRAY:
        for entry in data["bag"]:
            if str(entry) in TYPES and str(entry) != "VIP": bag.append(str(entry))
    if typeof(data.get("recent")) == TYPE_ARRAY:
        for entry in data["recent"]:
            if recent.size() < 2: recent.append(str(entry))
