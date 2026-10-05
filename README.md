# Best Gear Finder

WoW Forever 용 장비 추천 애드온 / Gear recommendation addon for WoW Forever (Interface 16001)

---

## 한국어 매뉴얼

### 설치
1. `BestGearFinder-1.0.0.zip` 압축을 풉니다.
2. `BestGearFinder` 폴더를 `World of Warcraft\<버전 폴더>\Interface\AddOns\` 에 넣습니다. (`AddOns\BestGearFinder\BestGearFinder.toc` 가 되어야 합니다.)
3. 게임을 켜고 `/bgf` 를 입력합니다. 처음 열 때 데이터를 읽느라 몇 초 걸립니다.

### 사용법
- 창을 열면 내 직업·레벨 기준으로 슬롯별 추천 장비가 역할(딜/탱/힐)별로 가로로 나란히 나옵니다.
- **요구 레벨**: 입력칸에 범위(예: 20~35)를 쓰고 `검색`. `자동(현재-10)` 은 현재 레벨 -10 ~ 현재 레벨로 되돌립니다.
- **필터 ▼** 메뉴: 제작템, 퀘스트 보상, 월드 드랍(저확률), 업그레이드만, 몹 레벨 제한, 다른 직업 전용 숨김, 아이템 등급.
- **슬롯당 N개** 버튼: 슬롯마다 보여줄 아이템 수(1~4).
- 아이템에 마우스를 올리면 툴팁에 비교 점수와 획득처(던전·보스·드랍률 / 제작 / 퀘스트)가 나옵니다.
- **화면 아이콘**: 방패 모양 아이콘을 클릭하면 창이 열리고 닫힙니다. 드래그해서 원하는 곳으로 옮길 수 있고 위치는 저장됩니다. (`/bgf 아이콘`으로 숨기기, `/bgf 초기화`로 위치 초기화)
- **후원** 버튼: 후원 링크를 복사할 수 있습니다.

### 명령어 (`/bgf`, `/bestgear`, `/내템`)
| 명령 | 설명 |
|---|---|
| `/bgf` | 창 열기/닫기 |
| `/bgf 20-35` | 요구 레벨 범위 설정 |
| `/bgf 제작` | 제작템 포함 켜기/끄기 |
| `/bgf 퀘스트` | 퀘스트 보상 포함 켜기/끄기 |
| `/bgf 월드드랍` | 월드 드랍(저확률) 포함 켜기/끄기 |
| `/bgf 등급 녹청보` | 표시할 등급 선택 (하/일/녹/청/보/주) |
| `/bgf 확률 1` | 이 드랍률(%) 미만은 월드 드랍으로 분류 |
| `/bgf 아이콘` | 화면 아이콘 숨기기/보이기 |
| `/bgf 신규` | Forever 신규 아이템(출처 불명) 포함 켜기/끄기 |
| `/bgf 재검색` | 신규 아이템을 처음부터 다시 검색 |
| `/bgf 슬롯` | 슬롯별 후보 수·점수 진단 |
| `/bgf 진단` | 상태 진단 |
| `/bgf 초기화` | 창 위치 초기화 |
| `/bgf 후원` | 후원 링크 |

### 알아두기
- 점수는 직업·역할별 스탯 가중치로 계산한 추정치입니다. 정확한 시뮬레이션이 아닙니다.
- 보스·몬스터 이름은 DB에 한글이 없어 영어로 표시됩니다.
- 상인이 파는 장비는 출처에 포함되지 않습니다.
- 1.12 DB에 없는 Forever 신규 장비는 게임에서 직접 찾아 `[신규]`로 표시합니다. 어디서 나오는지는 알 수 없습니다. 처음 한 번 몇 초 걸리고, 게임 빌드가 바뀔 때까지 결과를 저장해 둡니다.

---

## English manual

### Install
1. Unzip `BestGearFinder-1.0.0.zip`.
2. Put the `BestGearFinder` folder in `World of Warcraft\<version folder>\Interface\AddOns\` (result: `AddOns\BestGearFinder\BestGearFinder.toc`).
3. Type `/bgf` in game. The first open takes a few seconds while the data is indexed.

### Usage
- The window shows the best gear for your class and level per slot, with DPS / Tank / Heal columns side by side.
- **Required level**: type a range (e.g. 20-35) and press `Search`. `Auto (Lv-10)` resets to your level -10 ~ your level.
- **Filters ▼** menu: crafting, quest rewards, world drops (low chance), upgrades only, mob level limit, hide other-class items, item quality.
- **Per slot: N** button: how many items to show per slot (1-4).
- Hover an item for its comparison score and sources (dungeon / boss / drop rate, crafting, quest).
- **On-screen icon**: click the shield icon to open / close the window. Drag it anywhere; its position is saved. (`/bgf icon` to hide, `/bgf reset` to reset the position)
- **Support** button: copy the donation link.

### Commands (`/bgf`, `/bestgear`, `/내템`)
| Command | Description |
|---|---|
| `/bgf` | Open / close the window |
| `/bgf 20-35` | Set the required-level range |
| `/bgf craft` | Toggle crafted items |
| `/bgf quest` | Toggle quest rewards |
| `/bgf worlddrop` | Toggle world drops (low chance) |
| `/bgf quality green blue epic` | Choose qualities (gray white green blue epic legendary) |
| `/bgf chance 1` | Drop rate (%) below which an item counts as a world drop |
| `/bgf icon` | Hide / show the on-screen icon |
| `/bgf new` | Toggle new Forever items (source unknown) |
| `/bgf rescan` | Search for new items again from scratch |
| `/bgf slot` | Per-slot candidate / score diagnostics |
| `/bgf diag` | Status diagnostics |
| `/bgf reset` | Reset window position |
| `/bgf donate` | Support link |

### Notes
- Scores are estimates from per-class/role stat weights, not a simulation.
- Boss and creature names are English (the source DB has no Korean names).
- Vendor-sold gear is not included as a source.
- Forever gear that is not in the 1.12 database is found directly in the game client and marked `[New]`; where it comes from is unknown. The search takes a few seconds once and is cached until the game build changes.

---

## Rebuild the data / 데이터 다시 만들기
    python tools/extract_cmnangos.py "ClassicDB_1_12_1_z2815.sql.gz" --output "BestGearFinder/GearDatabase.lua"
(`--min-quality 2`, `--world-rares` optional.) Source: https://github.com/cmangos/classic-db (GPL-3.0)

## Publishing (CurseForge / Wago)
1. Create the project on both sites (game flavor: Forever, category: Inventory).
2. Upload `BestGearFinder-1.0.0.zip` with CHANGELOG.md and CURSEFORGE_DESCRIPTION.md.
3. Optionally add `## X-Curse-Project-ID:` / `## X-Wago-ID:` to the .toc in later versions.

Support: https://buymeacoffee.com/qqhrqqhr2
