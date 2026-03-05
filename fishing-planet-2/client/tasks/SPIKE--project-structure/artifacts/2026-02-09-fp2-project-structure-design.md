# Fishing Planet 2 — Client Project Structure Design

**Date:** 2026-02-09
**Status:** Approved
**Engine:** Unity 6, HDRP
**Scope:** Client-side only (server is separate)

---

## 1. Team & Repositories

### Team (~20 people)
| Role | Count | Works in |
|---|---|---|
| Programmers | 4-5 | fp2-client |
| Game/Level Designers | 3-4 | fp2-client (Scenes/Locations/) |
| Tech Artist | 1 | fp2-client + fp2-art (bridge) |
| Content Managers | 1-2 | fp2-client (ScriptableObjects, data) |
| 3D Artists | 4-5 | fp2-art |
| 2D Artists | 2 | fp2-art |
| Animators | 2 | fp2-art |

### Repositories (GitLab Self-Hosted)
```
├── fp2-client          Unity HDRP 6, main development
├── fp2-art             Unity HDRP 6, art production
└── fp2-packages/       UPM packages (extracted when mature)
```

---

## 2. Art Pipeline

```
fp2-art (Art Project)                    fp2-client (Main Project)
─────────────────────                    ──────────────────────────

Assets/
├── WIP/              ← work in progress
│   └── Fish_Bass/
│
├── Review/           ← ready for review
│   └── Fish_Bass/
│       ├── Fish_Bass_LOD0.fbx
│       ├── Fish_Bass_LOD1.fbx
│       ├── Fish_Bass_Albedo.png
│       └── Fish_Bass_Normal.png
│
└── Export/           ← approved by Tech Artist
    └── Fish_Bass.unitypackage ─────────► Assets/Art/Fish/Fish_Bass/
```

### Tech Artist Validation Checklist
- [ ] Naming convention followed
- [ ] LOD0, LOD1 minimum present
- [ ] Textures correct size, power of 2
- [ ] Pivots correct
- [ ] Scale = 1, no extra transforms
- [ ] Materials use HDRP/Lit or project shaders
- [ ] Prefab assembled with LOD Group

### Texture Specifications
| Content Type | Max Size | Format |
|---|---|---|
| Fish | 2048 | BC7 |
| Environment props | 1024-2048 | BC7 |
| UI icons | 512 | RGBA32 |
| Terrain splats | 2048 | BC5 (normal), BC7 (albedo) |
| Character | 2048-4096 | BC7 |
| Skybox/HDRI | 4096 | HDR |

---

## 3. Assets/ Folder Structure (Hybrid: feature modules + shared scenes/art)

