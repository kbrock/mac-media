# Hardware Inventory

Catch-all for devices and house infrastructure that don't have a bigger
bucket yet. For network gear see [network.md](network.md). For NAS/drives
see [storage.md](storage.md). For media hardware (TV, Roku, soundbar) see
[media.md](media.md). For paused hobby projects see
[hardware-projects.md](hardware-projects.md).

## Servers

| Device           | Spec                              | Role                          |
|------------------|-----------------------------------|-------------------------------|
| mac-media        | 2012 Mac Mini, mechanical HD      | See [mac-media.md](mac-media.md) |
| Mac Studio       | (user's primary work machine)     | Dev / personal               |
| iMac 2018 27"    | 16GB RAM, 1TB, AMD Radeon R9 M390 | Unplugged, candidate to linuxize |
| Apple TV gen 2/3 | Silver remote, no app store, no HD | Recycle queue                |

## Monitors

| Device          | Spec                                             | Used by |
|-----------------|--------------------------------------------------|---------|
| LG 34WL850-W    | 34" QHD ultrawide, 2021, Thunderbolt 3           | kbrock  |
| LG 27UP850-W    | 27" UHD, USB-C                                   | wife    |

## Home Automation

| Device                    | Integration       | Status      |
|---------------------------|-------------------|-------------|
| iRobot Roomba j9+ (Wall-E)| Local MQTT        | Done. j-series blocks local password retrieval; get it via `dorita980 getPasswordCloud` |
| Govee lights x2           | LAN (HACS)        | Done        |
| Govee H6066               | No LAN            | Skip        |
| Number bed                | -                 | Done        |
| Wallbox Pulsar Plus       | -                 | Done. 2/2021, type 4 enclosure, 50A |
| Hunter HPC sprinkler      | Hydrawise app     | Done        |
| HP MFP M277dw             | — | Hostname: `printer.home.thebrocks.net`. Cartridge: 201 |
| Ecobee 3 thermostat       | Home Assistant    | 14yo, finicky, integrated     |
| Emporia smart plugs x4    | -                 | Inventory   |
| VocoLinc SmartBar plugs   | HomeKit native    | 2-4 of them, locations unknown |

## Plumbing / Mechanical

- 1/2 HP 230V well pump
- WellXtrol WX-250 pressure tank (relief 150/125 PSI, sits at 50-60 psi)
- Resin/salt water softener
- Hydrawise (Hunter HPC) sprinkler controller

## HVAC

- Bryant oil furnace
- Central air
- Ecobee 3 at thermostat location. Wiring in use: Rc (red), G (green), Y1 (blue), W1 (white), C (green). Extra white and red at the thermostat are not connected — likely also disconnected in the basement, validate before relying on them.
- Ecobee remote sensors: dining room, kids room, parents room.

## Garage

- Chamberlain Formula 1 opener (button 03/05, board 41A5483-AC)

## Electrical Panel (incomplete)

- 15x 15A
- 3x 15A GFCI
- 9x 20A
- 1-2x 20A (uncertain)
- 40A
- 2x 30A
- 50A (wallbox charger)

## Health / Misc

- Smart scale: Greater Goods 0412 Accuchek Verve

## House projects

Hardware/sensor work to do around the house.

- [ ] Garage door: install ratgdo32 (ESP32) on Chamberlain Formula 1 (board 41A5483-AC)
- [ ] Identify which breaker controls the living/family room plug that needs replacement
      (could be a project for HA energy monitoring)
- [ ] Replace FiOS battery (GS Yuasa PX12072, 2010, beeping)
- [ ] Patch panel cleanup at Levitron (wires too short; telephone wires need clarifying:
      1 to fax/unused, 1 to house phone, 1 unknown)
- [ ] Hook up office's 2 ethernet plugs (currently wired T568B, user uses T568A — needs
      either repunch or terminal swap)
- [ ] Inventory VocoLinc SmartBar locations (have 2-4, status unknown)
- [ ] Clarify Hunter HPC vs Hydrawise sprinkler relationship

