# Best Gear Finder

WoW Forever 용 장비 추천 애드온 / Gear recommendation addon for WoW Forever (Interface 16001)

---

## 한국어 매뉴얼

### 설치
1. CurseForge에서 받은 `BestGearFinder-<버전>.zip` 압축을 풉니다.
2. `BestGearFinder` 폴더를 `World of Warcraft\<버전 폴더>\Interface\AddOns\` 에 넣습니다. (`AddOns\BestGearFinder\BestGearFinder.toc` 가 되어야 합니다.)
3. 게임을 켜고 `/bgf` 를 입력합니다. 처음 열 때 데이터를 읽느라 몇 초 걸립니다.

### 사용법
- 창을 열면 내 직업·레벨 기준으로 슬롯별 추천 장비가 역할(딜/탱/힐)별로 가로로 나란히 나옵니다.
- **요구 레벨**: 입력칸에 범위(예: 20~35)를 쓰고 `검색`. `자동(현재-10)` 은 현재 레벨 -10 ~ 현재 레벨로 되돌립니다.
- **필터 ▼** 메뉴: 제작템, 퀘스트 보상, 월드 드랍(저확률), 업그레이드만, 몹 레벨 제한, 다른 직업 전용 숨김, 아이템 등급.
- **슬롯 제목 클릭**: 그 슬롯을 접거나 펼칩니다. 창 오른쪽 아래 모서리를 끌면 높이를 조절할 수 있고 저장됩니다.
- **[BiS] 표시**: 레벨 30 BiS 목록의 1순위 아이템입니다. 기본은 역할별 추정 점수순이며, 정렬 메뉴에서 **30레벨 BiS 우선**을 선택할 수 있습니다. BiS 표시만으로 업그레이드라고 판정하지 않습니다.
- **아이템 검색** 버튼(`/bgf find 이름`): 이름·보스, 요구 레벨, 등급, 획득처, 경매장 식 분류(무기/방어구/방패/성물/등/목걸이/반지/장신구)로 전체 아이템을 검색합니다. 창 열기·조건 변경 시 자동 검색하고, 기존 데이터의 결과부터 보여줍니다. 중지·닫기는 예약된 검색을 취소합니다. 최대 150개 결과를 표시합니다.
- **내 캐릭터 ▼** 드롭다운: 다른 직업의 추천 장비를 봅니다(보기 전용). 창 오른쪽 위 **투명도** 슬라이더로 배경 투명도를 조절합니다.
- **아이템 클릭**: Shift+클릭은 채팅창에 아이템 링크 넣기, Ctrl+클릭은 착용 미리보기입니다.
- **하단 상태줄**: 확인된 아이템 수를 보여줍니다. 게임에 없는 아이템은 "제외"로 표시되며, 마우스를 올리면 자세한 설명이 나옵니다.
- 필터의 **출처가 확인된 것만**: 출처 불명(신규) 아이템과 저확률 월드 드랍을 숨깁니다. 신규 아이템은 항상 출처가 확인된 아이템 아래에 나옵니다.
- **슬롯당 N개 ▼** 드롭다운: 슬롯마다 보여줄 아이템 수(2~10).
- **언어 ▼** 드롭다운: 자동 / 한국어 / English. 고르면 창이 바로 새로 열립니다. (`/bgf lang ko|en|auto`)
- 아이템에 마우스를 올리면 툴팁에 비교 점수와 획득처(던전·보스·드랍률 / 제작 / 퀘스트)가 나옵니다.
- **화면 아이콘**: 방패 모양 아이콘을 클릭하면 창이 열리고 닫힙니다. 드래그해서 원하는 곳으로 옮길 수 있고 위치는 저장됩니다. (`/bgf 아이콘`으로 숨기기, `/bgf 초기화`로 위치 초기화)
- **후원** 버튼(창 오른쪽 위): 후원 링크를 복사할 수 있습니다.

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
| `/bgf 언어 ko` / `en` / `auto` | 표시 언어 바꾸기 (`/bgf lang ...` 도 가능) |

### 알아두기
- 점수는 직업·역할별 스탯 가중치로 계산한 추정치입니다. 정확한 시뮬레이션이 아닙니다.
- 보스·몬스터 이름은 한국어 선택 시 내장 한글 사전을 사용하며, 번역이 없는 이름은 영어로 표시됩니다.
- 1.12 데이터에서는 상인이 파는 장비가 출처에 포함되지 않습니다. 일부 Forever 전용 아이템은 상인·퀘스트·드랍 출처가 함께 들어 있습니다.
- 1.12 DB에 없는 Forever 신규 장비는 게임에서 직접 찾아 `[신규]`로 표시합니다. 최초 전체 탐색은 오래 걸릴 수 있으며 게임 빌드가 바뀔 때까지 결과를 저장합니다. 획득처가 확인되지 않은 아이템도 있습니다.

---

## English manual

### Install
1. Unzip the `BestGearFinder-<version>.zip` you downloaded from CurseForge.
2. Put the `BestGearFinder` folder in `World of Warcraft\<version folder>\Interface\AddOns\` (result: `AddOns\BestGearFinder\BestGearFinder.toc`).
3. Type `/bgf` in game. The first open takes a few seconds while the data is indexed.

### Usage
- The window shows the best gear for your class and level per slot, with DPS / Tank / Heal columns side by side.
- **Required level**: type a range (e.g. 20-35) and press `Search`. `Auto (Lv-10)` resets to your level -10 ~ your level.
- **Filters ▼** menu: crafting, quest rewards, world drops (low chance), upgrades only, mob level limit, hide other-class items, item quality.
- **Click a slot title** to collapse / expand it. Drag the bottom-right corner to resize the height (saved).
- **[BiS] marker**: the top pick on the level 30 BiS list (PvE). Recommendations default to role score order; select **Level 30 BiS first** to prioritize the list. A BiS marker alone does not mean an item is an upgrade.
- **Click an item**: Shift+click inserts its link into chat, Ctrl+click opens the dressing-room preview.
- **Status line** (bottom): shows how many items were found. Items that do not exist in this game version are reported as skipped; hover for details.
- Filter option **Known sources only** hides unknown-source [New] items and low-chance world drops. [New] items are always listed below items with known sources.
- **Per slot: N ▼** dropdown: how many items to show per slot (2-10).
- **Language ▼** dropdown: Auto / 한국어 / English. The window reopens in the chosen language right away. (`/bgf lang ko|en|auto`)
- Hover an item for its comparison score and sources (dungeon / boss / drop rate, crafting, quest).
- **On-screen icon**: click the shield icon to open / close the window. Drag it anywhere; its position is saved. (`/bgf icon` to hide, `/bgf reset` to reset the position)
- **Support** button (top right of the window): copy the donation link.

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
| `/bgf lang ko` / `en` / `auto` | Change the display language |

### Notes
- Scores are estimates from per-class/role stat weights, not a simulation.
- Boss and creature names use the bundled Korean dictionary when Korean is selected; names without a translation remain in English.
- In the 1.12 data, vendor-sold gear is not included as a source. Some Forever-only items have vendor / quest / drop sources in the bundled Forever data.
- Forever gear that is not in the 1.12 database is found directly in the game client and marked `[New]`; its source may be unknown. First-time discovery can take time and is cached until the game build changes.

---

## Rebuild the data / 데이터 다시 만들기
    python tools/extract_cmnangos.py "ClassicDB_1_12_1_z2815.sql.gz" --output "BestGearFinder/GearDatabase.lua"
(`--min-quality 2`, `--world-rares` optional.) Source: https://github.com/cmangos/classic-db (GPL-3.0)

Forever data (not in 1.12):
- `tools/extract_dungeon_data.py` → `DungeonData.lua` (dungeon boss drops and dungeon quest rewards)
- `tools/extract_world_data.py` → `WorldData.lua` (rare mob drops, zone vendors, zone quest rewards)
- `tools/extract_craft_data.py <recipe Data.lua>` → `CraftData.lua` (crafted items, skill to learn, recipe needed)
- `tools/extract_item_sources.py` → `ItemSources.lua` (gear sources noted on guide pages: quest rewards with faction, dungeon drops, vendors, rares, PvP sets)
- `tools/extract_names.py --pages <dungeon pages> --drg <Dungeon Route Guide Data.lua>` → `NamesKO.lua` (Korean boss / zone names)

## Releasing (GitHub / CurseForge)
Releases are automated by `.github/workflows/release.yml` using the BigWigs packager.

1. Test the changes in game. Keep `## Version: @project-version@` in `BestGearFinder.toc`.
2. Add a section such as `## 1.0.10` at the top of `CHANGELOG.md`, using the existing short bullet-point style. Commit the changelog and addon changes together.
3. Merging or pushing that commit to `main` starts the workflow. It reads the first version heading, creates `v1.0.10`, and dispatches the workflow for that tag.
4. The tag run builds the installable `BestGearFinder` ZIP and publishes to GitHub and CurseForge (project `1728236`). `.pkgmeta` uses `CHANGELOG.md` for both release notes.
5. Verify both the branch and tag workflow runs, the GitHub ZIP, and the CurseForge file status.