```
Assets/
│
├── _Core/                          # Project foundation
│   ├── Scripts/
│   │   ├── Networking/             # Server SDK wrapper
│   │   ├── Services/               # Zenject installers
│   │   ├── Events/                 # Signal declarations
│   │   ├── StateMachine/           # Base FSM implementation
│   │   ├── Utils/                  # Extensions, helpers
│   │   └── Data/                   # Shared DTO, enums, constants
│   ├── Plugins/                    # Server SDK, third-party DLLs
│   └── Settings/                   # ScriptableObject configs
│
├── Fishing/                        # Fishing mechanics
│   ├── Scripts/
│   │   ├── Casting/                # Casting
│   │   ├── Reeling/                # Reeling
│   │   ├── Tackle/                 # Rods, reels, tackle
│   │   └── FishPresentation/       # Fish visualization (logic on server)
│   └── Prefabs/
│
├── Environment/                    # World
│   ├── Scripts/
│   │   ├── Water/                  # Water system
│   │   ├── Weather/                # Weather (Enviro 3 integration)
│   │   ├── TimeOfDay/              # Day/night cycle
│   │   └── Terrain/                # Terrain, vegetation
│   └── Prefabs/
│
├── Character/                      # Player
│   ├── Scripts/
│   │   ├── Controller/             # Movement, camera
│   │   ├── Animation/              # Animation system
│   │   └── Customization/          # Appearance customization
│   └── Prefabs/
│
├── Economy/                        # Economy & progression
│   ├── Scripts/
│   │   ├── Inventory/              # Inventory
│   │   ├── Shop/                   # Shop
│   │   ├── Progression/            # XP, levels
│   │   └── Tournaments/            # Tournaments
│   └── Prefabs/
│
├── UI/                             # Interface
│   ├── Scripts/
│   │   ├── HUD/                    # In-game HUD
│   │   ├── Menus/                  # Main menu, settings
│   │   └── Widgets/                # Reusable elements
│   ├── Prefabs/
│   └── Resources/                  # UI atlases, fonts
│
├── Audio/                          # Sound system
│   ├── Scripts/
│   │   ├── Ambient/                # Ambient
│   │   ├── SFX/                    # Sound effects
│   │   └── Music/                  # Music
│   └── Mixers/                     # AudioMixer assets
│
├── Scenes/                         # All scenes (shared)
│   ├── Boot/                       # _Boot.unity — always Scene 0
│   ├── Menu/                       # MainMenu, LocationSelect, Shop, Inventory
│   ├── Locations/                  # Game locations (lakes, rivers)
│   ├── Additive/                   # HUD.unity, Weather.unity, Audio.unity
│   └── Test/                       # Dev test scenes (excluded from build)
│
├── Art/                            # Imported art from Tech Artist
│   ├── Characters/
│   ├── Environment/
│   ├── Fish/
│   ├── Props/
│   ├── UI/
│   └── Animations/
│
└── ThirdParty/                     # Third-party assets (Asset Store)
    ├── MicroSplat/
    ├── MicroVerse/
    ├── Enviro3/
    └── ...
```

---

## 4. Assembly Definitions & Namespaces

### Assembly Map
| Assembly | Path |
|---|---|
| FP2.Core | _Core/Scripts/ |
| FP2.Core.Editor | _Core/Scripts/Editor/ |
| FP2.Fishing | Fishing/Scripts/ |
| FP2.Fishing.Editor | Fishing/Scripts/Editor/ |
| FP2.Environment | Environment/Scripts/ |
| FP2.Environment.Editor | Environment/Scripts/Editor/ |
| FP2.Character | Character/Scripts/ |
| FP2.Character.Editor | Character/Scripts/Editor/ |
| FP2.Economy | Economy/Scripts/ |
| FP2.Economy.Editor | Economy/Scripts/Editor/ |
| FP2.UI | UI/Scripts/ |
| FP2.UI.Editor | UI/Scripts/Editor/ |
| FP2.Audio | Audio/Scripts/ |
| FP2.Audio.Editor | Audio/Scripts/Editor/ |

### Dependency Graph
```
        ┌──────────┐
        │ FP2.Core │  ← All depend on Core
        └────┬─────┘
             │
    ┌────────┼────────┬──────────┐
    ▼        ▼        ▼          ▼
Fishing  Environment Character  Economy
    │        │        │          │
    └────────┴────┬───┴──────────┘
                  │
               ┌──▼──┐
               │FP2.UI│  ← UI depends on modules (readonly)
               └──┬──┘
              ┌───▼────┐
              │FP2.Audio│ ← Audio reacts to events from any module
              └────────┘
```

### Rules
- `FP2.Core` — zero dependencies on other modules
- Modules (Fishing, Environment, Character, Economy) — depend **only on Core**
- Modules do **NOT** depend on each other — communicate via `SignalBus`
- `FP2.UI` — may depend on modules (readonly data access)
- `.Editor` — depends on its Runtime + `FP2.Core.Editor`

### Namespace Convention
```csharp
namespace FP2.Core.Networking { }
namespace FP2.Fishing.Casting { }
namespace FP2.Environment.Weather { }
namespace FP2.UI.HUD { }
```

---

## 5. Architecture: Zenject + Hierarchical State Machines

