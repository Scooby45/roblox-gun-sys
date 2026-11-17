# roblox-gun-sys

A realistic, server-validated gun system for Roblox built on **FastCast**. It works in first and third person and models:

- **Ballistics:** real muzzle velocities, drag, gravity drop and travel time. Speed is tracked along the whole flight.
- **Penetration:** cost depends on material and thickness. Exit points are measured, the bullet loses energy going through, yaws on exit and can over-penetrate bodies.
- **Ricochets:** depend on the grazing angle and the material. A bullet that ricochets keeps flying and can still hit someone.
- **Damage:** scales with impact velocity. Hit zones and armor (`BodyArmor`, `Helmet` character attributes) apply.
- **Malfunctions:** failure to fire (dud), failure to feed, stovepipe and double feed. Heat, fouling (rounds since cleaned) and ammo quality make them more likely. Clearing them takes the right procedure and time.
- **Real mechanics:** the chamber holds +1 round. Tactical reloads differ from empty reloads. Bolt hold-open, magazine retention (partial mags go back in your pouch), shell-by-shell tube loading you can interrupt, pump and bolt actions, and fire selector with safe, semi, burst and auto.
- **Recoil:** spring-based camera recoil. Part of each kick is permanent (you pull down) and the rest recovers. Viewmodel kick, shake, sustained-fire bloom, movement, airborne and heat spread, sway and breathing.
- **Presentation:** a first-person viewmodel and a third-person over-the-shoulder camera. Upper-body aim pitch is replicated to other players.
- **Effects:** tracers every Nth round, supersonic crack/whizz when bullets pass you, gunshot sound delayed by the speed of sound, impacts per material, bullet holes on entry and exit, and pooled shell casings.

You provide models, animations, sounds and particle effects. The system finds them by name and skips anything that's missing.

---

## Install

### 1. FastCast
Get **FastCastRedux** from https://github.com/EtiTheSpirit/FastCastAPI (MIT). Put the `FastCastRedux` ModuleScript (it contains its own `TypeDefinitions`, `ActiveCast` and `Signal` modules) in **one** of these places:

- `ReplicatedStorage.FastCastRedux`
- `ReplicatedStorage.Packages.FastCastRedux`
- `ReplicatedStorage.GunSystem.Vendor.FastCastRedux`

PartCache isn't needed. The system pools its own tracers.

### 2. Code
With **Rojo**, run `rojo serve` (or `rojo build -o guns.rbxlx`) using `default.project.json`. This creates:

```
ReplicatedStorage.GunSystem          (Settings, Config, Modules)
ServerScriptService.GunServer        (Script + modules)
StarterPlayer.StarterPlayerScripts.GunClient  (LocalScript + modules)
```

To install **by hand**, recreate that tree in Studio:
- A folder with an `init.server.lua` becomes a **Script**.
- A folder with an `init.client.lua` becomes a **LocalScript**.
- A folder with an `init.lua` becomes a **ModuleScript**.

Its siblings go inside it as children.

### 3. Tools
Each gun is a normal `Tool` in `StarterPack` (or given at runtime):

| Requirement | |
|---|---|
| Attribute `WeaponId` (string) | Must match a config in `GunSystem/Config/Weapons`, e.g. `AK74`. |
| `Handle` part | The third-person gun. Set the grip as usual. |
| Attachment `Muzzle` (anywhere in the tool) | Bullets start here in third person. Put muzzle-flash `ParticleEmitter`s (Enabled = false, optional `EmitCount` attribute) and a `PointLight` (Enabled = false) inside it. |
| Attachment `Eject` (optional) | The ejection port. Its **RightVector** is the direction casings fly. |

---

## Assets (`ReplicatedStorage.GunAssets`)

```
GunAssets
├── Weapons
│   └── <WeaponId>
│       ├── Viewmodel        Model  (first person arms + gun)
│       ├── Animations       Folder of Animation objects
│       ├── Sounds           Folder of Sound objects
│       └── Shell            BasePart (ejected casing; an optional child Sound plays on landing)
├── Effects
│   └── Impacts
│       ├── Default          Folder: ParticleEmitters (+ "EmitCount" attribute), Sounds, Decal named "Hole"
│       ├── Metal, Concrete, Brick, Wood, Plastic, Glass, Dirt, Mud, Sand, Snow, Fabric, Water, Flesh
├── Tracers
│   └── Default              BasePart (optional; a neon block is used otherwise)
└── Sounds
    ├── Crack                supersonic bullet passing close
    ├── Whizz                subsonic bullet passing close
    ├── Hitmarker
    └── Kill
```

