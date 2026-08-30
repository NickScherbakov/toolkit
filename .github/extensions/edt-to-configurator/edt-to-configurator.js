/**
 * GitHub Copilot CLI Extension / Agent Skill: EDT to Configurator Converter
 * 
 * This extension provides a unified tool to convert 1C:Enterprise extensions 
 * from EDT (Enterprise Development Tools) project format to classical Configurator 
 * formats (.cfe binary or Configurator XML files).
 * 
 * Format: Copilot CLI Extension / Agent Skill
 * Language: JavaScript (Node.js)
 * Dependencies: Built-in Node.js modules only (zero-dependency)
 * 
 * Standard: Agent Skills Specification (agentskills.io) & GitHub Copilot CLI Extension
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const os = require('os');

// =============================================================================
// Extension Metadata & Copilot CLI Skill Definition
// =============================================================================
const metadata = {
  name: "edt-to-configurator",
  version: "1.0.0",
  description: "Конвертирует расширение 1С из формата EDT в формат классического Конфигуратора (.cfe или XML)",
  commands: [
    {
      name: "convert",
      description: "Выполняет полную конвертацию проекта EDT в бинарный файл .cfe или XML-файлы Конфигуратора",
      arguments: [
        {
          name: "projectDir",
          type: "string",
          description: "Путь к каталогу проекта EDT (содержащему .project и папку src)",
          required: true
        },
        {
          name: "output",
          type: "string",
          description: "Путь для сохранения результата (файл .cfe или каталог для XML-выгрузки)",
          required: true
        },
        {
          name: "edtVersion",
          type: "string",
          description: "Версия EDT в формате ring (например, 'edt@2025.2.0'). По умолчанию автоопределяется.",
          required: false
        },
        {
          name: "platformPath",
          type: "string",
          description: "Путь к исполняемому файлу 1С (1cv8). По умолчанию ищется в стандартных путях.",
          required: false
        },
        {
          name: "extensionName",
          type: "string",
          description: "Имя расширения в 1С. По умолчанию совпадает с именем проекта EDT.",
          required: false
        },
        {
          name: "xmlOnly",
          type: "boolean",
          description: "Выгрузить только в формате XML-исходников Конфигуратора (без компиляции в .cfe)",
          required: false
        }
      ]
    }
  ]
};

// =============================================================================
// Helper Functions
// =============================================================================

function log(msg) {
  console.log(`[*] ${msg}`);
}

function logError(msg) {
  console.error(`[-] Ошибка: ${msg}`);
}

function find1CPlatform() {
  const isWindows = os.platform() === 'win32';
  if (isWindows) {
    const programFiles = process.env['ProgramFiles'] || 'C:\\Program Files';
    const programFilesX86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
    const searchPaths = [
      path.join(programFiles, '1cv8'),
      path.join(programFilesX86, '1cv8')
    ];
    for (const searchPath of searchPaths) {
      if (fs.existsSync(searchPath)) {
        const versions = fs.readdirSync(searchPath)
          .filter(f => /^\d+\.\d+\.\d+\.\d+$/.test(f))
          .sort((a, b) => b.localeCompare(a, undefined, { numeric: true })); // Сортировка по убыванию версий
        for (const version of versions) {
          const exePath = path.join(searchPath, version, 'bin', '1cv8.exe');
          if (fs.existsSync(exePath)) return exePath;
        }
      }
    }
  } else {
    // Linux
    const standardPath = '/opt/1cv8/x86_64/current/1cv8';
    if (fs.existsSync(standardPath)) return standardPath;
    const baseDir = '/opt/1cv8/x86_64';
    if (fs.existsSync(baseDir)) {
      const versions = fs.readdirSync(baseDir)
        .filter(f => /^\d+\.\d+\.\d+\.\d+$/.test(f))
        .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
      for (const version of versions) {
        const binPath = path.join(baseDir, version, '1cv8');
        if (fs.existsSync(binPath)) return binPath;
      }
    }
  }
  return null;
}

function detectEdtVersion() {
  try {
    const output = execSync('ring list', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
    const match = output.match(/edt@\d+\.\d+\.\d+\+\d+|edt@\d+\.\d+\.\d+/g);
    if (match && match.length > 0) {
      // Возвращаем самую свежую версию
      return match.sort().pop();
    }
  } catch (e) {
    // ring не установлен или недоступен
  }
  return null;
}

function extractProjectName(projectDir) {
  const projectFile = path.join(projectDir, '.project');
  if (fs.existsSync(projectFile)) {
    const content = fs.readFileSync(projectFile, 'utf8');
    const match = content.match(/<name>(.*?)<\/name>/);
    if (match) return match[1].trim();
  }
  return path.basename(path.resolve(projectDir));
}

// =============================================================================
// Core Conversion Logic
// =============================================================================

async function runConversion(args) {
  const projectDir = path.resolve(args.projectDir);
  const outputPath = path.resolve(args.output);
  const isXmlOnly = !!args.xmlOnly;

  if (!fs.existsSync(projectDir)) {
    throw new Error(`Каталог проекта EDT не найден: ${projectDir}`);
  }

  // 1. Извлечение имени проекта и расширения
  const projectName = extractProjectName(projectDir);
  const extName = args.extensionName || projectName.replace(/[^a-zA-Z0-9_]/g, '_');
  log(`Имя проекта EDT: ${projectName}`);
  log(`Целевое имя расширения 1С: ${extName}`);

  // 2. Поиск утилиты ring и версии EDT
  let edtVer = args.edtVersion;
  if (!edtVer) {
    edtVer = detectEdtVersion();
    if (!edtVer) {
      throw new Error("Не удалось автоматически определить версию EDT. Установите 1C:EDT или укажите версию через параметр --edtVersion.");
    }
    log(`Автоопределена версия EDT: ${edtVer}`);
  } else {
    log(`Используется указанная версия EDT: ${edtVer}`);
  }

  // 3. Поиск платформы 1С
  let p1c = args.platformPath;
  if (!p1c && !isXmlOnly) {
    p1c = find1CPlatform();
    if (!p1c) {
      throw new Error("Исполняемый файл платформы 1С (1cv8) не найден. Укажите путь вручную через параметр --platformPath.");
    }
    log(`Путь к платформе 1С: ${p1c}`);
  }

  // Создание временной директории для сборки
  const tempBaseDir = path.join(os.tmpdir(), `1c_edt_conv_${Date.now()}`);
  fs.mkdirSync(tempBaseDir, { recursive: true });
  log(`Создана временная папка сборки: ${tempBaseDir}`);

  const tempWorkspace = path.join(tempBaseDir, 'workspace');
  const tempXmlExport = path.join(tempBaseDir, 'xml_export');
  fs.mkdirSync(tempWorkspace, { recursive: true });
  fs.mkdirSync(tempXmlExport, { recursive: true });

  try {
    // 4. Экспорт проекта EDT в XML-формат классического Конфигуратора через EDT CLI (ring)
    log("Шаг 1/3: Экспорт проекта EDT в XML классического Конфигуратора...");
    // Для работы ring workspace export проект должен быть импортирован в воркспейс или находиться там.
    // Самый надежный способ - скопировать проект во временный воркспейс и запустить экспорт.
    const tempProjectDest = path.join(tempWorkspace, projectName);
    fs.mkdirSync(tempProjectDest, { recursive: true });
    
    // Копирование файлов проекта (исключая .git и .settings)
    const copyRecursive = (src, dest) => {
      const exists = fs.existsSync(src);
      const stats = exists && fs.statSync(src);
      const isDirectory = exists && stats.isDirectory();
      if (isDirectory) {
        if (path.basename(src) === '.git' || path.basename(src) === '.settings' || path.basename(src) === 'target') return;
        fs.mkdirSync(dest, { recursive: true });
        fs.readdirSync(src).forEach((child) => {
          copyRecursive(path.join(src, child), path.join(dest, child));
        });
      } else {
        fs.copyFileSync(src, dest);
      }
    };
    log("Подготовка временного воркспейса...");
    copyRecursive(projectDir, tempProjectDest);

    // Команда экспорта EDT CLI
    const ringCmd = `ring ${edtVer} workspace export --workspace "${tempWorkspace}" --project "${projectName}" --configuration "${tempXmlExport}"`;
    log(`Выполнение: ${ringCmd}`);
    execSync(ringCmd, { stdio: 'inherit' });

    if (isXmlOnly) {
      log("Конвертация завершена! Выгрузка только XML-исходников Конфигуратора запрошена.");
      // Очищаем целевую папку и копируем результат
      if (fs.existsSync(outputPath)) {
        fs.rmSync(outputPath, { recursive: true, force: true });
      }
      fs.mkdirSync(outputPath, { recursive: true });
      copyRecursive(tempXmlExport, outputPath);
      log(`XML сохранен в: ${outputPath}`);
      return outputPath;
    }

    // 5. Компиляция в бинарный файл .cfe с использованием платформы 1С
    log("Шаг 2/3: Инициализация временной информационной базы для компиляции...");
    const tempDbDir = path.join(tempBaseDir, 'temp_db');
    fs.mkdirSync(tempDbDir, { recursive: true });

    // Создание пустой файловой базы
    const createBaseCmd = `"${p1c}" CREATEINFOBASE File="${tempDbDir}" /Out "${path.join(tempBaseDir, 'create_db.log')}"`;
    log(`Выполнение: ${createBaseCmd}`);
    execSync(createBaseCmd, { stdio: 'inherit' });

    // Загрузка XML-файлов расширения в базу
    log("Шаг 3/3: Загрузка XML-исходников в базу 1С и сохранение в .cfe...");
    const loadXmlCmd = `"${p1c}" DESIGNER /F "${tempDbDir}" /LoadConfigFromFiles "${tempXmlExport}" -Extension "${extName}" /UpdateDBCfg /Out "${path.join(tempBaseDir, 'load_xml.log')}"`;
    log(`Выполнение: ${loadXmlCmd}`);
    execSync(loadXmlCmd, { stdio: 'inherit' });

    // Выгрузка расширения в .cfe
    const dumpCfgCmd = `"${p1c}" DESIGNER /F "${tempDbDir}" /DumpCfg "${outputPath}" -Extension "${extName}" /Out "${path.join(tempBaseDir, 'dump_cfe.log')}"`;
    log(`Выполнение: ${dumpCfgCmd}`);
    execSync(dumpCfgCmd, { stdio: 'inherit' });

    if (!fs.existsSync(outputPath)) {
      throw new Error("Финальный файл .cfe не был создан. Проверьте логи во временном каталоге.");
    }

    log(`Конвертация успешно завершена! Файл сохранен в: ${outputPath}`);
    return outputPath;

  } finally {
    // Очистка временных файлов
    log("Очистка временных файлов...");
    try {
      fs.rmSync(tempBaseDir, { recursive: true, force: true });
    } catch (e) {
      logError(`Не удалось полностью удалить временные файлы: ${e.message}`);
    }
  }
}

// =============================================================================
// CLI Entry Point (when run directly)
// =============================================================================
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h') || args.length === 0) {
    console.log(`
Утилита конвертации 1С:EDT проекта расширения в формат Конфигуратора (.cfe / XML)

Использование:
  node edt-to-configurator.js --projectDir <путь> --output <путь> [опции]

Обязательные параметры:
  --projectDir, -p   Путь к каталогу проекта EDT (содержащему .project)
  --output, -o       Путь для сохранения результата (выходной .cfe файл или папка XML)

Опциональные параметры:
  --edtVersion, -v   Конкретная версия EDT в формате ring (например, 'edt@2025.2.0')
  --platformPath, -b Путь к исполняемому файлу платформы 1С (1cv8 / 1cv8.exe)
  --extensionName, -e Имя расширения в 1С (по умолчанию имя проекта EDT)
  --xmlOnly          Только экспорт в XML-исходники классического формата (без .cfe)
  --help, -h         Показать эту справку
    `);
    process.exit(0);
  }

  // Простой парсинг аргументов командной строки
  const parsedArgs = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--projectDir' || args[i] === '-p') {
      parsedArgs.projectDir = args[++i];
    } else if (args[i] === '--output' || args[i] === '-o') {
      parsedArgs.output = args[++i];
    } else if (args[i] === '--edtVersion' || args[i] === '-v') {
      parsedArgs.edtVersion = args[++i];
    } else if (args[i] === '--platformPath' || args[i] === '-b') {
      parsedArgs.platformPath = args[++i];
    } else if (args[i] === '--extensionName' || args[i] === '-e') {
      parsedArgs.extensionName = args[++i];
    } else if (args[i] === '--xmlOnly') {
      parsedArgs.xmlOnly = true;
    }
  }

  if (!parsedArgs.projectDir || !parsedArgs.output) {
    logError("Пропущены обязательные параметры --projectDir или --output.");
    process.exit(1);
  }

  runConversion(parsedArgs)
    .then(() => {
      log("Выполнено успешно!");
      process.exit(0);
    })
    .catch((err) => {
      logError(err.message);
      process.exit(1);
    });
}

// Экспорт для Copilot Extension API / Agent Skills
module.exports = {
  metadata,
  run: runConversion
};
