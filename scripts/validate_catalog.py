#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "data" / "toolkit_catalog.json"
README_PATH = ROOT / "README.md"

VALID_PRIORITIES = {"high", "medium", "low"}


def load_catalog(path: Path = CATALOG_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_readme_tools(path: Path = README_PATH) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    inside = False
    result: list[str] = []
    for line in lines:
      if line.strip() == "# Перечень инструментов":
          inside = True
          continue
      if inside and line.startswith("## "):
          break
      if inside and line.startswith("* "):
          name = line[2:].split(" [подробнее]", 1)[0].strip()
          result.append(name)
    return result


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def validate_catalog(catalog: dict, readme_tools: Iterable[str]) -> list[str]:
    errors: list[str] = []
    tools = catalog.get("tools", [])
    improvements = catalog.get("improvements", [])
    blockers = catalog.get("critical_blockers", [])

    require(bool(tools), "Каталог инструментов пуст.", errors)
    require(bool(blockers), "Не зафиксированы критические блокеры.", errors)

    names = [tool["name"] for tool in tools]
    slugs = [tool["slug"] for tool in tools]
    readme_tools = list(readme_tools)

    require(len(names) == len(set(names)), "Имена инструментов должны быть уникальными.", errors)
    require(len(slugs) == len(set(slugs)), "Slug инструментов должны быть уникальными.", errors)
    require(names == readme_tools, "Перечень инструментов в README должен совпадать с каталогом.", errors)

    for tool in tools:
        require(tool.get("name"), f"Инструмент без имени: {tool}", errors)
        require(tool.get("slug"), f"Инструмент без slug: {tool}", errors)
        require(tool.get("category"), f"Инструмент без category: {tool['name']}", errors)

    for improvement in improvements:
        require(
            improvement.get("priority") in VALID_PRIORITIES,
            f"Некорректный priority у улучшения {improvement.get('id')}.",
            errors,
        )
        require(improvement.get("title"), f"У улучшения {improvement.get('id')} отсутствует title.", errors)
        require(
            improvement.get("rationale"),
            f"У улучшения {improvement.get('id')} отсутствует rationale.",
            errors,
        )

    for blocker in blockers:
        require(blocker.get("severity") == "critical", "Все блокеры должны иметь severity=critical.", errors)
        require(blocker.get("title"), f"У блокера {blocker.get('id')} отсутствует title.", errors)
        require(blocker.get("rationale"), f"У блокера {blocker.get('id')} отсутствует rationale.", errors)

    return errors


def build_report(catalog: dict, readme_tools: list[str], errors: list[str]) -> str:
    improvements = catalog.get("improvements", [])
    blockers = catalog.get("critical_blockers", [])
    lines = [
        "# Validation report",
        "",
        f"- Catalog tools: {len(catalog.get('tools', []))}",
        f"- README tools: {len(readme_tools)}",
        f"- Improvements: {len(improvements)}",
        f"- Critical blockers: {len(blockers)}",
        "",
    ]
    if errors:
        lines.extend(["## Errors", ""])
        lines.extend(f"- {error}" for error in errors)
    else:
        lines.extend(["## Status", "", "- OK"])
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, help="Write markdown report to the given path.")
    args = parser.parse_args()

    catalog = load_catalog()
    readme_tools = parse_readme_tools()
    errors = validate_catalog(catalog, readme_tools)
    report = build_report(catalog, readme_tools, errors)

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report, encoding="utf-8")

    if errors:
        print(report)
        return 1

    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