### Viewmodel
- `PrimaryPart` sits exactly at the camera. It's anchored by the script and everything else should be Motor6D'd to it.
- An `AnimationController` (or `Humanoid`) with an `Animator`. One is created if it's missing.
- **Attachments** (found by name anywhere in the model):
  - `Muzzle`: the first-person muzzle flash and bullet origin.
  - `AimPoint`: where the eye goes when aiming down sights. Place it behind the rear sight, with its **LookVector pointing down range**. The script measures this attachment every frame from the animated pose, so the sights line up even while animations play.
  - `Eject`: the ejection port. Its RightVector is the ejection direction.

If there's no viewmodel, first person just shows the character's tool.

### Animation names
Use Animation objects in `Animations/`, or set IDs in the weapon config's `Animations` table (`Animations = { Reload = "rbxassetid://123", TP_Reload = 456 }`).

| First person | Third person | When |
|---|---|---|
| `Idle` | `TP_Idle` | looped while equipped |
| `Equip` | `TP_Equip` | on equip |
| `Fire` / `AimFire` | `TP_Fire` / `TP_AimFire` | each shot (hip / aimed) |
| `Dry` | `TP_Dry` | click on empty / jammed |
| `Reload` | `TP_Reload` | tactical reload |
| `ReloadEmpty` | `TP_ReloadEmpty` | empty reload (includes charging / bolt release) |
| `ReloadStart`, `ShellInsert`, `ReloadEnd` | `TP_…` | tube-fed loading |
| `Cycle` | `TP_Cycle` | pump / bolt |
| `ClearMalfunction` | `TP_ClearMalfunction` | tap-rack (dud, failure to feed, stovepipe) |
| `ClearDoubleFeed` | `TP_ClearDoubleFeed` | strip mag, rack, reload |
| `CheckAmmo` | `TP_CheckAmmo` | mag check (T) |
| `FireMode` | `TP_FireMode` | selector switch |
| `Sprint` | `TP_Sprint` | looped while sprinting |
| | `TP_Aim` | looped while aiming in third person |

Action animations are **time-stretched to the durations in the config** (`Times`). The config is the source of truth for timing because the server enforces it.

### Sound names (`Weapons/<Id>/Sounds`)
`Fire`, `FireDistant` (used beyond 350 studs, optional), `Dry`, `Equip`, `Reload`, `ReloadEmpty`, `ReloadStart`, `ShellInsert`, `ReloadEnd`, `Cycle`, `ClearMalfunction`, `ClearDoubleFeed`, `FireMode`, `Malfunction`.

Set `RollOffMaxDistance` on `Fire` and `FireDistant` high (1000+) so distant gunfire carries.

---

## Controls (Settings.Keybinds)

| Action | Keyboard / Mouse | Gamepad |
|---|---|---|
| Fire | LMB | R2 |
| Aim | RMB (hold) | L2 |
| Reload | R | X |
| Clear malfunction / rack | F | Y |
| Fire selector | V | D-pad up |
| Check ammo | T | D-pad down |
| Sprint | Left Shift | L3 |
| Swap shoulder | Q | |

Touch buttons are created for Fire, Aim, Reload and Clear.

Pump and bolt guns cycle automatically when you release the trigger. Firing during a shell-by-shell reload stops it after the current shell.

---

## Configuration

- **`GunSystem/Settings.lua`** covers global options:
  - units and gravity (realistic 9.81 m/s² or `workspace.Gravity`)
  - malfunction multiplier (0 disables jams)
  - hit zones, friendly fire and security tolerances
  - effect limits for performance
  - camera options: shoulder offset, aim-into-first-person mode
  - HUD: exact ammo counts or a realistic estimate after checking the mag
  - keybinds
