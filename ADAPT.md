# ADAPT — как форкнуть этот плагин под свой проект

> 👋 **Получил архив? Начни отсюда — это твоя точка входа.**
>
> Внутри — плагин для **Claude Code**, который ведёт человека по доставке фичи или бага до готового
> MR (дизайн → код → локальная проверка → QA-смоук → draft-MR). Он снят с рабочего плагина исходного
> проекта и **обезличен**: вся механика на месте, а то, что было завязано на конкретный проект, заменено
> пометками `⟪ADAPT: …⟫`, куда ты впишешь своё.
>
> **Работа в два захода:**
> 1. **Адаптация — один раз.** Кто-то техничный проходит по пометкам этого файла и подставляет ваш
>    репозиторий, команды сборки, дизайн-систему и продукт (~1–2 часа). **Проще всего:** распакуй архив,
>    открой папку в Claude Code (десктоп → вкладка **Code** → **Local** → выбери папку) и напиши в чат:
>    «прочитай `ADAPT.md` и помоги пройти по меткам `⟪ADAPT:⟫` под наш проект». Claude пойдёт по ним сам,
>    спрашивая недостающее.
> 2. **Использование — каждый день.** После адаптации команда ставит плагин у себя и запускает `/deliver`.
>    Как поставить и пользоваться — в **`plugins/delivery/README.md`** (там тоже есть пометки под ваш стек).
>
> **Что нужно:** Claude Code (десктоп-приложение или терминал `claude`), доступ к приватному
> GitHub-репо с плагином (`github.com/echangli/delivery-flow`) и git-доступ к репозиторию вашей команды.
> Не обязательно быть кодером — плагин рассчитан в т.ч. на продакта/QA/дизайнера. Дальше — по этому файлу.

---

Это **обобщённый скелет** delivery-плагина для Claude Code. Он снят с рабочего плагина исходного
проекта: каркас флоу сохранён 1:1, а всё, что было завязано на конкретный продукт/репозиторий
исходного проекта, вынесено в **помеченные плейсхолдеры**. Твоя задача — пройтись по меткам и подставить своё.

> Это не «продукт из коробки». Это **шаблон**: работающая механика + размеченные места под твой стек.
> После адаптации ты получишь такой же пошаговый флоу «идея/баг → дизайн → код → локальная проверка →
> QA-смоук → draft-MR», но для своего репозитория и продукта.

---

## Что даёт этот плагин (зачем форкать, а не писать с нуля)

Готовая, обкатанная на реальных задачах **механика доставки** одним человеком с помощью Claude:

- **Оркестратор** (`delivery_orchestrator`) с тремя треками: **A** — новая фича (дизайн+прототип→код→QA),
  **B** — баг/правка (лёгкий цикл без дизайна), **C** — вход в середину (готовый MR / проблема на стейдже /
  тексты-i18n).
- **QA-скиллы**: `qa_mr` (разбор чужого MR), `delivery_qa_smoke` (смоук своего MR на стейдже),
  `autotest`/`autotest_run`/`selectors_sync` (durable Playwright-автотесты).
- **Прототип** (`delivery_prototype`): один самодостаточный HTML на токенах вашей дизайн-системы с
  демо-панелью всех развилок.
- **Guardrails** (жёсткие правила): агент никогда не мержит и не деплоит сам; не делает force-push чужой
  ветки; проверяет локально до пуша; ведёт лог заметок.
- **Хуки**: языковое напоминание + опциональный гейт «dev-check перед push».

Всё это — переносимо. Не переносится только то, что физически про исходный проект: конкретный
фронт-репозиторий, команды сборки, дизайн-система, i18n-локали и доменная модель продукта. Их ты и подставляешь.

---

## С чего начать (порядок действий)

1. **Положи скелет в свой git-репозиторий.** См. раздел «Установка у себя» ниже.
2. **Найди все метки:** `grep -rn 'ADAPT:' .` — это полный список того, что нужно вписать
   (сводка — в конце файла, раздел «Реестр меток»).