### Zenject Contexts
```
ProjectContext (always alive)
├── Core services, SignalBus, GameFSM
│
├── SceneContext: Menu
│   └── UI bindings
│
├── SceneContext: Location (gameplay)
│   ├── FishingInstaller
│   ├── EnvironmentInstaller
│   ├── CharacterInstaller
│   └── UIInstaller (HUD)
│
└── SceneContext: Shop
    ├── EconomyInstaller
    └── UIInstaller (Shop UI)
```

### Zenject Installers
```
_Core/Scripts/Installers/
├── ProjectInstaller.cs        # ProjectContext — always alive
│   ├── NetworkService
│   ├── SignalBus
│   └── GameStateMachine
│
Fishing/Scripts/Installers/
├── FishingInstaller.cs        # SceneContext — fishing session
│   ├── CastingService
│   ├── ReelingService
│   └── TackleManager
│
Environment/Scripts/Installers/
├── EnvironmentInstaller.cs
│   ├── WeatherService
│   ├── WaterSystem
│   └── TimeOfDayService
│
Character/Scripts/Installers/
├── CharacterInstaller.cs
│   ├── PlayerController
│   └── AnimationService
│
Economy/Scripts/Installers/
├── EconomyInstaller.cs
│   ├── InventoryService
│   ├── ShopService
│   └── ProgressionService
│
UI/Scripts/Installers/
├── UIInstaller.cs
│   ├── HUDController
│   └── MenuController
```

### Communication via Zenject Signals
```csharp
// Signal declaration
public struct FishCaughtSignal { public int FishId; public float Weight; }

// In installer
Container.DeclareSignal<FishCaughtSignal>();

// Publish
_signalBus.Fire(new FishCaughtSignal { FishId = 42, Weight = 3.5f });

// Subscribe (automatic unsubscribe via Zenject lifecycle)
_signalBus.Subscribe<FishCaughtSignal>(OnFishCaught);
```

### Hierarchical State Machines
```
Game FSM (ProjectContext — always alive)
│
├── BootState
├── AuthState
├── MainMenuState
├── LocationSelectState
├── LoadingState
├── GameplayState ─────────────────────────────┐
│   │                                          │
│   ├── Character FSM                          │
│   │   ├── IdleState                          │
│   │   ├── WalkingState                       │
│   │   ├── FishingStanceState ────────┐       │
│   │   └── CelebrationState           │       │
│   │                                   │       │
│   ├── Fishing FSM ◄──────────────────┘       │
│   │   ├── IdleState (ready to cast)          │
│   │   ├── CastingState (swing, flight)       │
│   │   ├── WaitingState (waiting for bite)    │
│   │   ├── HookedState (hook set)             │
│   │   ├── ReelingState (reeling in)          │
│   │   └── CaughtState (result)               │
│   │                                          │
│   ├── Environment FSM                        │
│   │   ├── TimeProgressState                  │
│   │   └── WeatherTransitionState             │
│   │                                          │
│   └── UI FSM (HUD mode switching)            │
│       ├── DefaultHUDState                    │
│       ├── FishingHUDState                    │
│       └── MapOverlayState                    │
│                                              │
├── ResultsState ◄─────────────────────────────┘
├── ShopState
└── InventoryState
```

### Base FSM Implementation
```csharp
// _Core/Scripts/StateMachine/StateMachine.cs
public class StateMachine<TState> where TState : class, IState
{
    private readonly DiContainer _container;
    private TState _current;

    public TState Current => _current;

    public void Enter<T>() where T : TState
    {
        _current?.Exit();
        _current = _container.Resolve<T>();
        _current.Enter();
    }

    public void Tick() => _current?.Tick();
}

// _Core/Scripts/StateMachine/IState.cs
public interface IState
{
    void Enter();
    void Exit();
    void Tick();
}
```

