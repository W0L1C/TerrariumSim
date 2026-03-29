## SpeciesData.gd
## Data resource for one species: cost, consumption, production, and ecology.
## Instances live as .tres files in res://data/species/.
##
## Economy (Unified Currency):
##   All species purchased with Biomass.
##   T0 Flora      : no consumption; produces Biomass.
##   T1 Herbivores : consumes Biomass; produces Biomass (net +) + trickle DNA.
##   T2 Predators  : no resource consumption; prey_required population floor;
##                   actively hunts prey (prey_consumption_rate); produces large
##                   Biomass + trickle Mutagens.
##
## Simulation lifecycle:
##   Every species reproduces (procreation_chance, litter_size) and ages to death
##   (base_lifespan_days), returning compost_value Biomass to the pool on death.
##   Predators reduce prey populations each tick via prey_consumption_rate.
class_name SpeciesData extends Resource

@export var id:           String    = ""
@export var display_name: String    = ""
@export var description:  String    = ""
@export var icon:         Texture2D = null
## Texture used by TerrariumManager to render this species as a live sprite.
@export var texture:      Texture2D = null

## 0 = flora  |  1 = herbivore / small prey  |  2 = predator
@export var tier: int = 0

# ── Purchase cost (always Biomass) ────────────────────────────────────────────
@export var base_cost_mantissa: float = 10.0
@export var base_cost_exponent: int   = 0
@export var cost_scaling:       float = 1.15

# ── Resource consumption per second per unit ───────────────────────────────────
## Biomass drained per second. Only Tier 1 herbivores use this.
@export var consumes_biomass: float = 0.0

# ── Resource production per second per unit ────────────────────────────────────
## All three are scaled by day/night efficiency and season modifiers in _tick().
@export var produces_biomass:  float = 0.0
@export var produces_dna:      float = 0.0
@export var produces_mutagens: float = 0.0

# ── Day / Night efficiency ────────────────────────────────────────────────────
@export var day_efficiency:   float = 1.0
@export var night_efficiency: float = 1.0

# ── Food-web prey requirement (starvation floor) ──────────────────────────────
## Maps species_id → minimum owned population.
## If ANY listed prey falls below its threshold the predator begins accumulating
## starvation — production drops and population eventually dies off.
@export var prey_required: Dictionary = {}

# ── Active hunting (physical population reduction) ────────────────────────────
## Maps prey_species_id → prey_units_consumed_per_predator_per_in_game_day.
## Scaled by the predator's day/night efficiency modifier.
## Consumed prey are subtracted from the prey population each tick.
@export var prey_consumption_rate: Dictionary = {}

## Maps flora_species_id → flora_plants_consumed_per_herbivore_per_in_game_day.
## Display-only: guides the player on which plants to grow for each herbivore.
## The simulation uses the shared biomass pool; this field drives the card labels.
@export var flora_consumption_rate: Dictionary = {}

# ── Simulation lifecycle ───────────────────────────────────────────────────────
## How many in-game days a unit survives before dying of old age.
@export var base_lifespan_days: float = 10.0

## Probability of a birth event per individual per in-game day (before season).
@export var procreation_chance: float = 0.1

## Units spawned per successful birth event.
@export var litter_size: int = 1

## Biomass returned to the ecosystem when a unit dies (age or starvation).
@export var compost_value: float = 1.0

# ── Discovery / Research ───────────────────────────────────────────────────────
## true  → always visible from run 1 (all flora + starter Rabbit).
## false → Shadow Card until researched.
@export var is_discovered: bool = true

## Hint shown on the Shadow Card before research.
@export var discover_hint: String = ""

## DNA cost to research. 0 mantissa = free / always discovered.
@export var research_cost_mantissa: float = 0.0
@export var research_cost_exponent: int   = 0


# ── Computed helpers ──────────────────────────────────────────────────────────

## Cost to buy the (owned + 1)th unit. Always Biomass.
func get_cost(owned: int) -> BigNumber:
	var base := BigNumber.new(base_cost_mantissa, base_cost_exponent)
	if owned == 0:
		return base
	return base.multiply_float(pow(cost_scaling, float(owned)))


func get_biomass_produced_per_second() -> BigNumber:
	return BigNumber.from_float(produces_biomass) if produces_biomass > 0.0 else BigNumber.zero()

func get_dna_produced_per_second() -> BigNumber:
	return BigNumber.from_float(produces_dna) if produces_dna > 0.0 else BigNumber.zero()

func get_mutagens_produced_per_second() -> BigNumber:
	return BigNumber.from_float(produces_mutagens) if produces_mutagens > 0.0 else BigNumber.zero()

func get_biomass_consumed_per_second() -> BigNumber:
	return BigNumber.from_float(consumes_biomass) if consumes_biomass > 0.0 else BigNumber.zero()

func get_research_cost() -> BigNumber:
	if research_cost_mantissa <= 0.0:
		return BigNumber.zero()
	return BigNumber.new(research_cost_mantissa, research_cost_exponent)
