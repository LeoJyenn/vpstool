#!/bin/bash

# 系统信息监控脚本 (System Information Monitoring Script)
# 适用于多种 Linux 发行版 (Compatible with multiple Linux distributions)

# Check if running on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo "本脚本仅适用于Linux系统。"
    exit 1
fi

# Function to detect package manager and install packages
install_package() {
    local package=$1
    echo "尝试安装必要的依赖: $package"

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y $package
    elif command -v yum &>/dev/null; then
        sudo yum install -y $package
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y $package
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm $package
    elif command -v apk &>/dev/null; then
        sudo apk add $package
    else
        echo "无法自动安装 $package。请手动安装后再运行脚本。"
        echo "常见安装命令:"
        echo "  Debian/Ubuntu: sudo apt-get install $package"
        echo "  CentOS/RHEL:   sudo yum install $package"
        echo "  Fedora:        sudo dnf install $package"
        echo "  Arch Linux:    sudo pacman -S $package"
        echo "  Alpine Linux:  sudo apk add $package"
        return 1
    fi
    return 0
}

# Check for required commands and try to install if missing
for cmd in bc curl free df grep awk; do
    if ! command -v $cmd &>/dev/null; then
        echo "检测到缺少必要组件: $cmd"
        if [ "$cmd" = "bc" ]; then
            package="bc"
        elif [ "$cmd" = "curl" ]; then
            package="curl"
        elif [ "$cmd" = "free" ]; then
            package="procps"
        elif [ "$cmd" = "df" ]; then
            package="coreutils"
        elif [ "$cmd" = "grep" ]; then
            package="grep"
        elif [ "$cmd" = "awk" ]; then
            package="gawk"
        fi

        if install_package $package; then
            echo "$cmd 已成功安装"
        else
            exit 1
        fi
    fi
done

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIVIDER="${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

clear # Clear the screen for better visibility

# Function to get network traffic
get_network_traffic() {
    # Get received and sent bytes
    local rx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{received += $2} END {print received}')
    local tx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{sent += $10} END {print sent}')

    # Convert to GB - carefully handle the calculation to avoid BC errors
    if [[ -n "$rx_bytes" && "$rx_bytes" != "0" ]]; then
        local rx_gb=$(echo "scale=2; $rx_bytes/1024/1024/1024" | bc 2>/dev/null || echo "0.00")
        # 确保有前导0
        if [[ "$rx_gb" == "."* ]]; then
            rx_gb="0$rx_gb"
        fi
    else
        local rx_gb="0.00"
    fi

    if [[ -n "$tx_bytes" && "$tx_bytes" != "0" ]]; then
        local tx_gb=$(echo "scale=2; $tx_bytes/1024/1024/1024" | bc 2>/dev/null || echo "0.00")
        # 确保有前导0
        if [[ "$tx_gb" == "."* ]]; then
            tx_gb="0$tx_gb"
        fi
    else
        local tx_gb="0.00"
    fi

    echo "$rx_gb $tx_gb"
}

# Function to get geographical location based on IP
get_geo_location() {
    local ip=$1
    if [[ -z "$ip" || "$ip" == "Unknown" ]]; then
        echo "未知"
        return
    fi

    local geo=$(curl -s --max-time 3 "https://ipinfo.io/${ip}/json" 2>/dev/null)
    if [[ -n "$geo" && "$geo" != *"error"* ]]; then
        local country=$(echo "$geo" | grep '"country"' | cut -d'"' -f4)
        local city=$(echo "$geo" | grep '"city"' | cut -d'"' -f4)
        if [[ -n "$country" && -n "$city" ]]; then
            # 转换国家代码为中文名称
            case "$country" in
            "US") country="美国" ;;
            "CN") country="中国" ;;
            "JP") country="日本" ;;
            "KR") country="韩国" ;;
            "SG") country="新加坡" ;;
            "RU") country="俄罗斯" ;;
            "DE") country="德国" ;;
            "GB") country="英国" ;;
            "CA") country="加拿大" ;;
            "AU") country="澳大利亚" ;;
            "FR") country="法国" ;;
            esac
            echo "$country $city"
        else
            echo "未知"
        fi
    else
        echo "未知"
    fi
}