- **`Config/Ammo.lua`** defines cartridges in real units (m/s, mm steel-equivalent penetration, drag), plus damage, tracer interval and quality.
- **`Config/Materials.lua`** sets penetration resistance, ricochet angle, speed retention, deflection and impact effect per `Enum.Material`. Per-part attributes override it:
  - `BallisticMaterial` (string)
  - `Impenetrable` (bool)
  - `PenetrationResistance` (number)
- **`Config/Weapons/*.lua`** has one module per weapon. Examples: `AK74` (no bolt hold-open, surplus ammo), `M4A1` (bolt catch), `Glock17`, `Remington870` (pump, tube-fed, buckshot) and `M24` (bolt action, 7.62). Anything a weapon omits comes from `Config/Defaults.lua`. To add a weapon, copy a module, change `Id`, and set the tool's `WeaponId`.

**Hooks (server):**
- `ServerStorage.GunSystemEvents.Damaged` is a BindableEvent fired with `(attacker, humanoid, damage, info)`.
- Override `DamageService.CanDamage` for game-mode rules.
- A `creator` tag is set on damaged humanoids for classic kill credit.

---

## How it works

### Network flow
1. **Fire.** The client predicts the shot and simulates the bullets right away. It sends `origin, aim direction, seed, spread`. The pellet directions come from the seed, so the server and every observer reproduce the exact same pattern.
2. **Server checks:** fire rate (token bucket on RPM), muzzle near the head, selector, chamber and malfunction state. Then it registers the shot and relays it, unreliably, to nearby players. They simulate cosmetic bullets with the same seed, so they see the same penetrations and ricochets.
3. **Hit.** When your bullet touches a character, the client sends that pellet's path nodes (origin → penetration exits / ricochet points → hit). Hits are batched once per frame.
4. **Server validation:**
   - the shot exists and is recent
   - the first leg matches the seeded pellet direction
   - the hit can't arrive faster than the bullet could fly
   - the target really was there, checked against a 1 second lag-compensated hitbox history
   - the whole path is re-traced through the world with the **same penetration and ricochet model**, so wallbangs only count if the round could really get through

   Damage is then computed from the server's own velocity estimate.

### Malfunctions without latency
Each weapon has a random seed. Malfunction rolls are `Random(seed, shotNumber)`, so the client predicts jams at the same shot as the server without a round trip. The server is still authoritative: it sends state corrections when its heat or timing differs. Reloads, clears and cycling are timed on the server and must take at least 80% of the configured time.

### Penetration model
- Penetration capacity is `Penetration (mm steel-eq) × (v / v0)²`, so it scales with kinetic energy.
- The cost of an obstacle is `thickness (mm) × material resistance`. Thickness is measured by casting back from beyond the entry point against only that part, which also works for wedges and meshes.
- After penetrating, `v' = v·√(1 − cost/budget)`. The bullet also yaws, more when it barely made it through.
- Below a material's critical angle a bullet can ricochet. The chance rises as the angle gets shallower, and the bullet loses speed and scatters a little.
- Water slows bullets and stops them within a short distance.

### Performance
- One FastCast caster serves every bullet.
- Only tracer rounds get a visible part, taken from a pool.
- Impact emitters, sounds, bullet holes and casings are pooled. Effects are distance-culled, and hits go out in one batched remote per frame.
- Cosmetic replication uses `UnreliableRemoteEvent`s and is distance-limited on the server.

---

## Notes and limitations
- This was written outside Studio. It has been syntax-checked as Luau but not play-tested, so expect some tuning: recoil feel, viewmodel offsets, and malfunction rates for your game's pace.
- The FastCast integration assumes FastCastRedux v13.x (`Caster:Fire`, `newBehavior`, `LengthChanged / RayHit / CastTerminating`, `ActiveCast.UserData`).
- Upper-body aim replication rotates the R15 `Waist` joint. R6 characters still work but don't pitch their torso.
- Internal magazines (the M24) are modelled as a detachable magazine. Use stripper-clip or per-round animations if you want that look.
- Third-person shots converge on the point under the crosshair. If your muzzle is blocked by a wall right in front of you, the bullet starts at the wall surface.
