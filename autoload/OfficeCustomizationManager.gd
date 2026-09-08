extends Node

signal customization_changed(id: String)

const DEFAULT_ID := "classic"
const CATEGORIES := [
    {"id": "walls", "name": "Walls"},
    {"id": "flooring", "name": "Flooring & Rugs"},
    {"id": "desks", "name": "Desks"},
    {"id": "seating", "name": "Seating"},
    {"id": "computers", "name": "Computers & Equipment"},
    {"id": "lighting", "name": "Lighting"},
    {"id": "storage", "name": "Storage"},
    {"id": "lounge", "name": "Lounge & Break Area"},
    {"id": "plants", "name": "Plants"},
    {"id": "decor", "name": "Wall Décor"}
]

func catalog() -> Array:
    return DataManager.office_customizations

func current() -> Dictionary:
    var item := DataManager.get_office_customization(GameState.equipped_office_customization)
    return item if not item.is_empty() else DataManager.get_office_customization(DEFAULT_ID)

func validate_remodel() -> void:
    var fallback := GameState.equipped_office_customization
    if not is_owned(fallback):
        fallback = DEFAULT_ID
    for category in CATEGORIES:
        var category_id := str(category["id"])
        var style_id := str(GameState.office_remodel.get(category_id, fallback))
        if not is_owned(style_id) or DataManager.get_office_customization(style_id).is_empty():
            style_id = DEFAULT_ID
        GameState.office_remodel[category_id] = style_id

func style_for(category_id: String) -> Dictionary:
    validate_remodel()
    var id := str(GameState.office_remodel.get(category_id, DEFAULT_ID))
    return DataManager.get_office_customization(id)

func style_id_for(category_id: String) -> String:
    validate_remodel()
    return str(GameState.office_remodel.get(category_id, DEFAULT_ID))

func is_owned(id: String) -> bool:
    return id == DEFAULT_ID or id in GameState.owned_office_customizations

func can_buy(id: String) -> bool:
    var item := DataManager.get_office_customization(id)
    return (
        not item.is_empty()
        and not is_owned(id)
        and str(item.get("purchase_type", "cash")) == "cash"
        and FinanceManager.can_afford(FinanceManager.expense(int(item.get("price", 0))))
    )

func buy(id: String) -> bool:
    if not can_buy(id):
        return false
    var item := DataManager.get_office_customization(id)
    var price := FinanceManager.expense(int(item.get("price", 0)))
    if not FinanceManager.spend(price, Ledger.Kind.OFFICE_CUSTOMIZATION,
            "Office theme: %s" % item.get("name", id)):
        return false
    GameState.owned_office_customizations.append(id)
    GameState.equipped_office_customization = id
    _apply_full_remodel(id)
    customization_changed.emit(id)
    EventBus.notify("OFFICE UPDATED", "%s is now equipped." % item.get("name", id), true)
    SaveManager.autosave()
    return true

func equip(id: String) -> bool:
    if not is_owned(id) or DataManager.get_office_customization(id).is_empty():
        return false
    GameState.equipped_office_customization = id
    _apply_full_remodel(id)
    customization_changed.emit(id)
    SaveManager.autosave()
    return true

func art_tint() -> Color:
    return Color(str(style_for("walls").get("tint", "#ffffff")))

func accent_color() -> Color:
    return Color(str(style_for("flooring").get("accent", "#e98d48")))

func overlay_texture() -> Texture2D:
    # Full rooms now use the same modular painterly components as mixed rooms.
    # The original SVG overlays stay in the catalog as editable source art.
    return null

func component_color(category_id: String) -> Color:
    return Color(str(style_for(category_id).get("accent", "#e98d48")))

func component_texture(category_id: String) -> Texture2D:
    return component_texture_for(style_id_for(category_id), category_id)

func component_texture_for(style_id: String, category_id: String) -> Texture2D:
    if style_id == DEFAULT_ID:
        return null
    var painted_path := "res://assets/offices/components_painted/%s/%s.png" % [
        style_id, category_id]
    if ResourceLoader.exists(painted_path):
        return load(painted_path) as Texture2D
    var vector_path := "res://assets/offices/components/%s/%s.svg" % [style_id, category_id]
    return load(vector_path) as Texture2D

func atmosphere_texture() -> Texture2D:
    return null

func foreground_texture() -> Texture2D:
    return null

func set_component(category_id: String, style_id: String) -> bool:
    if not _known_category(category_id) or not is_owned(style_id):
        return false
    GameState.office_remodel[category_id] = style_id
    GameState.equipped_office_customization = _matching_preset()
    customization_changed.emit(GameState.equipped_office_customization)
    SaveManager.autosave()
    return true

func _apply_full_remodel(style_id: String) -> void:
    for category in CATEGORIES:
        GameState.office_remodel[str(category["id"])] = style_id

func _matching_preset() -> String:
    var first := style_id_for(str(CATEGORIES[0]["id"]))
    for category in CATEGORIES:
        if style_id_for(str(category["id"])) != first:
            return "custom"
    return first

func _known_category(category_id: String) -> bool:
    for category in CATEGORIES:
        if str(category["id"]) == category_id:
            return true
    return false

func premium_product_id(id: String) -> String:
    ## Future App Store integration asks this manager for the product id, then
    ## grants ownership only after a verified transaction is restored or paid.
    var item := DataManager.get_office_customization(id)
    return str(item.get("product_id", "")) if str(item.get("purchase_type", "")) == "iap" else ""

func grant_verified_premium(id: String) -> bool:
    var item := DataManager.get_office_customization(id)
    if item.is_empty() or str(item.get("purchase_type", "")) != "iap":
        return false
    if id not in GameState.owned_office_customizations:
        GameState.owned_office_customizations.append(id)
    return equip(id)
