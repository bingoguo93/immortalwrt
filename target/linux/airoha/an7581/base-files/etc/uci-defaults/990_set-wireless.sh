#!/bin/sh
. /usr/share/libubox/jshn.sh

# 默认WIFI设置
BASE_SSID='an7581'
BASE_WORD='12345678'

# 获取无线设备的数量
RADIO_NUM=$(uci show wireless | grep -c "wifi-device")

# 如果没有找到无线设备，直接退出
[ "$RADIO_NUM" -eq 0 ] && exit 0

# 配置参数
configure_wifi() {
	local radio=$1
	local channel=$2
	local htmode=$3
	local ssid=$4

	# 设置无线设备参数
	uci set wireless.radio${radio}.channel=${channel}
	uci set wireless.radio${radio}.htmode=${htmode}
	uci set wireless.radio${radio}.country='CN'

	uci set wireless.default_radio${radio}.ssid=${ssid}
	uci set wireless.default_radio${radio}.key=${BASE_WORD}
	uci set wireless.default_radio${radio}.encryption='psk2+ccmp'
}

# 查询mode
query_mode() {
	json_load_file "/etc/board.json"
	json_select wlan
	json_get_keys phy_keys
	for phy in $phy_keys; do
		json_select $phy
		json_get_var path_value "path"
		if [ "$path_value" = "$1" ]; then
			json_select info
			json_select bands
			json_get_keys band_keys
			for band in $band_keys; do
				json_select $band
				json_select modes
				json_get_keys mode_keys
				for mode in $mode_keys; do
					json_get_var mode_value $mode
					last_mode=$mode_value
				done
				json_select ..
				json_select ..
			done
			echo "$last_mode"
			return
		fi
		json_select ..
	done
}

# 设置无线设备的默认配置
FIRST_5G=''
set_wifi_def_cfg() {
	local band=$(uci get wireless.radio${1}.band)
	local path=$(uci get wireless.radio${1}.path)
	local htmode=$(query_mode "$path")
	local channel=6
	local ssid="$BASE_SSID"

	case "$band" in
	'5g')
		channel=44
		htmode='HE160'
		ssid="${BASE_SSID}_5G"
		;;
	*)
			htmode='HE40'
		;;
	esac

	configure_wifi "$1" "$channel" "$htmode" "$ssid"
}

for i in $(seq 0 $((RADIO_NUM - 1))); do
	set_wifi_def_cfg "$i"
done

# 提交配置并重启网络服务
uci commit wireless

exit 0