3. **Пройди метки по слоям** (см. «Три слоя» ниже) — начни со **слоя 2 (стек фронт-репо)**: путь к репо,
   команды сборки, dev-сервер. Без него флоу не запустится. Слой 3 (продукт) можно наполнять постепенно.
4. **Переименуй плагин** под себя (сейчас он называется `delivery`) — если хочешь своё имя: папку
   `plugins/delivery/`, поля в манифестах (см. слой «Именование»).
5. **Проверь**, что плагин ставится и скиллы видны: `/plugin marketplace add <твой-репо>` →
   `/plugin install <твой-плагин>@<твой-marketplace>` → в новой сессии `/deliver`.

---

## Как размечены места под замену

Два маркера, оба грепаются по префиксу `ADAPT:`:

| Маркер | Где | Пример |
|---|---|---|
| `⟪ADAPT: что вписать⟫` | inline — в пути, команде, строке | `cd ⟪ADAPT: путь к фронт-репо⟫` |
| `> 🔧 **ADAPT — тема.** …` | блок — где нужен развёрнутый комментарий | целая секция «грабли ваших задач» |

Каждая метка само-объясняющая: по ней понятно, что вписать, не заглядывая в оригинал. Закрыл метку —
удали маркер `⟪ ⟫` / блок `🔧`, оставив свой текст.

Проверка «всё ли закрыто»: `grep -rn 'ADAPT:' .` должен в конце вернуть пусто (кроме этого файла).

---

## Три слоя адаптации

### Слой 1 — инфраструктура вашей команды (git-хост, VPN, каналы, токены)

Механика доступа к инфраструктуре сохранена, но host-специфичные значения вынесены в метки `⟪ADAPT: …⟫`:
git-хост команды (`⟪ADAPT: ваш git-хост⟫`), дев-VPN (`⟪ADAPT: ваш VPN-клиент⟫`), чат-каналы для запросов
доступа (`⟪ADAPT: ваш чат-канал⟫`), корп-домен почты (`⟪ADAPT: ваш корп-домен почты⟫`) и механика токена
(PAT с правом push + доступом к API, oauth2-push, osxkeychain).

> 🔧 **Доступ к плагину vs push кода — два разных git-хоста.** Сам плагин ставится из **приватного
> GitHub-репо** `github.com/echangli/delivery-flow` (приглашение + GitHub-аутентификация, VPN не нужен).
> А **push рабочей ветки** и авто-деплой стейджа идут на git-хост **вашей команды** (`⟪ADAPT: ваш git-хост⟫`) —
> это отдельный токен и отдельный доступ. Не путайте их (подробно — в `plugins/delivery/README.md §3` и §3.5).

> 🔧 **i18n-платформа — адаптируется или убирается.** Конкретная i18n-платформа/TMS под вас **не подойдёт** —
> у вашей команды её, скорее всего, нет. Все i18n-шаги вынесены в слои 2/3 как **опциональные**: если у вас
> есть своя i18n-платформа/TMS — впишите её (env-переменная токена, хост, команда сборки); **нет
> мультиязычности — просто уберите i18n-шаги**. Ищите точечно `⟪ADAPT:⟫`-метки про i18n и замените под свою
> платформу или удалите.

### Слой 2 — стек фронт-репозитория (плейсхолдеры `⟪ADAPT⟫`)

Это ядро адаптации — без него флоу не поедет. Всё помечено `⟪ADAPT: …⟫`:

| Что | Тип значения (пример) | Где искать |
|---|---|---|
| Путь/группа репо | группа/путь фронт-репо, имя монорепо, `apps/<app>` | `delivery_setup`, `repo-conventions`, `qa_mr` |
| Команды «зелёной последовательности» | типовые: type-check / eslint / stylelint / test / unused / format | `repo-conventions`, `delivery_setup` |
| Версия Node / bootstrap | напр. Node ≥ N, `bootstrap:dev`, `bootstrap:certs` | `delivery_setup`, `repo-conventions` |
| Dev-сервер | локальный хост:порт, команда `npm start` | `repo-conventions`, `delivery_setup` |
| API-хосты | stage/prod API-хосты, ws-хост | `repo-conventions`, `delivery_setup` |
| Дизайн-система | `design-system/ui-kit`, `tokens.css`, `src/tokens` | `delivery_prototype`, `track-a`, `repo-conventions` |
| e2e | путь e2e-сюиты (напр. `e2e/web`), `data-test` через хелпер | `autotest*`, `selectors_sync` |
| i18n | локали (напр. `en_US`/`ru_RU`), путь generated, команда build | `repo-conventions`, `delivery_setup`, `track-c` |
| Git-конвенция | regex веток (feature/bugfix/…), префикс тикета | `repo-conventions` |

> Общий принцип, который **оставлен как есть** (не плейсхолдер): «следуй git-конвенции своего репо
> (обычно enforced хуками+CI), и **Claude не добавляет трейлер `Co-Authored-By` / `Generated with Claude
> Code`** — иначе хук/CI отклонит пуш». Это ловушка Claude Code в любом репозитории.

### Слой 3 — доменная модель продукта (болванки-шаблоны)

Конкретика продукта исходного проекта убрана, оставлена **структура-подсказка**. Наполни своим:

| Файл | Что вписать |
|---|---|
| `context/platform.md` | обзор твоей платформы: что за продукт, ключевые поверхности |
| `context/dca.md` | центральный объект твоего домена — переименуй файл под свой домен и перепиши |
| `context/analytics.md` | как устроена твоя продуктовая аналитика (события, свойства) |
| `delivery_qa_smoke/references/platform-map.md` | карта экранов/роутов: где что смотреть на смоуке |
| `delivery_qa_smoke/references/test-data.md` | тестовые данные твоего продукта |
| `delivery_qa_smoke/references/auth-scenario.md` | как логиниться в тестовое окружение |
| «грабли ваших задач» в `repo-conventions.md` и треках | копи уроки из своих реальных задач |

### Слой «Именование»

- Плагин сейчас — `delivery`. Хочешь своё имя — переименуй папку
  `plugins/delivery/` и обнови `name` в `plugins/<имя>/.claude-plugin/plugin.json`.
- Marketplace — в `/.claude-plugin/marketplace.json` (`name` = `delivery-toolkit`, `owner`, описания).
- В командах установки внутри скиллов имя marketplace помечено `delivery-toolkit`.

---

## Установка у себя

Так как метки `⟪ADAPT:⟫` вы заполняете под свой стек, у вас будет **своя** копия marketplace — поэтому
разворачиваете её у себя (механика 1:1):

1. Создай пустой репозиторий на своём git-хосте (напр. `<твоя-группа>/ai-delivery`).
2. Положи в него содержимое папки `skeleton/` (этот `ADAPT.md`, `.claude-plugin/marketplace.json`,
   `plugins/delivery/`), закоммить, запушь в `main`.
3. Пройди адаптацию (слои 2 и 3 выше).
4. Подключи как marketplace и поставь плагин:
   ```
   /plugin marketplace add <URL твоего репо>
   /plugin install delivery@<имя-твоего-marketplace>
   ```
   Scope — **User** (флоу не привязан к одному проекту).
5. **Обязательная зависимость** — плагин `superpowers` (публичный, официальный marketplace встроен):
   ```
   /plugin install superpowers@claude-plugins-official
   ```
   Флоу опирается на его скиллы (`brainstorming`, `writing-plans`, `using-git-worktrees`,
   `systematic-debugging`, `verification-before-completion`).
6. Автообновление приватного marketplace: `/plugin` → вкладка **Marketplaces** → твой marketplace →
   **Enable auto-update**.

Подробный человеко-ориентированный онбординг (VPN, токены, доступы) — в `plugins/delivery/README.md`;
он тоже размечен метками под твой стек.

---

## Реестр меток

_(заполняется автоматически — сводка всех `ADAPT:`-мест по файлам; см. конец адаптации или
`grep -rn 'ADAPT:' .`)_