### FSM Cross-Communication Example
```
Fishing FSM enters CastingState
    → Fire(FishingStartedSignal)
        → Character FSM → FishingStanceState
        → UI FSM → FishingHUDState
        → Audio: ambient quieter, casting SFX

Server sends "fish hooked"
    → Networking → Fire(FishHookedSignal)
        → Fishing FSM: WaitingState → HookedState
        → Character FSM: hook-set animation
        → UI FSM: show tension bar
        → Audio: line tension SFX
```

---

## 6. Scene Loading Strategy

### Scene Map
```
Assets/Scenes/
├── Boot/
│   └── _Boot.unity                  # Single entry point. Always Scene 0
│                                    # ProjectContext (Zenject) lives here
├── Menu/
│   ├── MainMenu.unity
│   ├── LocationSelect.unity
│   ├── Shop.unity
│   └── Inventory.unity
│
├── Locations/                       # Game locations (lakes, rivers)
│   ├── Location_Tutorial.unity
│   ├── Location_LoneStarLake.unity
│   ├── Location_MuddyRiver.unity
│   └── ...
│
├── Additive/                        # Loaded on top of location
│   ├── HUD.unity
│   ├── Weather.unity
│   └── Audio.unity
│
└── Test/                            # Not included in build
    ├── Test_Casting.unity
    └── Test_Water.unity
```

### Loading Flow
```
_Boot.unity (always loaded)
    │  GameFSM: BootState → AuthState
    ▼
MainMenu.unity (LoadSceneMode.Single)
    │  GameFSM: MainMenuState → LocationSelectState
    ▼
Location_XXX.unity (LoadSceneMode.Single)
    +  HUD.unity (LoadSceneMode.Additive)
    +  Weather.unity (LoadSceneMode.Additive)
    +  Audio.unity (LoadSceneMode.Additive)
    │  GameFSM: GameplayState (child FSMs start)
    ▼
    ... gameplay ...
    │  GameFSM: ResultsState
    ▼
MainMenu.unity (return)
```

### _Boot.unity Contains
```
├── ProjectContext (Zenject)
├── GameStateMachine
├── LoadingScreen Canvas (DontDestroyOnLoad)
└── NetworkManager
```

---

## 7. Naming Conventions

| Category | Pattern | Examples |
|---|---|---|
| Scenes | `Location_{Name}.unity` | `Location_LoneStarLake.unity` |
| Prefabs | `{Name}.prefab` | `Fish_Bass.prefab` |
| Meshes/FBX | `{Name}_LOD{N}.fbx` | `Rod_Spinning_LOD0.fbx` |
| Textures | `{Name}_{Type}.png` | `Fish_Bass_Albedo.png`, `Fish_Bass_Normal.png` |
| Materials | `{Name}_Mat.mat` | `Fish_Bass_Mat.mat` |
| Animations | `{Name}_{Action}.anim` | `Player_Cast_Forward.anim` |
| Audio | `{Category}_{Name}.wav` | `SFX_Reel_Loop.wav`, `AMB_Lake_Morning.wav` |
| ScriptableObjects | `{Type}_{Name}.asset` | `FishData_Bass.asset` |
| Shaders | `FP2/{Category}/{Name}` | `FP2/Water/LakeWater` |
| Assembly Defs | `FP2.{Module}[.Editor]` | `FP2.Fishing.Editor` |

---

## 8. Git & Version Control

### Branching Model (GitLab Flow)
```
main                    ← stable build, protected branch
  │
  ├── develop           ← daily integration, auto builds
  │     ├── feature/fishing-casting
  │     ├── feature/weather-system
  │     ├── level/lone-star-lake
  │     ├── art/fish-bass-integration
  │     └── fix/reel-tension-bug
  │
  └── release/0.1.0     ← stabilization before release
```

### Branch Naming
`{type}/{short-description}` — feature/, fix/, level/, art/

