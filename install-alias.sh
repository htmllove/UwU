#!/bin/bash
#=============================================================================
# Имя скрипта: install-alias.sh
# Описание: Создание/удаление коротких псевдонимов для скрипта net-tcp-tune
# Использование:
#   Установка: bash install-alias.sh [install]
#   Удаление:  bash install-alias.sh uninstall
#=============================================================================

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m' # Сброс цвета

# Определение режима работы (установка или удаление)
MODE="${1:-install}"
if [ "$MODE" != "install" ] && [ "$MODE" != "uninstall" ]; then
    echo -e "${RED}Ошибка: неизвестный параметр '$MODE'${NC}"
    echo "Использование:"
    echo "  Установка: bash install-alias.sh [install]"
    echo "  Удаление:  bash install-alias.sh uninstall"
    exit 1
fi

# Определение текущей оболочки
CURRENT_SHELL=$(basename "$SHELL")

# Определение файла конфигурации в зависимости от оболочки (проверка нескольких возможных файлов)
detect_rc_file() {
    if [ "$CURRENT_SHELL" = "zsh" ]; then
        RC_FILE="$HOME/.zshrc"
    elif [ "$CURRENT_SHELL" = "bash" ]; then
        RC_FILE="$HOME/.bashrc"
        # Если .bashrc не существует, используем .bash_profile
        if [ ! -f "$RC_FILE" ]; then
            RC_FILE="$HOME/.bash_profile"
        fi
    else
        RC_FILE="$HOME/.bashrc"
    fi
    
    # Если файл не существует, создаём его
    if [ ! -f "$RC_FILE" ]; then
        if ! touch "$RC_FILE"; then
            echo -e "${RED}Ошибка: не удалось создать файл конфигурации ${RC_FILE}${NC}"
            exit 1
        fi
    fi
}

detect_rc_file

# Проверка наличия блока псевдонимов в файле конфигурации
alias_block_exists() {
    if [ ! -r "$RC_FILE" ]; then
        echo -e "${RED}Ошибка: не удалось прочитать файл конфигурации ${RC_FILE}${NC}" >&2
        return 2
    fi

    grep -qE '(^# >>> net-tcp-tune alias >>>|net-tcp-tune 快捷别名)' "$RC_FILE" 2>/dev/null && return 0

    awk '
    function strip_unquoted_comment(line,    i, c, out, in_single, in_double, escaped) {
        out = ""
        in_single = 0
        in_double = 0
        escaped = 0
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (escaped) {
                out = out c
                escaped = 0
                continue
            }
            if (c == "\\" && in_double) {
                out = out c
                escaped = 1
                continue
            }
            if (c == "'"'"'" && !in_double) in_single = !in_single
            if (c == "\"" && !in_single) in_double = !in_double
            if (c == "#" && !in_single && !in_double) break
            out = out c
        }
        return out
    }
    function is_project_alias(line,    body) {
        body = strip_unquoted_comment(line)
        return body ~ /^[[:space:]]*alias[[:space:]]+(bbr|dog)=/ &&
               body ~ /(raw\.githubusercontent\.com|github\.com)\/Eric86777\/vps-tcp-tune\// &&
               body ~ /net-tcp-tune\.sh/
    }
    is_project_alias($0) { found = 1; exit }
    END { exit(found ? 0 : 1) }
    ' "$RC_FILE"
}

# Добавление блока псевдонимов
append_alias_block() {
    cat <<'ALIAS_EOF'
# >>> net-tcp-tune alias >>>
# ========================================
# Короткие псевдонимы для net-tcp-tune (добавлено автоматически)
# -q игнорирует локальный curlrc, параметр с меткой времени гарантирует получение актуальной версии
# ========================================
alias bbr="bash <(curl -q -fsSL \"https://raw.githubusercontent.com/htmllove/UwU/refs/heads/main/net-tcp-tune.sh?\$(date +%s)\")"
# <<< net-tcp-tune alias <<<
ALIAS_EOF
}

