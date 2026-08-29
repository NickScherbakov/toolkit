#!/usr/bin/env python3
"""
Validate EDT extension structure.
Checks that all DataProcessors, CommonModules, and Roles
referenced in Extension.mdo actually exist on disk.
"""

import os
import sys
import re

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXTENSION_MDO = os.path.join(BASE, "src", "Extension", "Extension.mdo")
SRC_DIR = os.path.join(BASE, "src", "Extension", "src")

errors = []
warnings = []


def check_mdo():
    if not os.path.isfile(EXTENSION_MDO):
        errors.append(f"Extension.mdo not found: {EXTENSION_MDO}")
        return []

    with open(EXTENSION_MDO, encoding="utf-8") as f:
        content = f.read()

    refs = re.findall(r'<containedObjects[^>]*>([^<]+)</containedObjects>', content)
    return refs


def check_object_exists(ref):
    """Check that a referenced object exists on disk."""
    # ref is like "DataProcessors/КонсольЗапросов"
    parts = ref.strip().split("/")
    if len(parts) != 2:
        warnings.append(f"Unexpected ref format: {ref}")
        return

    collection, name = parts
    obj_dir = os.path.join(SRC_DIR, collection, name)
    mdo_file = os.path.join(obj_dir, f"{name}.mdo")

    if not os.path.isdir(obj_dir):
        errors.append(f"Object directory missing: {obj_dir}")
        return

    if not os.path.isfile(mdo_file):
        errors.append(f"MDO file missing: {mdo_file}")
        return

    # For DataProcessors — check at least one form exists
    if collection == "DataProcessors":
        forms_dir = os.path.join(obj_dir, "Forms")
        if not os.path.isdir(forms_dir):
            warnings.append(f"No Forms/ directory for DataProcessor: {name}")
        else:
            form_dirs = [d for d in os.listdir(forms_dir)
                         if os.path.isdir(os.path.join(forms_dir, d))]
            if not form_dirs:
                warnings.append(f"No form directories under Forms/ for: {name}")
            else:
                # Check module exists
                for form_name in form_dirs:
                    module = os.path.join(forms_dir, form_name, "Ext", "Form", "Module.bsl")
                    if not os.path.isfile(module):
                        warnings.append(f"Module.bsl missing for {name}/{form_name}")

    # For CommonModules — check Ext/Module.bsl
    if collection == "CommonModules":
        module = os.path.join(obj_dir, "Ext", "Module.bsl")
        if not os.path.isfile(module):
            warnings.append(f"Module.bsl missing for CommonModule: {name}")


def main():
    print(f"Validating EDT structure: {EXTENSION_MDO}")
    print()

    refs = check_mdo()
    if not refs:
        print("No containedObjects found or Extension.mdo missing.")
    else:
        print(f"Found {len(refs)} contained objects.")
        for ref in refs:
            check_object_exists(ref)

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  WARNING: {w}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"\nValidation FAILED: {len(errors)} error(s).")
        sys.exit(1)
    else:
        print(f"\nValidation PASSED. {len(warnings)} warning(s).")
        sys.exit(0)


if __name__ == "__main__":
    main()
