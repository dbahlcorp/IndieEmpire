extends TestCase

## Measures how far the positive modifiers actually stack, rather than reasoning
## about it. Walks a studio from a founder in a bedroom to a maxed-out late
## career and prints every multiplier feeding the quality and progress chains,
## plus their product, so the runaway can be seen instead of estimated.
##
## Not a pass/fail suite -- the one check is that it produced numbers at all.

func run() -> void:
    _show_stage("FOUNDER  (solo, bedroom, no XP, no engine)", _founder())
    _show_stage("MID      (5 staff, professional studio, some XP)", _mid())
    _show_stage("MAXED    (12 staff, campus, master XP, full engine, pro rigs)", _maxed())
    check(true, "measured three career stages")

func _blank_engine() -> Dictionary:
    return {"progress": 1.0, "technology": 1.0, "graphics": 1.0,
        "sound": 1.0, "performance": 1.0, "bugs": 1.0}

func _founder() -> Dictionary:
    return {
        "genre": KnowledgeSimulator.quality_bonus(0),
        "theme": KnowledgeSimulator.quality_bonus(0),
        "platform": KnowledgeSimulator.quality_bonus(0),
        "engine_tech": 1.0,
        "engine_gfx": 1.0,
        "engine_progress": 1.0,
        "office": 1.0,
        "equipment": EquipmentSimulator.contribution_multiplier("basic", "programming"),
        "chemistry": ProjectStaffSimulator.chemistry_speed_multiplier(50.0),
        "coordination": 1.0,
        "culture": CultureSimulator.progress_multiplier(CultureSimulator.NEUTRAL),
        "morale": 0.70 + 60.0 * 0.00375,
        "experience_lvl": 1.0,
    }

func _mid() -> Dictionary:
    return {
        "genre": KnowledgeSimulator.quality_bonus(3),
        "theme": KnowledgeSimulator.quality_bonus(2),
        "platform": KnowledgeSimulator.quality_bonus(3),
        "engine_tech": 1.12,
        "engine_gfx": 1.06,
        "engine_progress": 1.07,
        "office": 1.0 + 12.0 / 100.0,
        "equipment": EquipmentSimulator.contribution_multiplier("standard", "programming"),
        "chemistry": ProjectStaffSimulator.chemistry_speed_multiplier(70.0),
        "coordination": 1.06,
        "culture": CultureSimulator.progress_multiplier(60.0),
        "morale": 0.70 + 80.0 * 0.00375,
        "experience_lvl": 1.0 + minf(2.0 * 0.04 + 900.0 / 5000.0, 0.35),
    }

func _maxed() -> Dictionary:
    var engine := _every_engine_feature()
    return {
        "genre": KnowledgeSimulator.quality_bonus(KnowledgeSimulator.MAX_LEVEL),
        "theme": KnowledgeSimulator.quality_bonus(KnowledgeSimulator.MAX_LEVEL),
        "platform": KnowledgeSimulator.quality_bonus(KnowledgeSimulator.MAX_LEVEL),
        "engine_tech": float(engine["technology"]),
        "engine_gfx": float(engine["graphics"]),
        "engine_progress": float(engine["progress"]),
        "office": 1.0 + 25.0 / 100.0,
        "equipment": EquipmentSimulator.contribution_multiplier("pro", "programming"),
        "chemistry": ProjectStaffSimulator.chemistry_speed_multiplier(100.0),
        "coordination": 1.20,
        "culture": CultureSimulator.progress_multiplier(100.0),
        "morale": 0.70 + 100.0 * 0.00375,
        "experience_lvl": 1.35,
    }

func _every_engine_feature() -> Dictionary:
    ## The ceiling an engine can reach: every authored feature at once, combined
    ## exactly the way EngineManager.effects_for() combines them -- by product,
    ## with nothing capping the result.
    var result := _blank_engine()
    for item in EngineManager.FEATURES:
        for key in result:
            result[key] = float(result[key]) * float(item.get(key, 1.0))
    return result

func _show_stage(label: String, m: Dictionary) -> void:
    section(label)
    # The gameplay stat's chain, straight out of DevelopmentSimulator:
    #   randf * compatibility * (genre * theme) * staff["design"] * output
    # and technology's:
    #   randf * platform * staff["programming"] * output * engine["technology"]
    # Compatibility and team output are left out here on purpose: the first is
    # a project *choice* that cuts both ways, the second is headcount capacity
    # rather than a bonus. What is left is the pile of small percentages.
    var quality_stack := float(m["genre"]) * float(m["theme"])
    var tech_stack := float(m["platform"]) * float(m["engine_tech"])
    var craft_stack := float(m["equipment"]) * float(m["morale"]) * float(m["experience_lvl"])
    var pace_stack := (
        float(m["office"]) * float(m["coordination"]) * float(m["chemistry"])
        * float(m["culture"]) * float(m["engine_progress"])
    )
    var everything := quality_stack * tech_stack * craft_stack * pace_stack

    for key in ["genre", "theme", "platform", "engine_tech", "engine_gfx",
            "engine_progress", "office", "equipment", "chemistry", "coordination",
            "culture", "morale", "experience_lvl"]:
        print("    %-16s x%.4f  (%+.1f%%)" % [key, m[key], (float(m[key]) - 1.0) * 100.0])
    print("    %s" % "-".repeat(46))
    print("    %-16s x%.4f  (%+.1f%%)  knowledge" % ["gameplay chain", quality_stack, (quality_stack - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  platform + engine" % ["tech chain", tech_stack, (tech_stack - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  per-person craft" % ["craft chain", craft_stack, (craft_stack - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  team pace" % ["pace chain", pace_stack, (pace_stack - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  EVERYTHING MULTIPLIED (the old way)" % ["total", everything, (everything - 1.0) * 100.0])

    # What the same studio now gets, category-capped and added. Experience is
    # left out on both sides of this line: it is core competence, not a bonus,
    # and BonusStack deliberately does not touch it.
    var capped_quality := BonusStack.combine({
        BonusStack.KNOWLEDGE: [m["genre"], m["theme"]]})
    var capped_tech := BonusStack.combine({
        BonusStack.KNOWLEDGE: [m["platform"]],
        BonusStack.STRATEGY: [m["engine_tech"]]})
    var capped_craft := BonusStack.combine({
        BonusStack.TEAM: [m["morale"]],
        BonusStack.FACILITIES: [m["equipment"]]})
    var capped_pace := BonusStack.combine({
        BonusStack.FACILITIES: [m["office"]],
        BonusStack.TEAM: [m["coordination"], m["chemistry"], m["culture"]],
        BonusStack.STRATEGY: [m["engine_progress"]]})
    var capped_total := capped_quality * capped_tech * capped_craft * capped_pace
    print("    %-16s x%.4f  (%+.1f%%)  knowledge, capped" % ["  gameplay", capped_quality, (capped_quality - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  platform + engine, capped" % ["  tech", capped_tech, (capped_tech - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  per-person craft, capped" % ["  craft", capped_craft, (capped_craft - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  team pace, capped" % ["  pace", capped_pace, (capped_pace - 1.0) * 100.0])
    print("    %-16s x%.4f  (%+.1f%%)  CAPPED AND ADDED" % ["capped total", capped_total, (capped_total - 1.0) * 100.0])
    print("    %-16s %.2fx less stacking than before" % ["reduction", everything / maxf(capped_total, 0.0001)])
