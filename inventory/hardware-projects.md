# Hardware Projects

Dormant or in-progress hack hardware. For devices currently running in the
house see [hardware.md](hardware.md).

## Keyboards

- ~20 hand-built keyboards (PCB-level, soldered)
- Firmware history: QMK first, moved to Vial (easier remapping)
- No current Vial flasher set up — need to redo the toolchain

Friction points that paused the hobby:

- Bootloader-per-board confusion. Different MCUs (Pro Micro, Elite-C, RP2040)
  use different bootloaders; remembering which loader for which board was a
  recurring pain.
- USB-C vs microUSB boards each had their own quirks getting into bootloader
  mode.
- Catalina-era macOS made some flashers awkward (driver / signing issues).

## MCU stash (keyboard-grade)

- Pile of Pro Micros (ATmega32u4, 8-bit AVR, microUSB) downstairs
- A few with built-in Bluetooth (not as polished as Arduino Nano alternatives)
- Still functional for keyboards, but dated. Modern keyboard PCBs lean toward
  RP2040 (ARM, USB-C, web-flashable via Vial).
- Decision pending: donate to hackerspace / list on r/mechmarket if hobby
  stays paused. Don't recycle working MCUs.

## Raspberry Pis (being revived)

| Name | Model | State                              | Card                 |
|------|-------|------------------------------------|----------------------|
| pi1  | 3B+   | Was OctoPi; on network             | 32GB SanDisk, 14 MB/s |
| pi2  | 3B+   | Reflashed, not yet powered on      | 8GB no-name, 10 MB/s |

### pi1 fan wiring (observed from `pi1-gpio.jpg`)

- Noctua 4-wire PWM fan (variable speed)
- 3 wires soldered to GPIO header with heat-shrink at the joints
- Visible wire colors: **blue** (PWM control), **yellow** (tach)
- Inline resistor on one lower connection — likely tach pull-up to 3.3V
- Red (5V) and black (GND) wires routed behind, not visible in photo
- Exact pins not verified from side-angle photo. Conventional pinout
  (assumed until traced):
  - Blue PWM → GPIO 18 / physical pin 12 (hardware PWM)
  - Yellow tach → GPIO 24 / physical pin 18 (with pull-up)
  - Red 5V → pin 2 or 4
  - Black GND → pin 6, 9, 14, 20, 25, 30, 34, or 39

Original temp-triggered fan script (read `thermal_zone0/temp`, toggle GPIO)
was lost in the OctoPi wipe. Not recreating for now.

### pi2 fan wiring

- 2-wire fan, no PWM
- Decision: permanent-on (5V + GND, no GPIO involvement)
- Pin positions to verify when powering on (fan spins = correct, doesn't = on
  an undriven GPIO, move to a 5V pin)