<!-- ADAPT-REGISTRY-START -->
Всего **521 место** адаптации. Проверка на «всё ли закрыто»: `grep -rn 'ADAPT:' .` → в конце пусто (кроме этого файла). Файлы по убыванию числа меток (больше меток = больше вписывать; начинай сверху):

| Файл (от корня репо) | Мест | Слой |
|---|---|---|
| `plugins/delivery/skills/delivery_setup/SKILL.md` | 74 | окружение/репо/i18n |
| `plugins/delivery/skills/delivery_orchestrator/references/repo-conventions.md` | 60 | репо/сборка/i18n |
| `plugins/delivery/skills/delivery_orchestrator/references/access-gates.md` | 47 | доступы/i18n |
| `plugins/delivery/README.md` | 41 | онбординг/установка |
| `plugins/delivery/skills/delivery_orchestrator/references/track-a.md` | 32 | флоу/репо/i18n |
| `plugins/delivery/skills/autotest/references/autotest-conventions.md` | 29 | e2e |
| `plugins/delivery/skills/delivery_orchestrator/references/second-repo-profile.md` | 26 | второй репо (опц.) |
| `plugins/delivery/skills/delivery_qa_smoke/SKILL.md` | 24 | стейдж/деплой |
| `plugins/delivery/skills/delivery_orchestrator/references/track-c.md` | 17 | флоу/i18n |
| `plugins/delivery/skills/qa_backend/references/backend-profile.md` | 16 | бэкенд-QA (профиль) |
| `plugins/delivery/context/platform.md` | 14 | продукт |
| `plugins/delivery/skills/qa_mr/SKILL.md` | 13 | QA/репо |
| `plugins/delivery/skills/delivery_orchestrator/references/track-b.md` | 13 | флоу/репо |
| `plugins/delivery/skills/autotest/SKILL.md` | 13 | e2e |
| `plugins/delivery/context/dca.md` | 13 | продукт |
| `plugins/delivery/context/analytics.md` | 10 | продукт |
| `plugins/delivery/SLACK.md` | 9 | онбординг |
| `plugins/delivery/skills/delivery_qa_smoke/references/platform-map.md` | 8 | продукт |
| `plugins/delivery/skills/delivery_orchestrator/SKILL.md` | 8 | флоу/репо |
| `plugins/delivery/skills/delivery_qa_smoke/references/test-data.md` | 7 | продукт |
| `plugins/delivery/skills/autotest_run/SKILL.md` | 7 | e2e |
| `plugins/delivery/skills/delivery_qa_smoke/references/auth-scenario.md` | 6 | продукт/авторизация |
| `plugins/delivery/skills/delivery_prototype/SKILL.md` | 6 | дизайн-система |
| `plugins/delivery/skills/selectors_sync/SKILL.md` | 4 | e2e |
| `.claude-plugin/marketplace.json` | 2 | именование |
| `plugins/delivery/skills/qa_mr/references/test-plan.md` | 1 | продукт |
| `plugins/delivery/skills/qa_mr/references/qa-mr-report.md` | 1 | дизайн-система |
| `plugins/delivery/skills/qa_backend/SKILL.md` | 1 | бэкенд-QA (фикстуры) |

(Плюс 19 меток в самом `ADAPT.md` — это примеры внутри инструкций, не «вписать».)

**Про i18n:** платформа переводов — **опциональна**. Если у вас есть i18n-платформа/TMS — впишите её в `⟪ADAPT:⟫`-местах; **нет мультиязычности — просто удалите i18n-шаги** (весь § i18n в `repo-conventions.md`, i18n-строки в `delivery_setup`/`access-gates`/`track-c`).

Файлы без меток (готовы как есть, чистая механика): `hooks/hooks.json`, `hooks/language-reminder.json`, `commands/deliver.md`, `model-policy.md`, `qa_mr/references/{bug-report,checklist}.md`, `qa_mr/references/test-design-techniques.md` (домен-агностичный арсенал техник), `qa_backend/references/hints.md` (пустой накопитель).
<!-- ADAPT-REGISTRY-END -->