# Function to get IPPure info (fraud score / ASN / organization / residential flag)
# Note: IPPure public endpoint only returns the caller's egress IP info.
get_ippure_info() {
    local resp rc tmp

    # Try a bit harder: follow redirects, set UA, retry, and use a longer timeout.
    # Some networks are slow to establish TLS; a short timeout can cause empty output.
    tmp=$(mktemp 2>/dev/null || echo "/tmp/ippure_curl_err.$$")
    # First try IPv4 (some hosts prefer IPv6; IPPure may return fewer fields over IPv6)
    resp=$(curl -4 -sS -L --fail --connect-timeout 5 --max-time 15 --retry 2 --retry-delay 0 --retry-connrefused \
        -A "Mozilla/5.0 (X11; Linux x86_64)" \
        "https://my.ippure.com/v1/info" 2>"$tmp")
    rc=$?

    if [[ $rc -ne 0 || -z "$resp" ]]; then
        # Fallback to IPv6 (for IPv6-only hosts)
        resp=$(curl -6 -sS -L --fail --connect-timeout 5 --max-time 15 --retry 2 --retry-delay 0 --retry-connrefused \
            -A "Mozilla/5.0 (X11; Linux x86_64)" \
            "https://my.ippure.com/v1/info" 2>"$tmp")
        rc=$?
    fi

    # Strip any NUL bytes just in case
    resp=$(printf '%s' "$resp" | tr -d '\000')

    # Return 6 fields separated by '|': ip|asn|asOrganization|fraudScore|isResidential|isBroadcast
    if [[ $rc -ne 0 || -z "$resp" ]]; then
        if [[ -n "$DEBUG" ]]; then
            echo "[IPPure] curl failed (rc=$rc). stderr:" >&2
            head -n 5 "$tmp" >&2
        fi
        rm -f "$tmp" 2>/dev/null
        echo "未知|未知|未知|未知|未知|未知"
        return
    fi

    if [[ -n "$DEBUG" ]]; then
        echo "[IPPure] raw response (first 200 chars):" >&2
        echo "${resp:0:200}" >&2
    fi
    rm -f "$tmp" 2>/dev/null

    # Prefer python JSON parsing when available (much more reliable than grep/cut)
    if command -v python3 &>/dev/null; then
        local parsed
        parsed=$(echo "$resp" | python3 - <<'PY'
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)

def g(k, default="未知"):
    v = d.get(k, default)
    if v is None or v == "":
        return default
    return str(v)

print("|".join([
    g("ip"),
    g("asn"),
    g("asOrganization"),
    g("fraudScore"),
    g("isResidential"),
    g("isBroadcast"),
]))
PY
        )
        if [[ $? -eq 0 && -n "$parsed" ]]; then
            echo "$parsed"
            return
        fi
    fi

    # Fallback: parse JSON without python/jq (best-effort, works on BusyBox too)
    # Use sed to avoid grep -o/-E incompatibilities on some minimal systems.
    local ip asn asorg fraud isres isbcast
    ip=$(printf '%s' "$resp" | sed -n 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    asn=$(printf '%s' "$resp" | sed -n 's/.*"asn"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)
    asorg=$(printf '%s' "$resp" | sed -n 's/.*"asOrganization"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    fraud=$(printf '%s' "$resp" | sed -n 's/.*"fraudScore"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n 1)
    isres=$(printf '%s' "$resp" | sed -n 's/.*"isResidential"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -n 1)
    isbcast=$(printf '%s' "$resp" | sed -n 's/.*"isBroadcast"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -n 1)

    echo "${ip:-未知}|${asn:-未知}|${asorg:-未知}|${fraud:-未知}|${isres:-未知}|${isbcast:-未知}"
}
# Function to format network congestion algorithm output
format_cong_algo() {
    local algo=$1
    case "$algo" in
    "bbr") echo "BBR" ;;
    "cubic") echo "CUBIC" ;;
    "reno") echo "RENO" ;;
    "vegas") echo "VEGAS" ;;
    "westwood") echo "WESTWOOD" ;;
    *) echo "$algo" ;;
    esac
}