# Удаление блоков псевдонимов из файла
strip_alias_blocks() {
    local file="$1"

    awk '
    function flush_pending(    i) {
        for (i = 1; i <= pending_count; i++) print pending[i]
        pending_count = 0
        candidate = 0
    }
    function add_pending(line) {
        pending[++pending_count] = line
    }
    function strip_unquoted_comment(line,    i, c, out, in_single, in_double, escaped) {
        out = ""
        in_single = 0
        in_double = 0
        escaped = 0
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (escaped) {
                out = out c
                escaped = 0
                continue
            }
            if (c == "\\" && in_double) {
                out = out c
                escaped = 1
                continue
            }
            if (c == "'"'"'" && !in_double) in_single = !in_single
            if (c == "\"" && !in_single) in_double = !in_double
            if (c == "#" && !in_single && !in_double) break
            out = out c
        }
        return out
    }
    function is_project_alias(line,    body) {
        body = strip_unquoted_comment(line)
        return body ~ /^[[:space:]]*alias[[:space:]]+(bbr|dog)=/ &&
               body ~ /(raw\.githubusercontent\.com|github\.com)\/Eric86777\/vps-tcp-tune\// &&
               body ~ /net-tcp-tune\.sh/
    }
    function is_managed_comment(line) {
        return line ~ /^# >>> net-tcp-tune alias >>>/ ||
               line ~ /^# <<< net-tcp-tune alias <<</ ||
               line ~ /^# =+$/ ||
               line ~ /net-tcp-tune[[:space:]]+快捷别名/ ||
               line ~ /使用.*时间戳参数确保每次都获取最新版本/
    }
    function is_end_marker(line) {
        return line ~ /^# <<< net-tcp-tune alias <<</
    }
    BEGIN {
        pending_count = 0
        drop_next_end_marker = 0
    }
    drop_next_end_marker && is_end_marker($0) {
        drop_next_end_marker = 0
        next
    }
    is_managed_comment($0) {
        add_pending($0)
        if (pending_count >= 12) flush_pending()
        next
    }
    pending_count > 0 {
        if (is_project_alias($0)) {
            pending_count = 0
            drop_next_end_marker = 1
            next
        }
        flush_pending()
    }
    is_project_alias($0) { drop_next_end_marker = 1; next }
    {
        print
    }
    END {
        flush_pending()
    }
    ' "$file"
}

# Безопасная запись в файл конфигурации
write_rc_safely() {
    local new_content="$1"
    local backup_file="${RC_FILE}.bak.$(date +%Y%m%d_%H%M%S).$$"

    if cmp -s "$RC_FILE" "$new_content"; then
        LAST_BACKUP_FILE=""
        return 2
    fi

    if ! cp -p "$RC_FILE" "$backup_file"; then
        echo -e "${RED}Ошибка: не удалось создать резервную копию ${RC_FILE}${NC}" >&2
        return 1
    fi

    if ! cat "$new_content" > "$RC_FILE"; then
        echo -e "${RED}Ошибка: запись в ${RC_FILE} не удалась, пытаемся восстановить резервную копию${NC}" >&2
        cat "$backup_file" > "$RC_FILE" 2>/dev/null || true
        return 1
    fi

    if ! cmp -s "$new_content" "$RC_FILE"; then
        echo -e "${RED}Ошибка: проверка записи не удалась, пытаемся восстановить резервную копию${NC}" >&2
        cat "$backup_file" > "$RC_FILE" 2>/dev/null || true
        return 1
    fi

    LAST_BACKUP_FILE="$backup_file"
    return 0
}

# Функция удаления псевдонимов
uninstall_alias() {
    echo -e "${CYAN}=== Удаление коротких псевдонимов для net-tcp-tune ===${NC}"
    echo ""
    echo -e "Обнаружена оболочка: ${GREEN}${CURRENT_SHELL}${NC}"
    echo -e "Файл конфигурации: ${GREEN}${RC_FILE}${NC}"
    echo ""
    
    # Проверяем, существуют ли псевдонимы
    alias_block_exists
    local exists_rc=$?
    if [ "$exists_rc" -eq 2 ]; then
        echo -e "${RED}❌ Не удалось прочитать файл конфигурации, удаление псевдонимов не выполнено${NC}"
        echo ""
        return 1
    fi
    if [ "$exists_rc" -ne 0 ]; then
        echo -e "${YELLOW}Установленные псевдонимы не найдены, удаление не требуется${NC}"
        echo ""
        return 0
    fi

    local temp_file
    temp_file=$(mktemp "${RC_FILE}.tmp.XXXXXX") || {
        echo -e "${RED}Ошибка: не удалось создать временный файл${NC}"
        return 1
    }

    if ! strip_alias_blocks "$RC_FILE" > "$temp_file"; then
        rm -f "$temp_file"
        echo -e "${RED}Ошибка: очистка псевдонимов не удалась${NC}"
        return 1
    fi

    write_rc_safely "$temp_file"
    local write_rc=$?
    rm -f "$temp_file"

    case "$write_rc" in
        0)
        echo -e "${GREEN}✅ Псевдонимы удалены из ${RC_FILE}${NC}"
        echo ""
            [ -n "$LAST_BACKUP_FILE" ] && echo -e "${YELLOW}Подсказка: резервная копия файла конфигурации сохранена как ${LAST_BACKUP_FILE}${NC}"
        echo ""
        echo -e "${CYAN}=== Активация изменений (выполните следующую команду) ===${NC}"
        echo ""
        echo -e "${YELLOW}source ${RC_FILE}${NC}"
        echo ""
        echo "Или закройте и откройте терминал заново, чтобы изменения вступили в силу."
        echo ""
            ;;
        2)
            echo -e "${YELLOW}Не найдено содержимого для удаления${NC}"
            echo ""
            ;;
        *)
            echo -e "${RED}❌ Удаление псевдонимов не выполнено${NC}"
            echo ""
            return 1
            ;;
    esac
}

