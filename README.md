# ZCode по-русски для Linux

Неофициальный установщик русского интерфейса [ZCode Desktop](https://zcode.z.ai) на Linux.

Официальное приложение поставляется как AppImage и знает только английский и китайский. Архив внутри AppImage нельзя изменить, пока программа из него запущена. Этот установщик распаковывает AppImage и подменяет английский каталог русским текстом.

Проверено на ZCode **3.16.3** (Linux x64) и Ubuntu 26.04. Скрипт ищет строки по структуре каталога, поэтому часто подходит и к соседней версии. Если сборка изменилась, он останавливается и не записывает повреждённый архив.

## Установка

Нужен Node.js 18 или новее (`node -v`). На Ubuntu для распаковки AppImage нужен пакет `libfuse2t64`.

```bash
git clone https://github.com/plesnev-hash/zcode-ru-linux.git
cd zcode-ru-linux
chmod +x install.sh
./install.sh
```

Свой файл или уже распакованный каталог:

```bash
./install.sh ~/Загрузки/ZCode-3.16.3-linux-x64.AppImage
./install.sh ~/.local/share/ZCode/squashfs-root
```

Установщик:

- находит AppImage или каталог `squashfs-root`;
- один раз сохраняет исходный `resources/app.asar` как `app.asar.ru-orig`;
- записывает русский текст в английский каталог: интерфейс, меню, диалоги и шаблоны автоматизаций;
- в настройках ZCode ставит язык `en-US` — в этом каталоге теперь русский текст;
- создаёт команду `~/.local/bin/zcode` и пункт меню.

После обновления ZCode запустите `./install.sh` ещё раз.

## Откат

```bash
./install.sh --uninstall
```

Команда возвращает сохранённый `app.asar`. Сам ZCode, AppImage и настройки аккаунта не удаляются.

## Что переведено

Словарь интерфейса основан на [xISPx/ZCode_Russifier](https://github.com/xISPx/ZCode_Russifier) (MIT). Для 3.16.3 добавлены 15 строк, которых в том словаре не было: вход по ссылке, MID устройства и новые сообщения удалённого подключения.

Подсказка в трее остаётся `ZCode`: это название программы. Служебные промпты, которые уходят модели, не переводятся. Карточки «Предложенные задачи» приходят с сервера на английском; установщик переводит известные заголовки и текст, который они вставляют в поле ввода.

В настройках выбран английский каталог. Пункт китайского языка по-прежнему показывает китайский интерфейс.

## Песочница

На Ubuntu пользовательские песочницы часто закрыты. Если `chrome-sandbox` внутри распакованной копии не принадлежит root с режимом `4755`, ярлык добавляет `--no-sandbox`. Чтобы запускать без этого флага:

```bash
sudo chown root:root ~/.local/share/ZCode/squashfs-root/chrome-sandbox
sudo chmod 4755 ~/.local/share/ZCode/squashfs-root/chrome-sandbox
```

## English

Unofficial Russian UI installer for the ZCode Desktop AppImage on Linux. It unpacks the AppImage, replaces the English string catalog with Russian, and can restore the saved `app.asar`. The dictionary comes from [xISPx/ZCode_Russifier](https://github.com/xISPx/ZCode_Russifier) (MIT) plus the 3.16.3 strings added in this repository. The tray tooltip stays `ZCode`.

```bash
git clone https://github.com/plesnev-hash/zcode-ru-linux.git
cd zcode-ru-linux
./install.sh ~/Downloads/ZCode-*-linux-x64.AppImage
./install.sh --uninstall
```