# Get system information with error handling
hostname=$(hostname)
# 改进运营商检测方法，支持更多架构
if [ -f /sys/devices/virtual/dmi/id/product_name ]; then
    provider=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "未知")
elif [ -f /sys/firmware/devicetree/base/model ]; then
    # 适用于ARM和某些嵌入式设备
    provider=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null || echo "未知")
elif [ -f /proc/device-tree/model ]; then
    # 另一种ARM设备路径
    provider=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "未知")
elif [ -f /proc/cpuinfo ] && grep -q "vendor_id" /proc/cpuinfo; then
    # 尝试从cpuinfo获取厂商
    provider=$(grep "vendor_id" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs || echo "未知")
elif [ -f /proc/cpuinfo ] && grep -q "machine" /proc/cpuinfo; then
    # 适用于s390x架构
    provider=$(grep "machine" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs || echo "未知")
elif command -v lscpu &>/dev/null; then
    # 使用lscpu工具
    provider=$(lscpu | grep "Vendor ID" | cut -d':' -f2 | xargs || echo "未知")
elif command -v dmidecode &>/dev/null; then
    # 尝试使用dmidecode（需要root权限）
    provider=$(sudo dmidecode -s system-manufacturer 2>/dev/null || echo "未知")
else
    provider="未知"
fi

# 如果值为空，确保显示"未知"
if [[ -z "$provider" || "$provider" == "" ]]; then
    provider="未知"
fi

# Try multiple methods to get OS version
if command -v lsb_release &>/dev/null; then
    os_version=$(lsb_release -d 2>/dev/null | awk -F':' '{print $2}' | xargs)
elif [ -f /etc/os-release ]; then
    os_version=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
else
    os_version="未知"
fi

kernel_version=$(uname -r)
cpu_arch=$(uname -m)

# 根据不同架构获取CPU型号
if [ -f /proc/cpuinfo ]; then
    if grep -q "model name" /proc/cpuinfo; then
        # 常见x86架构
        cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "未知")
    elif grep -q "Hardware" /proc/cpuinfo; then
        # 适用于ARM架构
        cpu_model=$(grep "Hardware" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "未知")
    elif grep -q "machine" /proc/cpuinfo && [[ "$cpu_arch" == "s390x" ]]; then
        # 适用于s390x架构 - 优化显示
        machine_id=$(grep "machine" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs | cut -d' ' -f3 || echo "")
        # 映射常见IBM大型机型号
        case "${machine_id}" in
        "8561") cpu_model="IBM z15" ;;
        "3906") cpu_model="IBM z14" ;;
        "2964") cpu_model="IBM z13" ;;
        "2827") cpu_model="IBM zEC12" ;;
        "2817") cpu_model="IBM z196" ;;
        "2097") cpu_model="IBM z10" ;;
        "2094") cpu_model="IBM System z9" ;;
        *)
            # 如果无法识别，尝试获取更简洁的表示
            if command -v lscpu &>/dev/null; then
                cpu_model=$(lscpu | grep -E "Model:|Machine" | head -1 | cut -d':' -f2 | xargs || echo "IBM ${machine_id}")
            else
                cpu_model="IBM ${machine_id}"
            fi
            ;;
        esac
    elif grep -q "cpu" /proc/cpuinfo; then
        # 其他cpuinfo格式
        cpu_model=$(grep "cpu" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs || echo "未知")
    else
        cpu_model="未知"
    fi
elif command -v lscpu &>/dev/null; then
    # 尝试使用lscpu获取CPU信息
    cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs || echo "未知")
else
    cpu_model="未知"
fi

