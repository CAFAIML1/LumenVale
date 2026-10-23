<div align="center">

# LumenVale

### Кольорове світло. Жива вода. Атмосферні світи.

[![Перевірки](https://github.com/CAFAIML1/LumenVale/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/CAFAIML1/LumenVale/actions/workflows/validate.yml)
[![Версія 2.5.0 experimental](https://img.shields.io/badge/version-2.5.0%20experimental-3b887a)](https://github.com/CAFAIML1/LumenVale/releases/tag/v2.5.0)
[![Ліцензія MIT](https://img.shields.io/badge/license-MIT-74889a)](LICENSE.txt)

**Minecraft Java 1.20.1 · Iris 1.6.x / 1.7.x · OpenGL 4.3**

**[Завантажити 2.5.0](https://github.com/CAFAIML1/LumenVale/releases/tag/v2.5.0)** · **[Встановлення](#встановлення)** · **[Сумісність](docs/COMPATIBILITY.md)** · **[Зміни](CHANGELOG.md)** · **[Повідомити про помилку](https://github.com/CAFAIML1/LumenVale/issues/new/choose)**

</div>

LumenVale поєднує виразне освітлення з чотирма профілями якості. Почни з **Balanced**, а для кольорового воксельного освітлення, об’ємного туману та відбиттів на блоках увімкни **Ultra**.

**Нове у 2.5.0:** швидша вибірка воксельного світла, автоматичний спрощений режим для старіших Iris і матриця перевірок дев’яти випусків. [Режими та версії →](docs/COMPATIBILITY.md)

## Можливості

- **Кольорове світло з обох рук.** Звичайний факел теплий, факел душ блакитний, редстоун-факел червоний, плакучий обсидіан фіолетовий. Обидві руки додають свої внески незалежно.
- **Воксельне освітлення в Ultra.** Локальні джерела забарвлюють оточення; поверхні змінюють відтінок одного наближеного дифузного відбиття.
- **Світло крізь скло.** 16 кольорів скла та інші прозорі фільтри змінюють спектр світла. В Ultra переносне світло також враховує перешкоди.
- **Форма неповних блоків.** 278 форм для 236 ванільних типів блоків і 7 196 станів: плити, сходи, килими, люки, двері, паркани, стіни тощо.
- **Вода з глибиною.** Хвилі, заломлення, поглинання світла, відбиття видимого оточення, дощові кола, піна та світлові візерунки на дні залежно від профілю.
- **Атмосфера й камера.** М’які тіні, процедурне небо, об’ємне світло, світіння яскравих ділянок, плівковий колір і необов’язкова глибина різкості.
- **Українські й англійські налаштування.** Освітлення працює також у Незері та Енді.

**Навігація:** [Профілі](#профілі) · [Результати перевірок](docs/VALIDATION.md) · [Повна інструкція](README_UA.md) · [Розробка](#розробка)

## Встановлення

1. Підготуй **Minecraft Java 1.20.1** з **Iris 1.7.6** або іншою комбінацією з [матриці сумісності](docs/COMPATIBILITY.md), Fabric Loader та відповідним Sodium. Потрібна відеокарта з OpenGL 4.3.
2. **[Завантаж LumenVale-2.5.0-MC1.20.1.zip](downloads/LumenVale-2.5.0-MC1.20.1.zip?raw=1)**.
3. У меню Iris відкрий папку шейдерпаків і скопіюй туди ZIP **без розпакування**.
4. Вибери LumenVale, натисни **«Застосувати»** й відкрий налаштування шейдера.
5. Вибери профіль. Для повного кольорового освітлення — **Ultra**. Для чіткішого зображення під час гри можна вимкнути «Глибина різкості».

Використовуй готовий ZIP за посиланням вище. Архів **Code → Download ZIP** містить репозиторій розробки й не призначений для прямого встановлення в Iris.

## Профілі

| Профіль | Тіні | Вода | Додаткові ефекти |
|---|---|---|---|
| **Performance** | Без динамічних тіней | Плоска, без заломлення й пошуку відбиттів | Мінімальне навантаження |
| **Balanced** · початковий | 2048, 4 вибірки | 2 шари хвиль, відбиття неба | Для початку налаштування |
| **High** | 3072, 8 вибірок | 4 шари хвиль, 16 кроків відбиття | Дощові кола та каустика |
| **Ultra** | 4096, 16 вибірок | 6 шарів хвиль, 40 кроків відбиття | Вокселі, кольорове відбите світло, туман і ефекти камери |

На Iris 1.6.x воксельні ефекти автоматично вимикаються. Кольорове світло з рук доступне в усіх профілях. Його перевірка стін і скла потребує воксельного освітлення Ultra. Орієнтир під час розробки — RTX 4060 з 8 ГБ пам’яті.

## Стан і межі

Версія **2.5.0** є експериментальною. Пройдено перевірки компіляції та синтетичні тести на NVIDIA RTX 4060 Laptop GPU; вони не замінюють повний ігровий тест і не є бенчмарком Minecraft. [Що саме перевірено →](docs/VALIDATION.md)

- Локальна воксельна сітка охоплює приблизно ±32 блоки від камери. Це наближене освітлення, без апаратного RTX та повного трасування шляхів.
- Поширення кольорового поля має комірку в один блок і оцінку отворів на гранях 4×4; світло з рук перевіряє об’єми підтримуваних форм точніше.
- Опис неповних форм відповідає ванільним моделям 1.20.1. Модовані блоки й ресурс-паки, які змінюють геометрію, потребують окремої підтримки.
- Екранні відбиття бачать лише вже намальовану непрозору сцену. Об’єкти поза кадром у них не відображаються.
- PBR-карти ресурс-паків і Distant Horizons не інтегровані. Основна ціль — Minecraft 1.20.1. Iris 1.6.x має спрощений режим; для 1.7.x доступний повний Ultra. Перевірки парсерів 1.8.x не замінюють завершений перенос на Minecraft 1.21.x.

## Розробка

Вихідний код — у [shaders/lib/](shaders/lib/), профілі й меню — у [shaders/shaders.properties](shaders/shaders.properties). Для локальної роботи копію репозиторію можна розмістити в папці shaderpacks.

Зібрати ZIP із поточного коду можна за допомогою Python 3.10+:

```sh
python scripts/build.py
python scripts/check_repository.py
```

Готовий пакет з’явиться в dist/. GitHub Actions додатково компілює профілі та виміри, запускає оригінальні парсери дев’яти Iris і перевіряє ZIP та контрольні суми. Ігрові тести виконуються окремо. [Команди перевірки та правила внеску →](CONTRIBUTING.md)

## English

LumenVale is an experimental shader pack targeting **Minecraft Java 1.20.1 with full Ultra on supported Iris 1.7.x and a capability fallback for older Iris 1.6.x**, with four quality profiles. Ultra adds local colored voxel lighting, one approximate diffuse bounce, stained-glass transmission, volumetric light and screen-space surface reflections. Both hands support independent source colors. Shape metadata covers vanilla slabs, stairs, carpets and other partial blocks. Version 2.5.0 adds faster light sampling and checks the original parsers from nine Iris releases, including 1.8.14 beta.1; a complete Minecraft 1.21.x port is still pending.

Download the **[ready-to-install shader ZIP](downloads/LumenVale-2.5.0-MC1.20.1.zip?raw=1)** and put it in shaderpacks without extracting it. Start with Balanced or choose Ultra for voxel lighting. OpenGL 4.3 is required. Synthetic GPU tests pass; full in-game validation and game FPS are not claimed. Hardware path tracing, arbitrary modded geometry, PBR and Distant Horizons are not implemented.

## Ліцензія

[MIT](LICENSE.txt). LumenVale не є офіційним продуктом Minecraft, Mojang або Microsoft. Текстури Minecraft до репозиторію не входять; таблиця форм містить лише числовий опис геометрії ванільних моделей.
