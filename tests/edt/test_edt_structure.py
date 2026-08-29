"""
Tests for EDT extension structure validation.
"""
import os
import sys
import unittest

# Add test root to path
sys.path.insert(0, os.path.dirname(__file__))

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXTENSION_MDO = os.path.join(BASE, "src", "Extension", "Extension.mdo")
SRC_DIR = os.path.join(BASE, "src", "Extension", "src")


class TestExtensionMDO(unittest.TestCase):

    def test_extension_mdo_exists(self):
        self.assertTrue(os.path.isfile(EXTENSION_MDO),
                        f"Extension.mdo not found: {EXTENSION_MDO}")

    def test_extension_mdo_has_content(self):
        with open(EXTENSION_MDO, encoding="utf-8") as f:
            content = f.read()
        self.assertIn("1CDeveloperToolkit", content)
        self.assertIn("containedObjects", content)

    def test_extension_version_declared(self):
        with open(EXTENSION_MDO, encoding="utf-8") as f:
            content = f.read()
        self.assertIn("<version>", content)

    def test_extension_compatibility_mode(self):
        with open(EXTENSION_MDO, encoding="utf-8") as f:
            content = f.read()
        self.assertIn("compatibilityMode", content)


class TestDataProcessors(unittest.TestCase):

    EXPECTED_PROCESSORS = [
        "КонсольЗапросов",
        "КонсольКода",
        "РедакторОбъекта",
        "Метаданные",
        "ГлобальноеМеню",
        "ВсеФункции",
        "АнализПравДоступа",
        "Пользователи",
        "РегламентныеЗадания",
        "ЖурналРегистрации",
        "ПодпискиНаСобытия",
        "ПоискЗаменаСсылок",
        "СравнениеОбъектов",
        "МониторЛицензий",
        "КонсольСКД",
        "МенеджерФормы",
        "ВыгрузкаЗагрузкаДанных",
    ]

    def _proc_dir(self, name):
        return os.path.join(SRC_DIR, "DataProcessors", name)

    def test_all_processors_have_directory(self):
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                self.assertTrue(os.path.isdir(self._proc_dir(name)),
                                f"Directory missing: {name}")

    def test_all_processors_have_mdo(self):
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                mdo = os.path.join(self._proc_dir(name), f"{name}.mdo")
                self.assertTrue(os.path.isfile(mdo),
                                f"MDO file missing: {mdo}")

    def test_all_processors_have_form(self):
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                form_dir = os.path.join(self._proc_dir(name), "Forms", "ОсновнаяФорма")
                self.assertTrue(os.path.isdir(form_dir),
                                f"Form directory missing for: {name}")

    def test_all_processors_have_module(self):
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                module = os.path.join(
                    self._proc_dir(name),
                    "Forms", "ОсновнаяФорма", "Ext", "Form", "Module.bsl"
                )
                self.assertTrue(os.path.isfile(module),
                                f"Module.bsl missing for: {name}")

    def test_mdo_has_name_and_synonym(self):
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                mdo = os.path.join(self._proc_dir(name), f"{name}.mdo")
                if os.path.isfile(mdo):
                    with open(mdo, encoding="utf-8") as f:
                        content = f.read()
                    self.assertIn(f"<name>{name}</name>", content)
                    self.assertIn("<synonym>", content)

    def test_module_has_server_procedure(self):
        """Each module must have at least one &НаСервере procedure."""
        for name in self.EXPECTED_PROCESSORS:
            with self.subTest(processor=name):
                module = os.path.join(
                    self._proc_dir(name),
                    "Forms", "ОсновнаяФорма", "Ext", "Form", "Module.bsl"
                )
                if os.path.isfile(module):
                    with open(module, encoding="utf-8") as f:
                        content = f.read()
                    self.assertIn("&НаСервере", content,
                                  f"No &НаСервере in {name}/Module.bsl")


class TestCommonModules(unittest.TestCase):

    EXPECTED_MODULES = ["ТулкитОбщий", "ТулкитОбщийКлиент"]

    def _mod_dir(self, name):
        return os.path.join(SRC_DIR, "CommonModules", name)

    def test_common_modules_exist(self):
        for name in self.EXPECTED_MODULES:
            with self.subTest(module=name):
                self.assertTrue(os.path.isdir(self._mod_dir(name)))

    def test_common_modules_have_mdo(self):
        for name in self.EXPECTED_MODULES:
            with self.subTest(module=name):
                mdo = os.path.join(self._mod_dir(name), f"{name}.mdo")
                self.assertTrue(os.path.isfile(mdo))

    def test_common_modules_have_module_bsl(self):
        for name in self.EXPECTED_MODULES:
            with self.subTest(module=name):
                module = os.path.join(self._mod_dir(name), "Ext", "Module.bsl")
                self.assertTrue(os.path.isfile(module))


class TestRoles(unittest.TestCase):

    EXPECTED_ROLES = ["ТулкитПолныйДоступ", "ТулкитБазовыйДоступ"]

    def _role_dir(self, name):
        return os.path.join(SRC_DIR, "Roles", name)

    def test_roles_exist(self):
        for name in self.EXPECTED_ROLES:
            with self.subTest(role=name):
                self.assertTrue(os.path.isdir(self._role_dir(name)))

    def test_roles_have_mdo(self):
        for name in self.EXPECTED_ROLES:
            with self.subTest(role=name):
                mdo = os.path.join(self._role_dir(name), f"{name}.mdo")
                self.assertTrue(os.path.isfile(mdo))


if __name__ == "__main__":
    unittest.main()