# 如果值为空，确保显示"未知"
if [[ -z "$cpu_model" || "$cpu_model" == "" ]]; then
    cpu_model="未知"
fi

cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "未知")

# Get CPU usage with multiple methods for better reliability
get_cpu_usage() {
    local cpu_usage="0.0"

    # 方法1: 尝试使用mpstat (如果安装了sysstat)
    if command -v mpstat &>/dev/null; then
        cpu_idle=$(mpstat 1 1 | grep -A 5 "%idle" | tail -n 1 | awk '{print $NF}' | tr ',' '.')
        if [[ -n "$cpu_idle" && "$cpu_idle" != "0.00" ]]; then
            cpu_usage=$(echo "100 - $cpu_idle" | bc 2>/dev/null)
            if [[ -n "$cpu_usage" ]]; then
                echo "$cpu_usage"
                return
            fi
        fi
    fi

    # 方法2: 通过/proc/stat计算
    if [ -f /proc/stat ]; then
        # 获取两个采样点
        local cpu_stat1=$(grep '^cpu ' /proc/stat)
        sleep 0.2
        local cpu_stat2=$(grep '^cpu ' /proc/stat)

        # 解析数据
        local user1=$(echo "$cpu_stat1" | awk '{print $2}')
        local nice1=$(echo "$cpu_stat1" | awk '{print $3}')
        local system1=$(echo "$cpu_stat1" | awk '{print $4}')
        local idle1=$(echo "$cpu_stat1" | awk '{print $5}')

        local user2=$(echo "$cpu_stat2" | awk '{print $2}')
        local nice2=$(echo "$cpu_stat2" | awk '{print $3}')
        local system2=$(echo "$cpu_stat2" | awk '{print $4}')
        local idle2=$(echo "$cpu_stat2" | awk '{print $5}')

        # 计算差异
        local total1=$((user1 + nice1 + system1 + idle1))
        local total2=$((user2 + nice2 + system2 + idle2))
        local total_diff=$((total2 - total1))
        local idle_diff=$((idle2 - idle1))

        if [[ $total_diff -gt 0 ]]; then
            # 计算使用率 (100% - 空闲%)
            cpu_usage=$(echo "scale=1; 100 - ($idle_diff * 100 / $total_diff)" | bc 2>/dev/null || echo "0.0")
            echo "$cpu_usage"
            return
        fi
    fi

    # 方法3: 尝试更通用地提取top输出
    local top_output=$(top -bn1 2>/dev/null)

    # 尝试提取总CPU使用率或计算 100-idle
    if echo "$top_output" | grep -q "Cpu(s)"; then
        # 提取idle百分比
        local cpu_idle=$(echo "$top_output" | grep "Cpu(s)" | grep -o "[0-9]\+\.[0-9]\+.id" | grep -o "[0-9]\+\.[0-9]\+")
        if [[ -n "$cpu_idle" ]]; then
            cpu_usage=$(echo "100 - $cpu_idle" | bc 2>/dev/null || echo "0.0")
        else
            # 尝试提取user+system
            local cpu_user=$(echo "$top_output" | grep "Cpu(s)" | grep -o "[0-9]\+\.[0-9]\+.us" | grep -o "[0-9]\+\.[0-9]\+")
            local cpu_sys=$(echo "$top_output" | grep "Cpu(s)" | grep -o "[0-9]\+\.[0-9]\+.sy" | grep -o "[0-9]\+\.[0-9]\+")
            if [[ -n "$cpu_user" && -n "$cpu_sys" ]]; then
                cpu_usage=$(echo "$cpu_user + $cpu_sys" | bc 2>/dev/null || echo "0.0")
            fi
        fi
    fi

    # 确保结果至少有一位小数
    if [[ "$cpu_usage" == *"."* ]]; then
        echo "$cpu_usage"
    else
        echo "${cpu_usage}.0"
    fi
}

