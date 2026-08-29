from __future__ import annotations

import unittest

from scripts.validate_catalog import load_catalog, parse_readme_tools, validate_catalog


class CatalogValidationTests(unittest.TestCase):
    def test_catalog_matches_readme(self) -> None:
        catalog = load_catalog()
        errors = validate_catalog(catalog, parse_readme_tools())
        self.assertEqual(errors, [])

    def test_improvements_have_required_priority_values(self) -> None:
        catalog = load_catalog()
        priorities = {item["priority"] for item in catalog["improvements"]}
        self.assertTrue(priorities.issubset({"high", "medium", "low"}))

    def test_blocker_is_marked_critical(self) -> None:
        catalog = load_catalog()
        self.assertTrue(catalog["critical_blockers"])
        self.assertTrue(all(item["severity"] == "critical" for item in catalog["critical_blockers"]))


if __name__ == "__main__":
    unittest.main()
