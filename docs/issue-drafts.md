# Issue drafts

Ниже — подготовленные черновики issues, которые следует завести вручную, потому что в рамках этой сессии нет инструмента для создания GitHub issues напрямую.

## 1. Critical blocker: product source is not available in the public repository

- **Type:** Bug / Task
- **Labels:** `needs-attention`, `priority:critical`
- **Severity:** critical
- **Summary:** Публичный репозиторий Toolkit не содержит исходников, тестов и CI продукта, поэтому задачи на реализацию улучшенной версии Toolkit не могут быть закрыты честно в этом репозитории.
- **Why it matters:** блокирует реализацию product-code changes, security fixes и regression testing.
- **Recommended action:** открыть доступ к приватному репозиторию/зеркалу исходников либо явно ограничить scope публичного репозитория документацией и feedback.

## 2. Missing PR CI for repository-owned artifacts

- **Type:** Task
- **Labels:** `needs-attention`, `priority:high`
- **Severity:** high
- **Summary:** До этого PR в репозитории отсутствовал пользовательский workflow, который проверяет консистентность README и вспомогательных документов.
- **Recommended action:** принять `Documentation CI` и сделать его обязательным для PR.

## 3. Triage templates lack priority and artifact requirements

- **Type:** Feature
- **Labels:** `needs-attention`, `priority:medium`
- **Severity:** medium
- **Summary:** Шаблоны bug/feature requests не вынуждают автора указывать приоритет, влияние и прикладывать логи/скриншоты как артефакты.
- **Recommended action:** принять обновленные шаблоны и создать недостающую label taxonomy (`needs-attention`, `priority:*`).