# Get CPU usage, ensuring realistic values
cpu_usage_raw=$(get_cpu_usage)
if [[ -z "$cpu_usage_raw" || "$cpu_usage_raw" == "0" || "$cpu_usage_raw" == "0.0" ]]; then
    # 如果所有方法都返回0，尝试获取任意非零进程的CPU使用率
    cpu_process=$(ps -eo pcpu --sort=-pcpu | head -n 2 | tail -n 1)
    if [[ -n "$cpu_process" && "$cpu_process" != "0.0" ]]; then
        cpu_usage_raw="$cpu_process"
    else
        cpu_usage_raw="0.1" # 至少显示一点活动
    fi
fi
cpu_usage="${cpu_usage_raw}%"

# Get memory information with error handling
if command -v free &>/dev/null; then
    mem_info=$(free -m | grep Mem)
    total_mem=$(echo $mem_info | awk '{print $2}')
    used_mem=$(echo $mem_info | awk '{print $3}')
    if [[ -n "$used_mem" && -n "$total_mem" && "$total_mem" != "0" ]]; then
        mem_percent=$(echo "scale=2; ($used_mem/$total_mem)*100" | bc 2>/dev/null || echo "0")
        mem_percent="${mem_percent}%"
    else
        mem_percent="未知"
    fi

    # Get swap information
    swap_info=$(free -m | grep Swap)
    total_swap=$(echo $swap_info | awk '{print $2}')
    used_swap=$(echo $swap_info | awk '{print $3}')
    if [[ -n "$used_swap" && -n "$total_swap" ]]; then
        if [[ "$total_swap" -eq 0 ]]; then
            swap_percent="0%"
        else
            swap_percent=$(echo "scale=2; ($used_swap/$total_swap)*100" | bc 2>/dev/null || echo "0")
            swap_percent="${swap_percent}%"
        fi
    else
        swap_percent="未知"
    fi
else
    total_mem="未知"
    used_mem="未知"
    mem_percent="未知"
    total_swap="未知"
    used_swap="未知"
    swap_percent="未知"
fi

# Get disk information with error handling
if command -v df &>/dev/null; then
    disk_info=$(df -h / 2>/dev/null | grep -v Filesystem)
    disk_used=$(echo $disk_info | awk '{print $3}')
    disk_total=$(echo $disk_info | awk '{print $2}')
    disk_percent=$(echo $disk_info | awk '{print $5}')
else
    disk_used="未知"
    disk_total="未知"
    disk_percent="未知"
fi

