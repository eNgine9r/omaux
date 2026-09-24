#!/usr/bin/env python3
from pathlib import Path
import json, re

SOURCE = Path('/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc')
DEST = Path.home() / '.config/omarchy/extensions/omarchy-menu.jsonc'

T = {
 'Apps':'Програми','Learn':'Довідка','Trigger':'Дії','Style':'Вигляд','Setup':'Налаштування',
 'Install':'Встановити','Remove':'Видалити','Update':'Оновлення','About':'Про Omarchy','System':'Система',
 'Screensaver':'Заставка','Lock':'Заблокувати','Suspend':'Сон','Hibernate':'Гібернація','Logout':'Вийти',
 'Reboot':'Перезавантажити','Shutdown':'Вимкнути','Keybindings':'Гарячі клавіші','Community':'Спільнота',
 'Reminder':'Нагадування','Capture':'Захоплення','Screenshot':'Знімок екрана','Stop Screenrecording':'Зупинити запис екрана',
 'Screenrecord':'Запис екрана','Text':'Текст','QR Code':'QR-код','Color':'Колір','With no audio':'Без звуку',
 'With desktop audio':'Зі звуком системи','With desktop + microphone audio':'Зі звуком системи + мікрофон',
 'With desktop + microphone audio + webcam':'Зі звуком системи + мікрофон + вебкамера','Transcode':'Конвертувати',
 'Share':'Поділитися','Toggle':'Перемикачі','Hardware':'Обладнання','Speed Test':'Тест швидкості',
 'Laptop Display':'Екран ноутбука','Mirror Display':'Дзеркалити екран','Hybrid GPU':'Гібридна відеокарта',
 'Touchpad':'Тачпад','Touchpad Haptics':'Відгук тачпада','low':'низький','mid':'середній','high':'високий',
 'Touchscreen':'Сенсорний екран','Set one':'Створити','Show all':'Показати всі','Clear all':'Очистити всі',
 'Clipboard':'Буфер обміну','File':'Файл','Folder':'Папка','Receive':'Отримати','Stay Awake':'Не засинати',
 'Notifications':'Сповіщення','Crash Capture':'Збір даних про збої','Nightlight':'Нічне світло','Menu Bar':'Панель меню',
 'Battery Percentage':'Відсоток заряду','Workspace Layout':'Макет робочого простору','Window Gaps':'Відступи між вікнами',
 '1-Window Ratio':'Пропорції одного вікна','Network Speed Test':'Тест швидкості мережі','Disk Speed Test':'Тест швидкості диска',
 'Theme':'Тема','Background':'Фон','Unlock':'Екран розблокування','Font':'Шрифт','Position':'Позиція',
 'Transparency':'Прозорість','Top':'Зверху','Bottom':'Знизу','Left':'Ліворуч','Right':'Праворуч',
 'Edit Text':'Редагувати текст','Set From Image':'Встановити із зображення','Restore Default':'Відновити типове',
 'Monitors':'Монітори','Input':'Введення','Network':'Мережа','Custom':'Власний','Defaults':'За замовчуванням',
 'Agent':'Агент','Browser':'Браузер','Terminal':'Термінал','Editor':'Редактор','Plugins':'Плагіни',
 'Enable Plugin':'Увімкнути плагін','Disable Plugin':'Вимкнути плагін','Add Plugin':'Додати плагін',
 'Clone Plugin':'Клонувати плагін','Remove Plugin':'Видалити плагін','Security':'Безпека','Config':'Конфігурація',
 'Fingerprint':'Відбиток пальця','Passwordless Sudo':'Sudo без пароля','Sudoless Docker':'Docker без sudo',
 'Direct Boot':'Пряме завантаження','Reset Computer':'Скинути комп’ютер','Package':'Пакет','Web App':'Вебзастосунок',
 'Service':'Сервіс','Development':'Розробка','AI':'ШІ','Gaming':'Ігри','Preinstalls':'Попередньо встановлене',
 'Chromium Account':'Обліковий запис Chromium','ChatGPT Desktop':'ChatGPT для ПК','Dictation':'Диктування',
 'Xbox Controllers':'Контролери Xbox','Xbox Controllers (󰂯)':'Контролери Xbox (󰂯)','RetroArch Game Launcher':'Запуск ігор RetroArch',
 'Docker DB':'Бази даних Docker','Services':'Сервіси','Channel':'Канал оновлень','Extra Themes':'Додаткові теми',
 'Process':'Процеси','Firmware':'Прошивка','Password':'Пароль','Timezone':'Часовий пояс','Time':'Час',
 'Stable':'Стабільний','Dev':'Розробка','Shell':'Оболонка','Audio':'Аудіо','Trackpad':'Тачпад',
 'Drive Encryption':'Шифрування диска','User':'Користувач','Default Agent':'Агент за замовчуванням',
 'Default Browser':'Браузер за замовчуванням','Default Terminal':'Термінал за замовчуванням',
 'Default Editor':'Редактор за замовчуванням','Reset to default':'Скинути до типових','Restart':'Перезапустити',
}

def parse_jsonc(path: Path):
    raw = path.read_text(encoding='utf-8')
    raw = re.sub(r'^\s*//[^\n]*(?:\n|$)', '', raw, flags=re.MULTILINE)
    raw = re.sub(r',(\s*[}\]])', r'\1', raw)
    return json.loads(raw)

source = parse_jsonc(SOURCE)
overrides = {}
for item_id, original in source.items():
    if not isinstance(original, dict):
        continue
    out = dict(original)
    translated = False
    for field in ('label', 'title'):
        value = original.get(field)
        if value in T:
            out[field] = T[value]
            translated = True
    if translated:
        overrides[item_id] = out

DEST.parent.mkdir(parents=True, exist_ok=True)
header = '// Omarchy Ukrainian UI overlay — generated from current upstream menu.\n'
DEST.write_text(header + json.dumps(overrides, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'generated {DEST}: {len(overrides)} translated menu entries')