### Git LFS (.gitattributes)
```
# 3D
*.fbx filter=lfs diff=lfs merge=lfs -text
*.obj filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text

# Textures
*.png filter=lfs diff=lfs merge=lfs -text
*.tga filter=lfs diff=lfs merge=lfs -text
*.psd filter=lfs diff=lfs merge=lfs -text
*.hdr filter=lfs diff=lfs merge=lfs -text
*.exr filter=lfs diff=lfs merge=lfs -text

# Audio
*.wav filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text

# Unity
*.unity filter=lfs diff=lfs merge=lfs -text
*.prefab filter=lfs diff=lfs merge=lfs -text
*.asset filter=lfs diff=lfs merge=lfs -text
*.controller filter=lfs diff=lfs merge=lfs -text

# ML models
*.onnx filter=lfs diff=lfs merge=lfs -text

# Plugins
*.dll filter=lfs diff=lfs merge=lfs -text
```

### Scene Merge — UnityYAMLMerge
```
# .gitconfig
[merge "unityyamlmerge"]
    driver = "<unity-path>/Data/Tools/UnityYAMLMerge" merge -p %O %A %B %P
```

### File Locking (GitLab LFS)
```bash
# Before editing a scene:
git lfs lock "Assets/Scenes/Locations/Location_LoneStarLake.unity"

# After MR merged:
git lfs unlock "Assets/Scenes/Locations/Location_LoneStarLake.unity"
```

---

## 9. CI/CD — TeamCity

```
TeamCity Project: FP2
│
├── Build Configuration: Validate (MR checks)
│   ├── Trigger: GitLab Merge Request webhook
│   ├── Steps:
│   │   1. Git checkout + LFS pull
│   │   2. Unit Tests (Edit Mode)               ~30 sec
│   │   3. Asset Validation Tests                ~1 min
│   │   4. Report status back to GitLab MR
│   └── Failure Conditions: compilation errors, validation fails
│
├── Build Configuration: Build-Win64-Dev
│   ├── Trigger: push to develop
│   ├── Steps:
│   │   1. Git checkout + LFS pull
│   │   2. Unit Tests
│   │   3. Asset Validation
│   │   4. Integration Tests (Play Mode)         ~5 min
│   │   5. Unity build (Development, Win64)
│   │   6. Publish artifacts
│   │   7. Slack/Teams notification
│   └── Artifacts: Builds/Win64-Dev/**
│
├── Build Configuration: Build-Win64-Release
│   ├── Trigger: manual or push to release/*
│   ├── Steps:
│   │   1. Git checkout + LFS pull
│   │   2. Full test suite
│   │   3. Unity build (Release, Win64)
│   │   4. Publish artifacts
│   └── Artifacts: Builds/Win64-Release/**
│
└── Build Configuration: Nightly
    ├── Trigger: schedule (nightly from develop)
    ├── Steps:
    │   1. Full clean build
    │   2. Full test suite
    │   3. Asset validation scan
    │   4. Build size report
    └── Artifacts: Reports/** + Builds/**
```

### TeamCity Agent Requirements
- Unity 6 with HDRP installed
- Git + Git LFS
- 16GB+ RAM
- SSD for Library cache
- GPU for shader compilation

---

## 10. Testing Strategy

### Test Assembly Definitions
Each module has its own test assemblies:
```
{Module}/Scripts/Tests/
├── FP2.{Module}.Tests.asmdef           # Edit Mode tests
└── FP2.{Module}.PlayTests.asmdef       # Play Mode tests
```

### Three Levels of Testing

| Level | What | When |
|---|---|---|
| Unit Tests (Edit Mode) | Isolated logic, FSM transitions, services, data parsing, formulas | Local + every MR |
| Integration Tests (Play Mode) | Modules via Zenject, SignalBus interaction, FSM chains, scene loading | MR + develop build |
| Asset Validation (Edit Mode) | Naming conventions, textures, LODs, missing references, shader compatibility | MR + Nightly |

