# repo-profile — единый профиль вашего репо/стека (заполнить ОДИН раз)

> **Это единственная точка, где вы вписываете повторяющиеся значения своего проекта.** Файлы механики
> плагина ссылаются на ключи отсюда как `⟦KEY⟧` и при адаптации **не редактируются** — поэтому обновления
> апстрима (`git merge`/`git pull` из шаблона) ложатся в форк чисто, без конфликтов на каждой правке.
> Потребитель — Claude: он читает этот файл в контекст (шаг `delivery_setup`) и подставляет значения
> вместо `⟦KEY⟧` при выводе/запуске команд. Движок шаблонов (Jinja/copier) не нужен — разыменовывает модель.

## Как это работает

- **`⟦KEY⟧`** в любом файле плагина = «подставь значение ключа `KEY` из таблиц ниже».
- Заполни колонку **Значение** (замени `⟪ADAPT: …⟫` на своё). Повторяющиеся значения правятся **только здесь**,
  не в файлах механики.
- Часть ключей flow кладёт в `.env` (помечены **env**) — в bash-командах они доступны как `$KEY`.
- Проверка «профиль заполнен»: `grep -n 'ADAPT:' context/repo-profile.md` → пусто.
- **Уникальные one-off значения** (встречаются в одном месте) НЕ здесь — они остались инлайн как `⟪ADAPT⟫`
  в самих файлах (их меньшинство, повторного редактирования не требуют). Полный список того, что ещё вписать:
  `grep -rn 'ADAPT:' .` (в конце — пусто, кроме `ADAPT.md`).

## Слой 1 — инфраструктура команды

| Ключ | Что это | Значение | Где используется |
|---|---|---|---|
| `⟦GIT_HOST⟧` | git-хост команды (push + API + авто-деплой стейджа) | ⟪ADAPT: напр. gitlab.example.com⟫ | delivery_setup, access-gates, repo-conventions, qa_* |
| `⟦CHAT_CHANNEL⟧` | чат-канал для запросов доступа | ⟪ADAPT: напр. #team-access⟫ | delivery_setup, access-gates |
| `⟦VPN_CLIENT⟧` | дев-VPN-клиент (если стейдж/git за VPN; иначе — «нет») | ⟪ADAPT: напр. Cloudflare WARP⟫ | delivery_setup, access-gates |
| `⟦TOKEN_SCOPE⟧` | роль/scope PAT (достаточный на push + API) | ⟪ADAPT: напр. api + write_repository⟫ | delivery_setup, access-gates |

## Слой 2 — стек фронт-репо

| Ключ | Что это | Значение | Где используется |
|---|---|---|---|
| `⟦FRONTEND_REPO⟧` **env** | локальный путь к клону фронт-репо | ⟪ADAPT: напр. ~/work/frontend⟫ | delivery_setup, tracks, qa_* |
| `⟦REPO_GROUP⟧` | группа/путь репо на git-хосте | ⟪ADAPT: напр. group/frontend⟫ | delivery_setup, repo-conventions, MR |
| `⟦APP_PATH⟧` | путь к приложению в монорепо | ⟪ADAPT: напр. apps/web-client⟫ | delivery_setup, autotest, repo-conventions |
| `⟦NODE_MAJOR⟧` | мажор Node | ⟪ADAPT: напр. 24⟫ | delivery_setup, repo-conventions, tracks |
| `⟦BOOTSTRAP_CERTS⟧` | команда bootstrap-сертификатов dev-сервера | ⟪ADAPT: напр. bootstrap:certs⟫ | delivery_setup |
| `⟦DEV_HOST⟧` | локальный dev-хост | ⟪ADAPT: напр. local.example.dev⟫ | delivery_setup, repo-conventions |
| `⟦DEV_PORT⟧` | порт dev-сервера | ⟪ADAPT: напр. 8443⟫ | delivery_setup, repo-conventions |
| `⟦STAGE_API_HOST⟧` | API/gateway-хост стейджа | ⟪ADAPT: напр. gw-stage.example.dev⟫ | delivery_setup, qa_*, auth-scenario |
| `⟦E2E_PATH⟧` | путь к e2e-сьюте от корня фронт-репо | ⟪ADAPT: напр. e2e/web⟫ | autotest*, selectors_sync |
| `⟦DATA_TEST_HELPER⟧` | как проставить `data-test` в компоненте | ⟪ADAPT: напр. хелпер useTestId⟫ | autotest, selectors_sync, qa_mr |

## Слой 2 — i18n (опционально; нет мультиязычности — удалите эти строки и i18n-шаги)

| Ключ | Что это | Значение | Где используется |
|---|---|---|---|
| `⟦I18N_TOKEN_ENV⟧` | env-переменная токена вашей i18n-платформы/TMS | ⟪ADAPT: напр. I18N_TOKEN⟫ | delivery_setup, access-gates, repo-conventions |
| `⟦I18N_CMD⟧` | CLI-команда вашей i18n-платформы | ⟪ADAPT: напр. spectra⟫ | repo-conventions, track-c |

> **Композиции.** Где нужен под-путь — комбинируй ключи прямо в тексте: dev-URL = `https://⟦DEV_HOST⟧:⟦DEV_PORT⟧`;
> исходники приложения = `⟦APP_PATH⟧/src`; e2e-конфиг = `⟦FRONTEND_REPO⟧/⟦E2E_PATH⟧`.
