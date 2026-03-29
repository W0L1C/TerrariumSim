## GeneticTrait.gd
## Resource describing a permanent genetic modification purchasable with Mutagens.
## Instances live as .tres files in res://data/traits/.
##
## Traits are applied inside GameState._apply_trait_modifier() during _tick().
## They carry over across Extinction Events via GameState.unlocked_traits.
##
## Supported effect_type strings:
##   "procreation_mult"        — scales procreation_chance
##   "lifespan_mult"           — scales base_lifespan_days
##   "litter_bonus"            — flat addition to litter_size
##   "production_mult"         — scales all Biomass / DNA / Mutagen production
##   "winter_production_mult"  — extra production scale during WINTER only
##   "winter_procreation_mult" — extra procreation scale during WINTER only
##   "compost_mult"            — scales compost_value on death
class_name GeneticTrait extends Resource

@export var id:           String = ""
@export var display_name: String = ""
@export var description:  String = ""

## species_id this trait applies to. Empty = applies to all species of tier_target.
@export var species_target: String = ""

## Tier filter when species_target is empty.
## 0 = flora only, 1 = herbivores only, 2 = predators only, -1 = all tiers.
@export var tier_target: int = -1

## Mutagen cost to permanently unlock.
@export var mutagen_cost: float = 10.0

## Which stat this trait modifies (see list above).
@export var effect_type: String = ""

## How the value is applied.
## "multiply" : result *= effect_value  (e.g. 1.2 = +20%)
## "add"      : result += effect_value  (e.g. 2   = +2 flat)
@export var modifier_type: String = "multiply"

## Magnitude of the effect.
@export var effect_value: float = 1.0