### Unit Test Example — Zenject Test Fixtures
```csharp
[TestFixture]
public class FishingFSMTests : ZenjectUnitTestFixture
{
    [SetUp]
    public void Setup()
    {
        Container.DeclareSignal<FishHookedSignal>();
        Container.BindSignalBus();
        Container.Bind<FishingStateMachine>().AsSingle();
        Container.Bind<IdleState>().AsTransient();
        Container.Bind<CastingState>().AsTransient();
    }

    [Test]
    public void CastingState_OnEnter_FiresFishingStartedSignal()
    {
        var fsm = Container.Resolve<FishingStateMachine>();
        var signalFired = false;
        Container.Resolve<SignalBus>()
            .Subscribe<FishingStartedSignal>(() => signalFired = true);

        fsm.Enter<CastingState>();

        Assert.IsTrue(signalFired);
    }
}
```

### Asset Validation Test Example
```csharp
[TestFixture]
public class AssetValidationTests
{
    [Test]
    public void AllTexturesInArt_FollowNamingConvention()
    {
        var textures = AssetDatabase.FindAssets("t:Texture2D",
            new[] { "Assets/Art" });
        foreach (var guid in textures)
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var name = Path.GetFileNameWithoutExtension(path);
            Assert.IsTrue(
                name.EndsWith("_Albedo") ||
                name.EndsWith("_Normal") ||
                name.EndsWith("_Mask"),
                $"Bad naming: {path}");
        }
    }

    [Test]
    public void AllPrefabsInArt_HaveLODGroup()
    {
        var prefabs = AssetDatabase.FindAssets("t:Prefab",
            new[] { "Assets/Art/Fish", "Assets/Art/Props" });
        foreach (var guid in prefabs)
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            Assert.IsNotNull(
                prefab.GetComponent<LODGroup>(),
                $"Missing LODGroup: {path}");
        }
    }

    [Test]
    public void NoMissingScriptReferences()
    {
        var prefabs = AssetDatabase.FindAssets("t:Prefab",
            new[] { "Assets" });
        foreach (var guid in prefabs)
        {
            var path = AssetDatabase.GUIDToAssetPath(guid);
            var go = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            Assert.AreEqual(0,
                GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(go),
                $"Missing scripts: {path}");
        }
    }
}
```

### Integration Play Mode Test Example
```csharp
[TestFixture]
public class SceneLoadingTests
{
    [UnityTest]
    public IEnumerator BootScene_Loads_AndInitializesProjectContext()
    {
        yield return SceneManager.LoadSceneAsync("_Boot");
        var context = GameObject.FindObjectOfType<ProjectContext>();
        Assert.IsNotNull(context);
    }

    [UnityTest]
    public IEnumerator GameplayFlow_LoadLocation_WithAdditiveScenes()
    {
        yield return SceneManager.LoadSceneAsync("_Boot");
        yield return SceneManager.LoadSceneAsync(
            "Location_Tutorial", LoadSceneMode.Single);
        yield return SceneManager.LoadSceneAsync(
            "HUD", LoadSceneMode.Additive);

        Assert.IsTrue(SceneManager.GetSceneByName("HUD").isLoaded);
    }
}
```

---

## 11. Git Workflow Pipeline

### Workflow per Role