# Get network traffic with error handling
if [ -f /proc/net/dev ]; then
    read rx_gb tx_gb <<<"$(get_network_traffic)"
    # 确保值不为空，改成两位小数
    rx_gb=${rx_gb:-"0.00"}
    tx_gb=${tx_gb:-"0.00"}

    # 如果值非常小（但不是0），尝试以MB为单位显示
    if [[ "$rx_gb" == "0.00" || $(echo "$rx_gb < 0.01" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        rx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{received += $2} END {print received}')
        if [[ -n "$rx_bytes" && "$rx_bytes" != "0" ]]; then
            rx_mb=$(echo "scale=2; $rx_bytes/1024/1024" | bc 2>/dev/null || echo "0.00")
            # 确保有前导0
            if [[ "$rx_mb" == "."* ]]; then
                rx_mb="0$rx_mb"
            elif [[ -z "$rx_mb" ]]; then
                rx_mb="0.00"
            fi
            rx_display="${rx_mb} MB"
        else
            rx_display="0.00 GB"
        fi
    else
        rx_display="${rx_gb} GB"
    fi

    if [[ "$tx_gb" == "0.00" || $(echo "$tx_gb < 0.01" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        tx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{sent += $10} END {print sent}')
        if [[ -n "$tx_bytes" && "$tx_bytes" != "0" ]]; then
            tx_mb=$(echo "scale=2; $tx_bytes/1024/1024" | bc 2>/dev/null || echo "0.00")
            # 确保有前导0
            if [[ "$tx_mb" == "."* ]]; then
                tx_mb="0$tx_mb"
            elif [[ -z "$tx_mb" ]]; then
                tx_mb="0.00"
            fi
            tx_display="${tx_mb} MB"
        else
            tx_display="0.00 GB"
        fi
    else
        tx_display="${tx_gb} GB"
    fi
else
    rx_display="未知"
    tx_display="未知"
fi

# Get network congestion algorithm with error handling
if command -v sysctl &>/dev/null; then
    tcp_cong_raw=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo "未知")
    tcp_cong=$(format_cong_algo "$tcp_cong_raw")
else
    tcp_cong="未知"
fi

# Get public IP addresses with timeout to avoid hanging
ipv4_addr=$(curl -s --max-time 3 https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n' || echo "未知")
ipv6_addr=$(curl -s --max-time 3 https://ipv6.icanhazip.com 2>/dev/null | tr -d '\n' || echo "不可用")

# Get IPPure fraud / ASN info for current egress IP
IFS='|' read ippure_ip ippure_asn ippure_asorg ippure_fraud ippure_isres ippure_isbcast <<<"$(get_ippure_info)"

# Derive IP property label from IPPure flags
ippure_property="未知"
if [[ "$ippure_isbcast" == "true" ]]; then
    ippure_property="广播IP"
elif [[ "$ippure_isres" == "true" ]]; then
    ippure_property="住宅IP"
elif [[ "$ippure_isres" == "false" ]]; then
    ippure_property="机房IP"
fi

# Get location based on IP
location=$(get_geo_location "$ipv4_addr")

# Get system time
sys_time=$(date "+%Y-%m-%d %H:%M %p")

# Get uptime with error handling and convert to Chinese
if command -v uptime &>/dev/null; then
    # 获取原始uptime输出
    uptime_full=$(uptime)

    # 完全重写uptime解析
    # 初始化变量
    uptime_str=""
    weeks=0
    days=0
    hours=0
    minutes=0

    # 提取周数
    weeks_pattern='([0-9]+) week[s]*'
    if [[ $uptime_full =~ $weeks_pattern ]]; then
        weeks="${BASH_REMATCH[1]}"
        [[ $weeks -gt 0 ]] && uptime_str="${uptime_str}${weeks}周"
    fi

    # 提取天数
    days_pattern='([0-9]+) day[s]*'
    if [[ $uptime_full =~ $days_pattern ]]; then
        days="${BASH_REMATCH[1]}"
        [[ $days -gt 0 ]] && uptime_str="${uptime_str}${days}天"
    fi

    # 通过uptime -p获取时分
    if uptime -p &>/dev/null; then
        time_info=$(uptime -p)

        # 提取小时
        hours_pattern='([0-9]+) hour[s]*'
        if [[ $time_info =~ $hours_pattern ]]; then
            hours="${BASH_REMATCH[1]}"
            (( 10#$hours > 0 )) && uptime_str="${uptime_str}${hours}小时"
        fi

        # 提取分钟
        minutes_pattern='([0-9]+) minute[s]*'
        if [[ $time_info =~ $minutes_pattern ]]; then
            minutes="${BASH_REMATCH[1]}"
            (( 10#$minutes > 0 )) && uptime_str="${uptime_str}${minutes}分钟"
        fi
    else
        # 如果uptime -p不支持，解析传统uptime输出的HH:MM格式
        time_pattern='up.*([0-9]+):([0-9]+)'
        if [[ $uptime_full =~ $time_pattern ]]; then
            hours="${BASH_REMATCH[1]}"
            minutes="${BASH_REMATCH[2]}"
            (( 10#$hours > 0 )) && uptime_str="${uptime_str}${hours}小时"
            (( 10#$minutes > 0 )) && uptime_str="${uptime_str}${minutes}分钟"
        fi
    fi

    # 如果最终字符串仍为空，使用备用方法
    if [[ -z "$uptime_str" ]]; then
        # 尝试直接解析
        uptime_raw=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | sed 's/.*up \([^,]*\),.*/\1/')
        # 先做安全替换
        uptime_raw=$(echo "$uptime_raw" | tr -d ',')
        # 使用临时变量执行替换，避免多次替换
        uptime_tmp=$(echo "$uptime_raw" | sed -E 's/([0-9]+) weeks?/\1周/g')
        uptime_tmp=$(echo "$uptime_tmp" | sed -E 's/([0-9]+) days?/\1天/g')
        uptime_tmp=$(echo "$uptime_tmp" | sed -E 's/([0-9]+) hours?/\1小时/g')
        uptime_tmp=$(echo "$uptime_tmp" | sed -E 's/([0-9]+) minutes?/\1分钟/g')
        uptime_tmp=$(echo "$uptime_tmp" | sed -E 's/([0-9]+) seconds?/\1秒/g')
        # 移除所有可能导致问题的空格
        uptime_str=$(echo "$uptime_tmp" | tr -d ' ')
    fi

    # 防止任何可能导致s后缀的问题
    uptime_str=$(echo "$uptime_str" | sed -E 's/小时s?/小时/g')
    uptime_str=$(echo "$uptime_str" | sed -E 's/分钟s?/分钟/g')
    uptime_str=$(echo "$uptime_str" | sed -E 's/秒s?/秒/g')

    # 最终清理
    uptime_info="$uptime_str"
else
    uptime_info="未知"
fi

# Print header with decoration
echo -e "\n${WHITE}${BOLD}✦ 系统信息详情 ✦${NC}"
echo -e "$DIVIDER"

# Column layout with improved formatting
echo -e "► 主机名: ${PURPLE}$hostname${NC}"
echo -e "► 运营商: ${PURPLE}$provider${NC}"
echo -e "$DIVIDER"
echo -e "► 系统版本: ${PURPLE}$os_version${NC}"
echo -e "► Linux版本: ${PURPLE}$kernel_version${NC}"
echo -e "$DIVIDER"
echo -e "► CPU架构: ${PURPLE}$cpu_arch${NC}"
echo -e "► CPU型号: ${PURPLE}$cpu_model${NC}"
echo -e "► CPU核心数: ${PURPLE}$cpu_cores${NC}"
echo -e "$DIVIDER"
echo -e "► CPU占用: ${PURPLE}$cpu_usage${NC}"
echo -e "► 物理内存: ${PURPLE}${used_mem}/${total_mem} MB (${mem_percent})${NC}"
echo -e "► 虚拟内存: ${PURPLE}${used_swap}/${total_swap}MB (${swap_percent})${NC}"
echo -e "► 硬盘占用: ${PURPLE}${disk_used}/${disk_total} (${disk_percent})${NC}"
echo -e "$DIVIDER"
echo -e "► 总接收: ${PURPLE}${rx_display}${NC}"
echo -e "► 总发送: ${PURPLE}${tx_display}${NC}"
echo -e "$DIVIDER"
echo -e "► 网络拥塞算法: ${PURPLE}$tcp_cong${NC}"
echo -e "$DIVIDER"
echo -e "► 公网IPv4地址: ${PURPLE}$ipv4_addr${NC}"
echo -e "► 公网IPv6地址: ${PURPLE}$ipv6_addr${NC}"
echo -e "► IPPure检测IP: ${PURPLE}${ippure_ip}${NC}"
echo -e "► IPPure ASN/组织: ${PURPLE}${ippure_asn} / ${ippure_asorg}${NC}"
echo -e "► IPPure 欺诈值: ${PURPLE}${ippure_fraud}${NC}"
echo -e "► IP属性: ${PURPLE}${ippure_property}${NC}"
echo -e "$DIVIDER"
echo -e "► 地理位置: ${PURPLE}$location${NC}"
echo -e "► 系统时间: ${PURPLE}$sys_time${NC}"
echo -e "$DIVIDER"
echo -e "► 运行时长: ${PURPLE}$uptime_info${NC}"
echo -e "$DIVIDER"
echo -e "${GREEN}✓ 系统检测完成${NC}"
