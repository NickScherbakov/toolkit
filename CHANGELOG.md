# Changelog

Все значимые изменения в проекте документируются в этом файле.  
Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.0.0/).  
Версионирование — [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added
- Начальная структура проекта (EDT XML): расширение конфигурации, роли, общие модули
- Консоль запросов: редактор с Monaco Editor, выполнение, вывод в ТЗ и дерево
- Консоль кода: выполнение BSL-кода клиент/сервер, история скриптов
- Редактор объекта: просмотр/редактирование реквизитов и табличных частей по ссылке
- Метаданные: дерево конфигурации, поиск, структура хранения
- Глобальное меню, Все функции, Анализ прав доступа, Пользователи
- Регламентные/фоновые задания, Журнал регистрации, Подписки на события
- Поиск и замена ссылок, Сравнение объектов, Монитор лицензий
- Редактор констант, параметров сеанса, записи регистра сведений
- Консоль СКД, Менеджер формы, Выгрузка/Загрузка данных
- Роли доступа: ТулкитПолныйДоступ, ТулкитБазовыйДоступ, отдельные роли на инструменты
- CI: проверка структуры EDT, тесты
- Документация по всем инструментам

### Old

- machine-readable catalog of publicly documented Toolkit tools and blockers in `data/toolkit_catalog.json`
- validation script and unit tests for repository-owned documentation assets
- GitHub Actions workflow running validation, tests and artifact upload with 30-day retention
- design doc, improvements register, migration plan, upgrade guide and issue drafts

### Changed

- bug report and feature request templates now collect priority, impact and artifact details

### Notes

- product source code is still unavailable in the public repository; this PR improves only the maintainability of the public documentation repository