| Role | Git Workflow | Tool | MR Review |
|---|---|---|---|
| Programmers (4-5) | Feature branches, full GitLab Flow | IDE / CLI | Code review from another programmer |
| Tech Artist (1) | Feature branches, art/* branches | Fork / CLI | Programmer or Lead review |
| GD/LD (3-4) | Simplified: long-lived personal branch level/{name} | Fork | Tech Artist or Lead review |
| Content Mgrs (1-2) | Simplified: long-lived personal branch content/{name} | Fork | GD Lead review |

### Programmers — Full Flow
```
1. git checkout develop
2. git pull
3. git checkout -b feature/fishing-casting
4. ... work, commit ...
5. git push -u origin feature/fishing-casting
6. GitLab → New Merge Request → develop
7. Code Review from another programmer
8. CI (TeamCity) green → Merge
```

### GD/LD — Simplified Flow
```
Each GD/LD has a PERSONAL long-lived branch:

  level/ivan
  level/olena
  level/dmytro

Daily cycle:
1. [Fork GUI] Pull latest from develop → merge into own branch
2. Work on scenes
3. [Fork GUI] Commit → Push
4. When feature ready → MR from level/ivan → develop
5. Tech Artist / Lead reviews → Merge
6. Repeat
```

### Content Managers — Simplest Flow
```
  content/maria
  content/alex

Work only with ScriptableObjects and data.
Conflicts are nearly impossible (different files).
Same MR process as GD/LD.
```

### Tech Artist — Bridge Between Repos
```
fp2-art repo:
1. Review art in Review/ folder
2. Validation (checklist)
3. Export .unitypackage

fp2-client repo:
1. git checkout -b art/fish-bass-batch-03
2. Import .unitypackage → Assets/Art/
3. Verify in HDRP
4. Commit → Push → MR → develop
```

### File Locking — Critical for Team

**Rule: Before editing a scene or key prefab — LOCK**

```
GD/LD workflow (in Fork GUI):
1. Right-click file → Lock
2. Edit scene
3. Commit + Push
4. Merge Request
5. After merge → Unlock
```

**What to lock:**
- `Assets/Scenes/Locations/*.unity` — ALWAYS
- `Assets/Scenes/Menu/*.unity` — ALWAYS
- `Assets/Scenes/Additive/*.unity` — ALWAYS
- Key shared prefabs — as needed

**What NOT to lock:**
- Scripts (*.cs) — merge works well
- ScriptableObjects — rarely conflict
- Assets/Art/** — Tech Artist is sole owner

**GitLab Lock settings (.gitattributes):**
```
*.unity lockable
*.prefab lockable
*.controller lockable
*.asset lockable
```

### GUI Client: Fork (Recommended)

| Client | Pros | Cons |
|---|---|---|
| **Fork** | Fast, LFS lock from GUI, merge visualization, free | Win/Mac only |
| GitKraken | Nice UI, GitLab integration | Paid for private repos |
| SourceTree | Free | Slow, often glitches with LFS |
| CLI | Full control | Not for GD/LD |

### Merge Request Rules in GitLab

```
Branch: main (protected)
├── Allowed to merge: Maintainers only
├── Allowed to push: No one
└── Require: 1 approval + CI green

Branch: develop (protected)
├── Allowed to merge: Developers+
├── Allowed to push: No one (MR only)
└── Require: 1 approval + CI green
```

**MR Review Matrix:**
```
Programmer → Programmer       (code review)
GD/LD → Tech Artist or Lead   (scene review)
Tech Artist → Lead Programmer  (art integration review)
Content Mgr → GD Lead          (data review)
```

**MR Template:**
```markdown
## What was done
- [ ] Description of changes

## Type
- [ ] Feature
- [ ] Level/Scene
- [ ] Art Integration
- [ ] Bugfix
- [ ] Data/Content

## Checklist
- [ ] Tested locally in Editor
- [ ] No missing references
- [ ] File locks released after merge
```

### Conflict Prevention Strategy

| Problem | Solution |
|---|---|
| Two GD edit same scene | File Locking — first to lock works, second waits or takes another |
| Programmer changed script, GD scene broke | Additive scenes. HUD.unity separate from Location_XXX.unity |
| Merge conflict in .unity file | UnityYAMLMerge automatic. If fails — Tech Artist resolves |
| Forgot to unlock | GitLab shows who locked. Weekly reminder: check your locks |
| Someone pushes to develop directly | Forbidden. MR only |

### Daily Team Rhythm

```
Morning:
├── Everyone: Pull latest develop into own branch
├── GD/LD: Lock scenes they'll work on
└── TeamCity: Nightly build result in Slack

During the day:
├── Commit often, push regularly
├── MR when feature ready
└── Review and merge during the day (don't accumulate)

Evening:
├── Unlock everything you locked
├── Push all changes
└── Develop must be green in TeamCity
```
