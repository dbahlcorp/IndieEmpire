extends Node

## Contract work: paid jobs for other companies. They keep the lights on
## between releases, and they are what a studio falls back on when a game flops.
## A contract occupies a team, so taking one is a real choice against building
## something of your own.

const OFFER_COUNT := 3
const ROTATION_WEEKS := 8

func _ready() -> void:
    EventBus.week_ticked.connect(_on_week)

func _on_week(_year: int, _month: int, _week: int) -> void:
    pass

# --- Offers ------------------------------------------------------------

func refresh_offers(notify: bool = true) -> void:
    GameState.contract_offers.clear()

    var eligible: Array = []
    for template in DataManager.contracts:
        if ContractSimulator.is_available(template, GameState.consumer_reputation, GameState.released_games.size()):
            eligible.append(template)
    if eligible.is_empty():
        GameState.contract_offer_weeks_left = ROTATION_WEEKS
        return

    eligible.shuffle()
    for index in mini(OFFER_COUNT, eligible.size()):
        GameState.contract_offers.append(_offer_from(eligible[index]))

    GameState.contract_offer_weeks_left = ROTATION_WEEKS
    if notify and not GameState.contract_offers.is_empty():
        EventBus.notify("NEW CONTRACT WORK", "%d jobs are on the board" % GameState.contract_offers.size())

func _offer_from(template: Dictionary) -> Contract:
    var contract := Contract.new()
    contract.id = GameState.next_contract_id()
    contract.template_id = str(template.get("id", ""))
    contract.name = str(template.get("name", "Contract"))
    contract.client = str(template.get("client", "A client"))
    contract.brief = str(template.get("brief", ""))
    contract.work = int(template.get("work", 30))
    contract.deadline_weeks = int(template.get("weeks", 8))
    contract.reputation_reward = float(template.get("reputation_reward", 0.5))
    contract.payout = ContractSimulator.payout_for(template, GameState.consumer_reputation)
    contract.status = "offered"
    return contract

func offers() -> Array:
    if GameState.contract_offers.is_empty():
        refresh_offers(false)
    return GameState.contract_offers

func active_contract() -> Contract:
    return GameState.active_contract

func has_active_contract() -> bool:
    return GameState.active_contract != null

# --- Taking and doing the work -----------------------------------------

func can_accept(team_id: String = "team_a") -> bool:
    if has_active_contract():
        return false
    var team := TeamManager.find_team(team_id)
    if team == null or not team.project_id.is_empty():
        return false
    return not TeamManager.working_members(team_id).is_empty()

func accept(contract: Contract, team_id: String = "team_a") -> bool:
    if contract == null or not can_accept(team_id):
        return false
    if not GameState.contract_offers.has(contract):
        return false

    contract.status = "active"
    contract.team_id = team_id
    contract.accepted_year = TimeManager.current_year
    contract.accepted_month = TimeManager.current_month
    contract.accepted_week = TimeManager.current_week

    GameState.contract_offers.erase(contract)
    GameState.active_contract = contract

    EventBus.contract_accepted.emit(contract)
    SaveManager.autosave()
    return true

func abandon() -> void:
    var contract := GameState.active_contract
    if contract == null:
        return
    contract.status = "failed"
    GameState.active_contract = null
    GameState.add_consumer_reputation(-ContractSimulator.abandon_penalty(contract))
    EventBus.contract_failed.emit(contract, true)
    SaveManager.autosave()

func weekly_output() -> float:
    var contract := GameState.active_contract
    if contract == null:
        return 0.0
    var staff := TeamManager.working_members(contract.team_id)
    return ContractSimulator.weekly_work(staff, OfficeManager.productivity())

func process_week() -> void:
    ## Offers rotate whether or not the studio is working on one.
    GameState.contract_offer_weeks_left -= 1
    if GameState.contract_offer_weeks_left <= 0:
        refresh_offers(not has_active_contract())

    var contract := GameState.active_contract
    if contract == null:
        return

    contract.weeks_worked += 1
    contract.work_done += weekly_output()

    if contract.is_complete():
        _complete(contract)
        return

    if contract.is_overdue():
        _fail(contract)

func _complete(contract: Contract) -> void:
    contract.status = "completed"
    GameState.active_contract = null
    GameState.completed_contracts.append(contract)

    FinanceManager.earn(
        contract.payout, Ledger.Kind.CONTRACT,
        "%s (%s)" % [contract.name, contract.client])
    GameState.add_consumer_reputation(contract.reputation_reward)

    EventBus.contract_completed.emit(contract)
    SaveManager.autosave()

func _fail(contract: Contract) -> void:
    contract.status = "failed"
    GameState.active_contract = null
    GameState.completed_contracts.append(contract)
    GameState.add_consumer_reputation(-ContractSimulator.late_penalty(contract))

    EventBus.contract_failed.emit(contract, false)
    SaveManager.autosave()

# --- Reporting ---------------------------------------------------------

func total_contract_income() -> int:
    var total := 0
    for contract in GameState.completed_contracts:
        if contract.status == "completed":
            total += contract.payout
    return total

func completed_count() -> int:
    var count := 0
    for contract in GameState.completed_contracts:
        if contract.status == "completed":
            count += 1
    return count

func failed_count() -> int:
    var count := 0
    for contract in GameState.completed_contracts:
        if contract.status == "failed":
            count += 1
    return count
