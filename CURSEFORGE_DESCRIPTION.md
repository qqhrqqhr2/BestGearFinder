# Best Gear Finder

**One-line summary:** Finds the best gear you can wear right now for your class and level - and exactly where it drops, who crafts it, or which quest gives it. For WoW Forever.

## English

### What it does
Open the window and see, slot by slot, the best items you can equip at your level and where to get them. DPS, Tank and Heal recommendations are shown **side by side**, so you can compare all roles at a glance.

### Features
- Best-in-slot style recommendations for **your class and level**, from one data source
- **Dungeon & raid drops**, **crafted items** (with a "recipe required" hint) and **quest rewards** in one list
- Tooltips show the **source** (dungeon, boss, quest, profession) and the **drop chance**
- Numeric **required-level range** (e.g. 20-35) plus a Search button to refresh after you change gear
- **Upgrades only** mode compares against what you have equipped
- **[BiS] marker** for the top pick on the level 30 BiS list (PvE, per wowf.io); BiS items are listed first, and tooltips show how the item differs from what you wear
- **New Forever items** that are not in the Classic database are found in the game client and marked [New] (source unknown)
- A draggable on-screen icon opens the window with one click
- Choose how many items to show per slot (2-10) from a dropdown
- Click a slot title to collapse it; drag the bottom-right corner to resize; Shift+click an item to link it in chat
- "Known sources only" filter hides items whose source is unknown
- Filter menu: item quality, crafting, quests, world drops, mob level limit, hide other-class items
- English and Korean (follows your game language, or pick one from the Language dropdown / `/bgf lang`)

### Commands
- `/bgf` (also `/bestgear`) - open / close the window
- `/bgf 20-35` - set the required-level range
- `/bgf craft`, `/bgf quest`, `/bgf worlddrop` - toggle sources
- `/bgf quality green blue epic` - choose item qualities
- `/bgf chance 1` - drop rate (%) below which an item counts as a world drop
- `/bgf diag` - diagnostics, `/bgf donate` - support link

### Data
All item, loot, crafting, quest and vendor data is generated offline from the CMaNGOS classic-db (1.12.x) plus bundled Forever-specific sources, and shipped with the addon. No other addon is required. Boss and creature names are shown in English.

---

## 한국어

### 소개
내 직업과 레벨에서 **지금 입을 수 있는 최고의 장비**를 슬롯별로 보여주고, **어디서 나오는지**(던전·제작·퀘스트)까지 알려줍니다. 딜 / 탱 / 힐 추천을 **가로로 나란히** 보여줘서 한눈에 비교할 수 있습니다.

### 기능
- 한 곳의 데이터로 **내 직업·레벨**에 맞는 장비 추천
- **던전·레이드 드랍**, **제작템**(도안 필요 표시), **퀘스트 보상**을 한 목록에서 확인
- 툴팁에 **획득처**(던전, 보스, 퀘스트, 전문기술)와 **드랍률** 표시
- **요구 레벨 범위**를 숫자로 입력(예: 20-35), 장비를 바꾼 뒤에는 검색 버튼으로 새로고침
- **업그레이드만** 보기: 현재 착용 장비와 비교
- 레벨 30 BiS 목록(PvE, wowf.io 기준)의 1순위에 **[BiS]** 표시, BiS 아이템을 먼저 보여주고 툴팁에 현재 장비와의 차이를 표시
- 슬롯당 표시 개수(2~10)를 드롭다운으로 선택
- 슬롯 제목을 눌러 접기, 오른쪽 아래 모서리로 높이 조절, Shift+클릭으로 채팅창에 링크
- "출처가 확인된 것만" 필터로 출처 불명 아이템 숨기기
- 필터 메뉴: 아이템 등급, 제작, 퀘스트, 월드 드랍, 몹 레벨 제한, 다른 직업 전용 숨김
- 클릭 한 번으로 여는 드래그 가능한 화면 아이콘
- 한국어/영어 지원 (게임 언어를 따르며, 언어 드롭다운이나 `/bgf 언어`로 바꿀 수 있습니다)

### 명령어
- `/bgf` 또는 `/bestgear`, `/내템` - 창 열기/닫기
- `/bgf 20-35` - 요구 레벨 범위 설정
- `/bgf 제작`, `/bgf 퀘스트`, `/bgf 월드드랍` - 출처 켜기/끄기
- `/bgf 등급 녹청보` - 아이템 등급 선택
- `/bgf 확률 1` - 이 드랍률(%) 미만이면 월드 드랍으로 분류
- `/bgf 진단` - 진단, `/bgf 후원` - 후원 링크

### 데이터
아이템, 드랍, 제작, 퀘스트, 상인 데이터는 CMaNGOS classic-db(1.12.x)와 Forever 전용 출처 데이터를 미리 추출해 애드온에 포함했습니다. 다른 애드온이 필요 없습니다. 보스·몬스터 이름은 영어로 표시됩니다.

---

## Support / 후원
If this saves you time, you can buy me a coffee: https://buymeacoffee.com/qqhrqqhr2
도움이 되셨다면 커피 한 잔으로 응원해 주세요: https://buymeacoffee.com/qqhrqqhr2

Level 30 BiS lists: wowf.io. GPL-3.0. World of Warcraft is a trademark of Blizzard Entertainment; this addon is not affiliated with Blizzard or CMaNGOS.