# Функция установки псевдонимов
install_alias() {
    echo -e "${CYAN}=== Установка коротких псевдонимов для net-tcp-tune ===${NC}"
    echo ""
    echo -e "Обнаружена оболочка: ${GREEN}${CURRENT_SHELL}${NC}"
    echo ""
    echo -e "Файл конфигурации: ${GREEN}${RC_FILE}${NC}"
    echo ""
    local had_alias=0
    alias_block_exists
    local exists_rc=$?
    if [ "$exists_rc" -eq 2 ]; then
        echo -e "${RED}❌ Не удалось прочитать файл конфигурации, установка псевдонимов не выполнена${NC}"
        return 1
    fi
    if [ "$exists_rc" -eq 0 ]; then
        had_alias=1
        echo -e "${YELLOW}Конфигурация уже существует, обновляем...${NC}"
    fi

    local temp_file
    temp_file=$(mktemp "${RC_FILE}.tmp.XXXXXX") || {
        echo -e "${RED}Ошибка: не удалось создать временный файл${NC}"
        return 1
    }

    if ! strip_alias_blocks "$RC_FILE" > "$temp_file"; then
        rm -f "$temp_file"
        echo -e "${RED}Ошибка: очистка старых псевдонимов не удалась${NC}"
        return 1
    fi

    if [ -s "$temp_file" ] && [ "$(tail -c 1 "$temp_file" | wc -l | tr -d ' ')" -eq 0 ]; then
        printf '\n' >> "$temp_file"
    fi
    append_alias_block >> "$temp_file"

    write_rc_safely "$temp_file"
    local write_rc=$?
    rm -f "$temp_file"

    if [ "$write_rc" -eq 1 ]; then
        echo -e "${RED}❌ Запись псевдонимов не удалась${NC}"
        return 1
    fi

    if [ "$had_alias" -eq 1 ]; then
        echo -e "${GREEN}✅ Псевдонимы обновлены в ${RC_FILE}${NC}"
        echo ""
    else
        echo -e "${GREEN}✅ Псевдонимы добавлены в ${RC_FILE}${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}=== Быстрые команды ===${NC}"
    echo ""
    echo -e "  ${GREEN}bbr${NC}   - запустить скрипт оптимизации системы"
    echo ""
    echo -e "${CYAN}=== Использование ===${NC}"
    echo ""
    echo "1. Перезагрузите конфигурацию:"
    echo -e "   ${YELLOW}source ${RC_FILE}${NC}"
    echo ""
    echo "2. Или закройте и откройте терминал заново"
    echo ""
    echo "3. Затем просто введите быструю команду:"
    echo -e "   ${GREEN}bbr${NC}  (оптимизация системы)"
    echo ""
    echo -e "${CYAN}=== Удаление ===${NC}"
    echo ""
    echo "Чтобы удалить псевдонимы, выполните:"
    echo -e "   ${YELLOW}bash install-alias.sh uninstall${NC}"
    echo ""
    echo -e "${CYAN}=== Активация изменений (выполните следующую команду) ===${NC}"
    echo ""
    echo -e "${YELLOW}source ${RC_FILE}${NC}"
    echo ""
}

# Выполнение соответствующего действия в зависимости от режима
case "$MODE" in
    install)
        install_alias
        ;;
    uninstall)
        uninstall_alias
        ;;
esac
