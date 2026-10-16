# force_drugs

Drug pickup jobs. Talk to Kalle, pick cocaine, meth or weed, then race the clock to the marked area, fight off the armed guards and collect the crates. Bring them back to Kalle and he pays you in drugs. Sell them with [force_drugsell](https://github.com/Force-Developing/force_drugsell).

Free and open source. Works on ESX Legacy, QBCore and QBox.

## Features

- Three jobs out of the box (cocaine, meth, weed), each with its own area, crates, guards, time limit, reward and cooldown
- Hostile guards with melee weapons around the crates
- Server-side checks: job and crate ids from the config, distance to Kalle and to each crate, pickup pace, time limit, crate count, cooldown per character, optional police minimum
- The reward amount and item are decided by the server; a full inventory keeps the job open until there is room
- Death or the time limit ends the job; everything it spawned is removed, also on a resource restart
- ox_target, qb-target or [E] with the ox_lib text UI
- ox_inventory, qb-inventory and the ESX inventory
- English and Swedish locales

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- OneSync
- ESX Legacy, QBCore or QBox (other frameworks through `server/custom/frameworks/custom.lua`)
- The items `coke`, `meth` and `weed` in your inventory (see the [items](items) folder)
- Optional: ox_target or qb-target

No database is used.

## Installation

1. Put the folder in your resources as `force_drugs`.
2. Add the items from the `items` folder to your inventory.
3. Add `ensure force_drugs` to `server.cfg` below `ensure ox_lib`. The order relative to your framework and target resource doesn't matter.
4. Edit `config.lua`: rewards, time limits, cooldowns and the police minimum.

## Documentation

https://docs.forcedevelopments.com/free-resources/force_drugs/introduction

## License

Apache 2.0, see [LICENSE](LICENSE).
