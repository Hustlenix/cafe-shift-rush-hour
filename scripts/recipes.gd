extends RefCounted
## Authored preparation rules. Runtime progress never mutates these definitions.
const DATA: Dictionary = {
    "espresso": [["pick", "Load freshly ground beans", "BEANS"], ["hold", "Hold the brewer; release at the cup line", "EXTRACT"]],
    "latte": [["pick", "Load freshly ground beans", "BEANS"], ["hold", "Pull espresso to the cup line", "EXTRACT"], ["stir", "Swirl the pitcher to foam the milk", "MILK"], ["pick", "Finish with a ribbon of honey", "HONEY"]],
    "coldbrew": [["stack", "Drop three ice cubes into the glass", "ICE", 3], ["hold", "Hold the cold-brew tap; stop at the line", "COLD BREW"]],
    "chai": [["stack", "Add ginger, cardamom, then tea", "SPICES", 3], ["heat", "Steep the chai; lift the pot at GOLDEN", "TEAPOT"]],
    "matcha": [["pick", "Scoop matcha into the bowl", "MATCHA"], ["stir", "Whisk left and right until silky", "WHISK"], ["hold", "Pour oat milk up to the line", "OAT MILK"]],
    "croissant": [["heat", "Warm the croissant; lift it at GOLDEN", "OVEN"], ["plate", "Slide the warm croissant onto the plate", "PLATE"]],
    "toastie": [["stack", "Stack bread, cheese, then bread", "SANDWICH", 3], ["heat", "Grill the sandwich; lift it at GOLDEN", "GRILL"], ["cut", "Drag down the seam to cut the toastie", "SLICE"], ["plate", "Slide both halves onto the plate", "PLATE"]],
    "brownie": [["cut", "Drag down the seam to slice the brownie", "SLICE"], ["plate", "Slide the fudge brownie onto the plate", "PLATE"]],
    "cookie": [["pick", "Take a fresh cookie from the jar", "COOKIE JAR"], ["plate", "Slide the cookie onto the plate", "PLATE"]]
}

static func steps(product: String) -> Array:
    return DATA.get(product, []).duplicate(true)

static func texture(product: String) -> Texture2D:
    return load("res://assets/original/food/%s.svg" % product) as Texture2D
