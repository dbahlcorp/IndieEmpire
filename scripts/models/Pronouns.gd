class_name Pronouns
extends RefCounted

## How the game refers to a person. Stored as a single id on the employee so
## every screen writes the same sentence about them.

const DEFAULT := "they"

const SETS := [
    {
        "id": "she", "label": "She / her",
        "subject": "she", "object": "her", "possessive": "her",
        "possessive_noun": "hers", "reflexive": "herself", "plural": false
    },
    {
        "id": "he", "label": "He / him",
        "subject": "he", "object": "him", "possessive": "his",
        "possessive_noun": "his", "reflexive": "himself", "plural": false
    },
    {
        "id": "they", "label": "They / them",
        "subject": "they", "object": "them", "possessive": "their",
        "possessive_noun": "theirs", "reflexive": "themselves", "plural": true
    }
]

const IDS := ["she", "he", "they"]

static func set_data(id: String) -> Dictionary:
    for pronoun_set in SETS:
        if str(pronoun_set["id"]) == id:
            return pronoun_set
    return SETS[2]

static func is_known(id: String) -> bool:
    return IDS.has(id)

static func label(id: String) -> String:
    return str(set_data(id)["label"])

static func subject(id: String) -> String:
    return str(set_data(id)["subject"])

static func object(id: String) -> String:
    return str(set_data(id)["object"])

static func possessive(id: String) -> String:
    return str(set_data(id)["possessive"])

static func reflexive(id: String) -> String:
    return str(set_data(id)["reflexive"])

static func is_plural(id: String) -> bool:
    ## "They have resigned" against "she has resigned".
    return bool(set_data(id)["plural"])

static func capitalise(word: String) -> String:
    if word.is_empty():
        return word
    return word.substr(0, 1).to_upper() + word.substr(1)

static func verb(id: String, singular: String, plural: String) -> String:
    ## Picks the form that agrees: verb(id, "has", "have").
    return plural if is_plural(id) else singular

static func random(rng: RandomNumberGenerator) -> String:
    ## An even split across the three. Nothing in the simulation reads this:
    ## it only decides how the game writes about somebody.
    return str(IDS[rng.randi_range(0, IDS.size() - 1)])
