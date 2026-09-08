class_name RecruitmentSimulator
extends RefCounted

## Pure recruitment maths. The manager gathers company state and passes only
## numbers in, which keeps the attraction curve straightforward to test.

static func attractiveness(
    employer_reputation: float,
    company_size: int,
    highest_review: float,
    salary_competitiveness: float,
    office_quality: int,
    profitability: float,
    work_life_balance: float = 50.0,
    average_morale: float = 50.0,
    recent_layoffs: int = 0
) -> float:
    ## The studio's standing as an employer, 0-100. Deliberately independent
    ## of consumer reputation (GameState.consumer_reputation) -- a studio can
    ## ship acclaimed games while being miserable to work for, or vice versa.
    ## What this score is made of, and roughly how much each part matters:
    ##   employer reputation 22    game success        18
    ##   fair pay            13    profitability       12
    ##   how big it is       10    work-life balance    8
    ##   the office           9    staff morale         8
    ## Recent layoffs then subtract from the total, up to a hard 25 points.
    var size_score := clampf(float(company_size - 1) / 11.0, 0.0, 1.0) * 100.0
    var review_score := clampf(highest_review * 10.0, 0.0, 100.0)
    var salary_score := clampf((salary_competitiveness - 0.65) / 0.70, 0.0, 1.0) * 100.0
    var blend := clampf(
        employer_reputation * 0.22
        + size_score * 0.10
        + review_score * 0.18
        + salary_score * 0.13
        + clampf(float(office_quality), 0.0, 100.0) * 0.09
        + clampf(profitability, 0.0, 100.0) * 0.12
        + clampf(work_life_balance, 0.0, 100.0) * 0.08
        + clampf(average_morale, 0.0, 100.0) * 0.08,
        0.0,
        100.0
    )
    var layoff_penalty := clampf(float(maxi(recent_layoffs, 0)) * 5.0, 0.0, 25.0)
    return clampf(blend - layoff_penalty, 0.0, 100.0)

## The employer reputation the player sees, high to low. The first band the
## recruiting score clears wins. Stars are the same score on a five-point
## scale; the label is what to call it.
const EMPLOYER_TIERS := [
    {"min": 88.0, "stars": 5.0, "label": "Exceptional"},
    {"min": 76.0, "stars": 4.5, "label": "Excellent"},
    {"min": 65.0, "stars": 4.0, "label": "Very Good"},
    {"min": 54.0, "stars": 3.5, "label": "Good"},
    {"min": 43.0, "stars": 3.0, "label": "Fair"},
    {"min": 32.0, "stars": 2.5, "label": "Mixed"},
    {"min": 22.0, "stars": 2.0, "label": "Poor"},
    {"min": 12.0, "stars": 1.5, "label": "Bad"},
    {"min": 0.0, "stars": 1.0, "label": "Notorious"}
]

static func employer_reputation(score: float) -> Dictionary:
    ## {score, stars, label, display} for a recruiting score.
    var chosen: Dictionary = EMPLOYER_TIERS[EMPLOYER_TIERS.size() - 1]
    for tier in EMPLOYER_TIERS:
        if score >= float(tier["min"]):
            chosen = tier
            break
    var stars := float(chosen["stars"])
    return {
        "score": score,
        "stars": stars,
        "label": str(chosen["label"]),
        "display": employer_stars(stars)
    }

static func employer_stars(stars: float) -> String:
    var full := int(floor(stars))
    var half := stars - float(full) >= 0.5
    var text := "★".repeat(full)
    if half:
        text += "½"
        full += 1
    return text + "☆".repeat(maxi(5 - full, 0))

static func seniority_weights(attraction: float) -> Dictionary:
    if attraction < 25.0:
        return {"intern": 30, "junior": 60, "mid": 9, "senior": 1}
    if attraction < 50.0:
        return {"intern": 15, "junior": 55, "mid": 27, "senior": 3}
    if attraction < 70.0:
        return {"intern": 5, "junior": 40, "mid": 43, "senior": 12}
    if attraction < 85.0:
        return {"intern": 1, "junior": 24, "mid": 50, "senior": 25}
    return {"intern": 0, "junior": 12, "mid": 43, "senior": 45}

static func role_weights(attraction: float) -> Dictionary:
    var generalist_weight := 38 if attraction < 35.0 else (22 if attraction < 70.0 else 10)
    return {
        "programmer": 14,
        "designer": 11,
        "artist": 12,
        "writer": 8,
        "audio_designer": 7,
        "qa_tester": 10,
        "producer": 0 if attraction < 45.0 else (7 if attraction < 75.0 else 14),
        "generalist": generalist_weight
    }

static func acceptance_probability(
    requested_salary: int, offered_salary: int, attraction: float
) -> float:
    if requested_salary <= 0:
        return 1.0
    var ratio := float(offered_salary) / float(requested_salary)
    # At the requested salary candidates usually accept, while exceeding it
    # buys certainty quickly. Employer appeal shifts the curve by at most 8%.
    var chance := 0.72 + (ratio - 1.0) * 2.5
    chance += (clampf(attraction, 0.0, 100.0) - 50.0) * 0.0016
    return clampf(chance, 0.02, 0.98)

static func acceptance_label(chance: float) -> String:
    if chance < 0.18:
        return "Very Low"
    if chance < 0.38:
        return "Low"
    if chance < 0.62:
        return "Moderate"
    if chance < 0.84:
        return "High"
    return "Very High"