For a beta, run the workflow manually on a reviewed branch with the `beta` input checked. This creates a tag such as `v1.0.10-beta`. Adding a beta suffix to the changelog heading alone does **not** select beta: the version parser reads only the numeric version. Avoid merging a new changelog version to `main` until ready for a normal release.

Secrets: `CF_API_KEY` for CurseForge; the workflow uses `GITHUB_TOKEN` for GitHub. An existing release for the selected tag is skipped. If a tag exists without a release, the current workflow replaces that tag before retrying.

### 한국어 배포 안내
- `CHANGELOG.md` 맨 위에 `## 1.0.10`처럼 버전 제목과 짧은 변경 항목을 추가합니다. 수정 코드와 변경 내역을 같은 커밋에 포함합니다.
- `main`에 반영하면 워크플로가 버전 태그를 만들고 GitHub·CurseForge에 자동 배포합니다. `.toc`의 `@project-version@`은 패키저가 실제 버전으로 치환합니다.
- 베타는 검토한 브랜치에서 워크플로를 수동 실행하며 `beta`를 선택합니다. 변경 내역 제목에만 `-beta`를 붙이면 정식 배포가 될 수 있습니다.
- 배포 전 게임 내 동작을 확인하고, 배포 후 태그 워크플로 성공·GitHub ZIP·CurseForge 파일 상태를 확인합니다.

Support: https://buymeacoffee.com/qqhrqqhr2

## Credits / Licenses
- Item and loot data: CMaNGOS classic-db (GPL-3.0).
- Level 30 BiS lists (PvE): bundled as item IDs for the BiS marker.
