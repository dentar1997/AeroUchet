# Все изменения кода по порядку: П001–П171, затем v58+

Сквозная нумерация всех изменений кода АэроУчёта — с первой строки 22.09 (Денис, 04.10 10:45: «каждое изменение кода тоже обозначить… пронумеровать»).

**Три эпохи:**
1. **П001–П070** — до GitHub, код копировался из чата ChatGPT в Playgrounds (22.09 20:31 → 24.09 01:24). Источник — реконструкция `chatgpt_reconstruction/` в приватном архиве: П-номер = R-номер журнала `CHAT-01_REVISION_LEDGER.md`, подробности — `CHAT-01_R*_DETAILED.md`. Это **кандидаты**: восстановлено автоматически по ответам с кодом; часть строк — объяснение без кода (файлы «—»).
2. **П071–П171** — GitHub, но ещё без номера версии (24.09 02:01 → 26.09 19:59): 101 коммит в `main`, менявший `.swift` (прямые коммиты и слияния PR #5–#57). Служебный перенос файлов 24.09 01:33–01:41 не считается. Реакция Дениса на PR #1–57 — в [HISTORY_INDEX.md](HISTORY_INDEX.md).
3. **v58 и дальше** — номер на «Главной» (`AppVersion.swift`), один PR = одна версия. Список — [HISTORY_INDEX.md](HISTORY_INDEX.md). Версии **не перенумеровываются**: номер виден в приложении и в истории PR; П-номера — только для эпох без версии.

Итого на 04.10: 171 изменение без версии + v58…v125 (68 номеров, с особенностями v104/v120 — см. HISTORY_INDEX).

## Эпоха 1: чат ChatGPT, до GitHub (П001–П070)

Названия — из подробного разбора `CHAT-01_R*_DETAILED.md` (на английском, как в реконструкции).

| П | R | Дата | Что | Статус |
|---|---|---|---|---|
| П001 | R001 | 22.09 20:53 | onboarding and implementation sequence | USER_OK |
| П002 | R002 | 22.09 21:04 | first runnable AeroUchet shell | USER_OK |
| П003 | R003 | 22.09 21:08 | flight history, FlightLeg model and navigable detail | USER_OK |
| П004 | R004 | 22.09 21:11 | first real time arithmetic, overnight handling and whole-file replacement | USER_OK |
| П005 | R005 | 22.09 21:17 | live Add Flight UI and first continuity idea | USER_OK |
| П006 | R006 | 22.09 21:25 | local persistence and swipe deletion | USER_OK |
| П007 | R007 | 22.09 21:30 | FlightDuty grouping and duty chronology | USER_OK |
| П008 | R008 | 22.09 21:39 | first calendar-day allocation; Playgrounds performance failure | ISSUE_REPORTED |
| П009 | R009 | 22.09 22:12 | precompute daily index instead of recalculating inside month cells | USER_OK |
| П010 | R010 | 22.09 22:32 | calendar presentation redesigned toward iPad Calendar | NEEDS_VERIFICATION |
| П011 | R011 | 22.09 22:47 | Plan Work / ground events integrated with flights and calendar | USER_OK |
| П012 | R012 | 22.09 23:01 | first Accounting screen and preliminary monthly norm | ISSUE_REPORTED |
| П013 | R013 | 22.09 23:04 | exact ContentView wiring for Accounting | USER_OK |
| П014 | R014 | 22.09 23:09 | absences and adjusted monthly norm | ISSUE_REPORTED |
| П015 | R015 | 22.09 23:20 | first attempt to display absences in Calendar | REPLACED_OR_ROLLBACK |
| П016 | R016 | 22.09 23:38 | full ContentView replacement and durable whole-file workflow preference | ISSUE_REPORTED |
| П017 | R017 | 22.09 23:48 | split giant SwiftUI file after >4 minute load | USER_OK |
| П018 | R018 | 22.09 23:58 | MyApp remains the application entry point | USER_OK |
| П019 | R019 | 23.09 00:00 | first official RF production calendar and 36-hour norms | USER_OK |
| П020 | R020 | 23.09 00:13 | automatic next-year production-calendar search | REPLACED_OR_ROLLBACK |
| П021 | R021 | 23.09 00:38 | settings, first-install validation, 2027 fallback, then final manual-only lifecycle | USER_OK |
| П022 | R022 | 23.09 01:26 | year-by-year Settings status refreshes immediately | USER_OK |
| П023 | R023 | 23.09 01:26 | Accounting norm refreshes immediately after calendar mutation | USER_OK |
| П024 | R024 | 23.09 01:36 | top production/calculation-calendar status card receives refresh token | NEEDS_VERIFICATION |
| П025 | R025 | 23.09 01:42 | year formatting in production-calendar status card | USER_OK |
| П026 | R026 | 23.09 01:43 | production calendar wired into monthly calendar with live refresh | USER_OK |
| П027 | R027 | 23.09 01:53 | first compact production-day badges in month grid | ISSUE_REPORTED |
| П028 | R028 | 23.09 01:58 | vector badge quality pass and visual alternatives | REPLACED_OR_ROLLBACK |
| П029 | R029 | 23.09 02:07 | month-cell visual redesign and full CalendarView replacement | USER_OK |
| П030 | R030 | 23.09 02:28 | holiday-icon experiment chain; final SF-composed burst accepted | USER_OK |
| П031 | R031 | 23.09 03:08 | nonworking-day background fix after a crash/rollback | USER_OK |
| П032 | R032 | 23.09 03:21 | adaptive month-cell layout for iPad split-screen | USER_OK |
| П033 | R033 | 23.09 03:28 | production-day detail names, unified card icons and transferred-workday color | NEEDS_VERIFICATION |
| П034 | R034 | 23.09 03:41 | rounded month-day cells restored safely | NEEDS_VERIFICATION |
| П035 | R035 | 23.09 03:46 | cross-midnight event continuation represented as the same flight | NEEDS_VERIFICATION |
| П036 | R036 | 23.09 03:53 | unified chronological event ordering inside a day | NEEDS_VERIFICATION |
| П037 | R037 | 23.09 03:56 | shorter unified transition-arrow glyph | NEEDS_VERIFICATION |
| П038 | R038 | 23.09 04:04 | leg edit/delete with confirmation and persistent replacement | USER_OK |
| П039 | R039 | 23.09 04:21 | incoming transition arrow moved right; Playgrounds target/file-state recovery | USER_OK |
| П040 | R040 | 23.09 04:49 | edit/delete parity for work events and absences; calendar becomes direct editing hub | USER_OK |
| П041 | R041 | 23.09 05:26 | scanned PDF → structured calculation-hours import concept | NEEDS_VERIFICATION |
| П042 | R042 | 23.09 05:28 | source PDF structure analyzed | CONFIRMED_BY_SOURCE |
| П043 | R043 | 23.09 05:33 | versioned FlightNorm database and initial PDF/Vision importer | ISSUE_REPORTED |
| П044 | R044 | 23.09 05:41 | calculation-hours screen wired into the real “Ещё” hierarchy | USER_OK |
| П045 | R045 | 23.09 05:50 | first OCR parser correction: line separation + display formatting + metadata | ISSUE_REPORTED |
| П046 | R046 | 23.09 05:57 | amendment “Поправка № 6” detection fixed | USER_OK |
| П047 | R047 | 23.09 06:01 | heavy automatic validation/review system attempted | ISSUE_REPORTED |
| П048 | R048 | 23.09 06:39 | rollback plan after 3300+ line performance failure | REPLACED_OR_ROLLBACK |
| П049 | R049 | 23.09 06:42 | stable ~1300-line FlightNorms restored without Undo | NEEDS_VERIFICATION |
| П050 | R050 | 23.09 06:48 | emergency 380-line rescue version proposed but not used | REPLACED_OR_ROLLBACK |
| П051 | R051 | 23.09 06:51 | 1300-line importer becomes working baseline; 354 rows recognized | USER_OK |
| П052 | R052 | 23.09 06:54 | correct data model: Route → aircraft type → outbound/return norm | ISSUE_REPORTED |
| П053 | R053 | 23.09 23:23 | OCR speed optimization attempt | ISSUE_REPORTED |
| П054 | R054 | 23.09 23:24 | speed optimization explicitly rolled back | REPLACED_OR_ROLLBACK |
| П055 | R055 | 23.09 23:31 | inspect exact current FlightNorms file | NEEDS_VERIFICATION |
| П056 | R056 | 23.09 23:33 | full corrected file requested | NEEDS_VERIFICATION |
| П057 | R057 | 23.09 23:37 | corrected FlightNorms accepted as new working point | USER_OK |
| П058 | R058 | 23.09 23:37 | lightweight per-aircraft counters added | NEEDS_VERIFICATION |
| П059 | R059 | 23.09 23:44 | all 354 rows distributed correctly across five aircraft families | USER_OK |
| П060 | R060 | 23.09 23:46 | “Анализ маршрутов” grouping view | USER_OK |
| П061 | R061 | 23.09 23:53 | OCR/grouping accepted as working baseline; persistence check planned | USER_OK |
| П062 | R062 | 23.09 23:56 | duplicate season/year/version protection | NEEDS_VERIFICATION |
| П063 | R063 | 24.09 00:00 | saved version reorganized from 354 flat rows to Route → aircraft types | REPLACED_OR_ROLLBACK |
| П064 | R064 | 24.09 00:05 | remove extra route-detail navigation; show all norms inline | NEEDS_VERIFICATION |
| П065 | R065 | 24.09 00:12 | first compact table layout: aircraft as rows | REPLACED_OR_ROLLBACK |
| П066 | R066 | 24.09 00:14 | table transposed: aircraft types become columns | ISSUE_REPORTED |
| П067 | R067 | 24.09 00:16 | HStack-based transposed matrix fallback | ISSUE_REPORTED |
| П068 | R068 | 24.09 00:19 | full single-file route-matrix rewrite becomes too heavy | ISSUE_REPORTED |
| П069 | R069 | 24.09 00:29 | split FlightNorms core and route UI; filename ambiguity | ISSUE_REPORTED |
| П070 | R070 | 24.09 00:38 | new-file target failure; return to compact single-target FlightNorms | USER_OK |

## Эпоха 2: GitHub без версий (П071–П171)

| П | Коммит | Дата | Что |
|---|---|---|---|
| П071 | `9758d02` | 24.09 02:01 | Sync current working Playgrounds project |
| П072 | `d8fbce4` | 24.09 02:06 | Test GitHub to Playgrounds sync |
| П073 | `96bfd99` | 24.09 02:08 | Restore calculation time label |
| П074 | `8fb6d81` | 24.09 02:14 | Test Working Copy auto-sync |
| П075 | `8cab4bd` | 24.09 02:19 | Restore calculation time label after auto-sync test |
| П076 | `7c826bd` | 24.09 02:43 | GitSync pull test |
| П077 | `40ceaca` | 24.09 02:53 | Test GitSync to Playgrounds project |
| П078 | `9cbad16` | 24.09 02:55 | Restore calculation time label after GitSync test |
| П079 | `d49f193` | 24.09 02:55 | Remove GitSync test marker |
| П080 | `1e14e0d` | 24.09 03:13 | Identify GitSync app for shortcut automation |
| П081 | `e42f6c8` | 24.09 03:38 | Clean up shortcut test label |
| П082 | `0f3a624` | 24.09 05:11 | Test UIKit text field for hardware keyboard |
| П083 | `ede060b` | 24.09 05:30 | Fix hardware keyboard loss in flight norm year field |
| П084 | `524b12a` | 24.09 05:34 | Replace norm year text field with wheel picker |
| П085 | `6c1c157` | 24.09 05:40 | Add UIKit picker controls for Playgrounds input |
| П086 | `ddafa3c` | 24.09 05:40 | Open norm year wheel from row tap |
| П087 | `f28b254` | 24.09 05:40 | Use tappable UIKit wheels for flight and work times |
| П088 | `4f2a863` | 24.09 05:45 | Avoid picker controls that break hardware keyboard in Playgrounds |
| П089 | `7f131c7` | 24.09 05:49 | Avoid year popover that breaks hardware keyboard |
| П090 | `fd529ad` | 24.09 05:53 | Use inline stepper for norm year to preserve hardware keyboard |
| П091 | `76016a6` | 24.09 06:02 | Use UIKit document picker for norm PDF import |
| П092 | `f6b132e` | 24.09 06:07 | Add hardware keyboard recovery after file picker |
| П093 | `7f17a60` | 24.09 06:07 | Restore hardware keyboard when PDF picker closes |
| П094 | `ce785a5` | 24.09 06:12 | Remove failed keyboard recovery experiment |
| П095 | `2f80779` | 24.09 06:12 | Restore clean file importer and add PDF drag drop |
| П096 | `e9593f0` | 24.09 06:17 | Remove PDF drag and drop import |
| П097 | `250084a` | 24.09 06:28 | Align saved norm routes to five fixed aircraft columns |
| П098 | `8d6f845` | 24.09 06:35 | Refine norm table blanks notes and Moscow-first sorting |
| П099 | `3f75193` | 24.09 06:41 | Refine norm table route width and note alignment |
| П100 | `b9984f2` | 24.09 06:49 | Clarify route separators and fix OCR note abbreviation |
| П101 | `f5d60d1` | 24.09 06:54 | Match import review layout to saved norm tables |
| П102 | `84d82b1` | 24.09 06:58 | Widen import review table and keep columns single line |
| П103 | `525421d` | 24.09 07:11 | Auto-save validated norm imports and persist OCR confidence |
| П104 | `ed70c41` | 24.09 07:11 | Add reusable minutes wheel for norm editing |
| П105 | `c35542b` | 24.09 07:13 | Add inline norm editing warnings and version deletion |
| П106 | `0470341` | 24.09 07:13 | Simplify norm time warning styling |
| П107 | `fdfaa31` | 24.09 07:13 | Use boolean warning state for norm time wheels |
| П108 | `4c83710` | 24.09 07:25 | Add undo redo and manual norm blocks in edit mode |
| П109 | `b48f248` | 24.09 07:25 | Commit norm time wheel changes as one undoable action |
| П110 | `679d3b2` | 24.09 07:33 | Keep aircraft headers aligned with adjacent delete buttons |
| П111 | `c5e0902` | 24.09 07:34 | Enlarge aircraft labels and tighten time row spacing |
| П112 | `dd18b5c` | 24.09 17:03 | Stabilize norm row layout across edit mode |
| П113 | `2a4271f` | 24.09 17:08 | Keep aircraft labels fixed and match route title size |
| П114 | `d3bb28e` | 24.09 19:43 | Cache derived flight data and reduce repeated timeline parsing |
| П115 | `83c8faa` | 24.09 19:44 | Use cached daily totals on home screen |
| П116 | `7179c37` | 24.09 19:44 | Use cached daily totals in accounting |
| П117 | `741cc69` | 24.09 19:44 | Reuse cached calendar flight indexes |
| П118 | `9acaa3e` | 24.09 19:49 | Build derived app data in one prepared pass |
| П119 | `2d2d93e` | 24.09 19:55 | Reuse calendar and prepared work event timestamps |
| П120 | `ceb15ee` | 24.09 19:56 | Restore cached duties list on home screen |
| П121 | `9fa46b6` | 25.09 15:48 | Merge core time regression checks |
| П122 | `7302f77` | 25.09 15:56 | Merge validated stored date handling |
| П123 | `027b959` | 25.09 16:10 | Merge pull request #7 from dentar1997/ui/invalid-record-warnings |
| П124 | `6032a07` | 25.09 16:34 | Merge pull request #9 from dentar1997/feature/show-complete-night-time |
| П125 | `b2b9a68` | 25.09 16:45 | Merge pull request #10 from dentar1997/maintenance/clear-test-events-once |
| П126 | `5143b26` | 25.09 17:00 | Импорт истории рейсов из XLS портала пилотов (#11) |
| П127 | `a11ee1a` | 25.09 17:41 | Сверка времён перед импортом и семь полей расчёта лега (#12) |
| П128 | `bfa30f7` | 25.09 18:18 | Compact flight detail into adaptive time grids and remove numbered labels (#13) |
| П129 | `63d894f` | 25.09 18:25 | Arrange flight, time and calculations in three vertical columns (#14) |
| П130 | `67f9cdb` | 25.09 18:55 | Карточка задания и разделённые полётные смены (#15) |
| П131 | `bb6fcf6` | 25.09 19:19 | Lay out flight assignment legs like paper form with ordered day and night times (#16) |
| П132 | `f56013b` | 25.09 19:31 | Merge pull request #17 from dentar1997/ui/compact-duty-time-and-night |
| П133 | `40e70c3` | 25.09 20:10 | Polish flight duty card presentation |
| П134 | `7b6085b` | 25.09 20:24 | Compact flight duty card |
| П135 | `32eec2b` | 25.09 20:50 | Make flight duty a single container card |
| П136 | `c624748` | 25.09 21:08 | Restore three-level flight duty cards |
| П137 | `8d90f97` | 25.09 21:19 | Merge pull request #22 from dentar1997/ui/duty-card-summary-and-night-style |
| П138 | `6806179` | 25.09 21:29 | Merge pull request #23 from dentar1997/ui/align-duty-times-and-center-leg-info |
| П139 | `ad93e08` | 25.09 21:35 | Merge pull request #24 from dentar1997/feature/duty-edit-delete-and-rest-cards |
| П140 | `972f85a` | 25.09 21:49 | Merge pull request #25 from dentar1997/ui/inline-duty-edit-and-calculated-tile |
| П141 | `afc74e2` | 25.09 22:06 | Merge pull request #26 from dentar1997/ui/leg-info-cards-and-toolbar-actions |
| П142 | `2da9b75` | 25.09 22:19 | Merge pull request #27 from dentar1997/ui/remove-leg-info-tiles-and-wrench |
| П143 | `336671e` | 25.09 22:31 | Merge pull request #28 from dentar1997/ui/space-leg-heading-details |
| П144 | `d386bce` | 25.09 22:46 | Merge pull request #29 from dentar1997/ui/labeled-flight-identity-inline |
| П145 | `5ba700a` | 25.09 23:02 | Merge pull request #30 from dentar1997/ui/center-flight-header-fields |
| П146 | `04af4e6` | 25.09 23:15 | Merge pull request #31 from dentar1997/ui/stable-inline-edit-highlights |
| П147 | `d73ae73` | 25.09 23:29 | Merge pull request #32 from dentar1997/ui/editable-flight-field-outlines |
| П148 | `c2a9b66` | 25.09 23:31 | Merge pull request #33 from dentar1997/ui/flight-header-matches-time-columns |
| П149 | `9292eeb` | 25.09 23:42 | Present flight assignments in a sheet and highlight editable title (#34) |
| П150 | `f0671de` | 25.09 23:48 | Restore visible value cards in flight assignment sheet (#35) |
| П151 | `a1aed37` | 26.09 00:08 | Показывать задание на полёт одной широкой всплывающей карточкой (#36) |
| П152 | `662f4c4` | 26.09 00:30 | Narrow assignment overlay and scroll the entire card as a page (#37) |
| П153 | `3c10a67` | 26.09 00:56 | Компактная шапка задания, отмена правок и блокировка фоновой прокрутки |
| П154 | `4403fc3` | 26.09 01:02 | Локальная база аэропортов IATA ICAO и названий |
| П155 | `87dd394` | 26.09 01:23 | Центрировать задание, редактировать последний work end и убрать bounce |
| П156 | `7196ea4` | 26.09 01:32 | Зафиксировать окно задания и прокручивать только содержимое |
| П157 | `75fe0ff` | 26.09 01:41 | Свайп вниз для закрытия задания без движения фонового списка |
| П158 | `9b8412d` | 26.09 01:48 | Сразу показывать календарь и крутилки времени при редактировании |
| П159 | `38ce1ba` | 26.09 01:53 | Уменьшить редактор даты и времени |
| П160 | `58f3176` | 26.09 02:38 | Унифицировать окна редактирования |
| П161 | `7a7599e` | 26.09 02:48 | Довести компактные окна редактирования |
| П162 | `e1ebbf5` | 26.09 02:59 | [PR #48] Компактное окно «Задание на полёт №» |
| П163 | `2891b5d` | 26.09 03:11 | [PR #49] Компактные окна редактирования и упругий свайп задания |
| П164 | `064bd6b` | 26.09 03:24 | [PR #50] Компактные редакционные окна с левым выравниванием |
| П165 | `76613f7` | 26.09 11:29 | [PR #51] Редактируемое расчётное время и стабильные окна редактирования |
| П166 | `364c362` | 26.09 11:56 | [PR #52] Исправить галочку, форму редакторов и прокрутку задания |
| П167 | `d28fb41` | 26.09 12:18 | Merge pull request #53 from dentar1997/ui/pr53-editor-card-layout-fixes |
| П168 | `731e3c7` | 26.09 18:16 | [PR #54] Исправить взаимодействие с редакторами и слои окон |
| П169 | `fb74192` | 26.09 18:38 | [PR #55] Редактирование карточек на месте и исправление слоёв календаря |
| П170 | `fc08248` | 26.09 19:38 | [PR #56] Стабилизировать карточки редактирования и календарь |
| П171 | `e22883a` | 26.09 19:59 | [PR #57] Стабилизировать размер карточек и слой календаря |
