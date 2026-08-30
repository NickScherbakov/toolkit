import { joinSession } from "@github/copilot-sdk/extension";
import { createRequire } from "module";
import { fileURLToPath } from "url";
import path from "path";
import { execSync, spawnSync } from "child_process";
import os from "os";
import fs from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// Загружаем скилл от ноутбука
const { run: runConversion } = require("./edt-to-configurator.js");

function findV8Bin() {
    for (const base of [
        "C:\\Program Files (x86)\\1cv8",
        "C:\\Program Files\\1cv8"
    ]) {
        if (!fs.existsSync(base)) continue;
        const vers = fs.readdirSync(base).filter(v => /^\d/.test(v)).sort().reverse();
        for (const v of vers) {
            const p = path.join(base, v, "bin", "1cv8.exe");
            if (fs.existsSync(p)) return p;
        }
    }
    return null;
}

const session = await joinSession({
    tools: [
        {
            name: "edt_to_cfe",
            description: "Конвертирует расширение 1С из формата EDT (проект в репозитории) в бинарный .cfe файл или XML Конфигуратора. Использует ring (EDT CLI) или встроенный PS-конвертер как fallback.",
            parameters: {
                type: "object",
                properties: {
                    projectDir: {
                        type: "string",
                        description: "Путь к каталогу проекта EDT (где лежит Extension.mdo)"
                    },
                    output: {
                        type: "string",
                        description: "Путь для результата: файл .cfe или каталог для XML"
                    },
                    extensionName: {
                        type: "string",
                        description: "Имя расширения в 1С. По умолчанию '1CDeveloperToolkit'."
                    },
                    xmlOnly: {
                        type: "boolean",
                        description: "Только XML-исходники (без компиляции в .cfe). По умолчанию false."
                    },
                    useFallback: {
                        type: "boolean",
                        description: "Использовать встроенный PS-конвертер вместо ring. По умолчанию: автовыбор."
                    }
                },
                required: ["projectDir", "output"]
            },
            handler: async (args) => {
                const projectDir = args.projectDir || path.join(__dirname, "../../../src/Extension");
                const output     = args.output;
                const extName    = args.extensionName || "1CDeveloperToolkit";
                const xmlOnly    = !!args.xmlOnly;

                await session.log(`EDT→Configurator: ${projectDir}`);

                // Проверяем ring
                const ringAvailable = (() => {
                    try { execSync("ring list", { stdio: "ignore" }); return true; } catch { return false; }
                })();

                if (!ringAvailable || !!args.useFallback) {
                    await session.log("ring недоступен — PS fallback", { level: "warning" });

                    const psConv   = path.join(__dirname, "../../../scripts/edt_to_1c_platform.ps1");
                    const psBuild  = path.join(__dirname, "../../../scripts/build_and_load.ps1");
                    const tmpXml   = path.join(os.tmpdir(), `edt_xml_${Date.now()}`);

                    try {
                        // Шаг 1: конвертируем EDT -> platform XML
                        const r1 = spawnSync("powershell.exe",
                            ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", psConv,
                             "-Src", projectDir, "-Dst", tmpXml],
                            { encoding: "utf8", stdio: "pipe" });

                        if (r1.status !== 0) {
                            return `Ошибка конвертации EDT:\n${r1.stdout}\n${r1.stderr}`;
                        }
                        await session.log(`XML сконвертирован в ${tmpXml}`);

                        if (xmlOnly) {
                            if (!fs.existsSync(output)) fs.mkdirSync(output, { recursive: true });
                            fs.cpSync(tmpXml, output, { recursive: true });
                            return `XML сохранён: ${output}`;
                        }

                        // Шаг 2: загружаем через build_and_load.ps1 (умеет мерджить с существующим)
                        const r2 = spawnSync("powershell.exe",
                            ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", psBuild,
                             "-InfoBasePath", "C:\\bases\\nopik",
                             "-UserName", "Администратор (ОрловАВ)",
                             "-ExtensionName", extName, "-UpdateDB"],
                            { encoding: "utf8", stdio: "pipe" });
                        await session.log(`build_and_load exit: ${r2.status}`);

                        // Шаг 3: выгружаем .cfe
                        const v8bin  = findV8Bin();
                        if (!v8bin) return "Платформа 1С не найдена";

                        const dumpLog = path.join(os.tmpdir(), "dump_cfe.log");
                        const dumpCmd = `"${v8bin}" DESIGNER /F"C:\\bases\\nopik" /N"Администратор (ОрловАВ)" /DumpCfg "${output}" -Extension "${extName}" /Out"${dumpLog}" /DisableStartupDialogs`;
                        execSync(dumpCmd, { stdio: "ignore" });

                        if (fs.existsSync(output)) {
                            const kb = (fs.statSync(output).size / 1024).toFixed(1);
                            return `Файл .cfe создан: ${output} (${kb} KB)`;
                        }
                        const dumpTxt = fs.existsSync(dumpLog) ? fs.readFileSync(dumpLog, "utf8") : "(нет лога)";
                        return `Файл .cfe не создан:\n${dumpTxt}`;

                    } finally {
                        try { if (fs.existsSync(tmpXml)) fs.rmSync(tmpXml, { recursive: true }); } catch {}
                    }
                }

                // ring доступен — используем скилл ноутбука
                try {
                    const result = await runConversion({ projectDir, output, extensionName: extName, xmlOnly });
                    return `Готово: ${result}`;
                } catch (e) {
                    return `Ошибка: ${e.message}`;
                }
            }
        },
        {
            name: "edt_build_and_deploy",
            description: "Собирает расширение Toolkit из EDT-исходников и устанавливает его в информационную базу 1С",
            parameters: {
                type: "object",
                properties: {
                    infoBasePath: {
                        type: "string",
                        description: "Путь к файловой базе 1С. По умолчанию C:\\bases\\nopik"
                    },
                    userName: {
                        type: "string",
                        description: "Пользователь базы. По умолчанию 'Администратор (ОрловАВ)'"
                    }
                },
                required: []
            },
            handler: async (args) => {
                const infoBase = args.infoBasePath || "C:\\bases\\nopik";
                const userName = args.userName     || "Администратор (ОрловАВ)";
                const script   = path.join(__dirname, "../../../scripts/build_and_load.ps1");

                await session.log(`Сборка и деплой в ${infoBase}...`);

                const result = spawnSync(
                    "powershell.exe",
                    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script,
                     "-InfoBasePath", infoBase, "-UserName", userName, "-UpdateDB"],
                    { encoding: "utf8", stdio: "pipe" }
                );

                const out = (result.stdout || "") + (result.stderr || "");
                if (result.status === 0 || result.status === 101) {
                    return `Деплой завершён успешно (код ${result.status})\n${out}`;
                }
                return `Ошибка деплоя (код ${result.status}):\n${out}`;
            }
        }
    ],
});
