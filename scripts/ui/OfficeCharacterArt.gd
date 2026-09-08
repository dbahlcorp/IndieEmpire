class_name OfficeCharacterArt
extends RefCounted

## Twelve production 4x4 sprite sheets. Portrait seeds select a stable identity
## so the same employee looks the same every time the office is opened.

const APPEARANCE_NAMES: Array[String] = [
    "Classic Teal",
    "Golden Creative",
    "Studio Blue",
    "Plum Logic",
    "Rust Method",
    "Copper Spark",
    "Teal Focus",
    "Silver Mentor",
    "Violet Edge",
    "Navy Craft",
    "Olive Drive",
    "Coral Rise"
]

const SHEETS: Array[Texture2D] = [
    preload("res://assets/employees/developer_a_sheet.png"),
    preload("res://assets/employees/developer_b_sheet.png"),
    preload("res://assets/employees/developer_c_sheet.png"),
    preload("res://assets/employees/developer_d_sheet.png"),
    preload("res://assets/employees/developer_e_sheet.png"),
    preload("res://assets/employees/developer_f_sheet.png"),
    preload("res://assets/employees/developer_g_sheet.png"),
    preload("res://assets/employees/developer_h_sheet.png"),
    preload("res://assets/employees/developer_i_sheet.png"),
    preload("res://assets/employees/developer_j_sheet.png"),
    preload("res://assets/employees/developer_k_sheet.png"),
    preload("res://assets/employees/developer_l_sheet.png")
]

static func sheet_for_seed(seed: int) -> Texture2D:
    return SHEETS[absi(seed) % SHEETS.size()]

static func sheet_for_appearance(appearance_index: int) -> Texture2D:
    return SHEETS[clampi(appearance_index, 0, SHEETS.size() - 1)]

static func sheet_for_employee(employee: Employee) -> Texture2D:
    if employee.appearance_index >= 0:
        return sheet_for_appearance(employee.appearance_index)
    return sheet_for_seed(employee.portrait_seed)

static func frame_region(column: int, row: int) -> Rect2:
    return Rect2(clampi(column, 0, 3) * 256, clampi(row, 0, 3) * 256, 256, 256)
