#!/bin/bash

CPU_CRIT=85
GPU_EDGE_CRIT=85
GPU_JUNCTION_CRIT=95
NVME_CRIT=80

INTERVAL=5           
GRACE_CRIT=6

LOG_FILE="/var/log/thermal-guard.log"

crit_count=0

log() {
	local level="$1"
	local msg="$2"
	echo "$(date '+%Y-%m-%d %H:%M:%S') [${level}] ${msg}" >> "$LOG_FILE"
}

read_temp() {
	local label="$1"
	local input="$2"
	for hwmon in /sys/class/hwmon/hwmon*; do
		[[ -f "$hwmon/name" ]] || continue
		if [[ "$(cat "$hwmon/name")" == "$label" ]]; then
			if [[ -f "$hwmon/$input" ]]; then
				echo $(( $(cat "$hwmon/$input") / 1000 ))
				return
			fi
		fi
	done
	echo 0
}

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "INFO" "Thermal Guard started. CPU_CRIT=${CPU_CRIT}°C GPU_EDGE_CRIT=${GPU_EDGE_CRIT}°C GPU_JUNCTION_CRIT=${GPU_JUNCTION_CRIT}°C NVME_CRIT=${NVME_CRIT}°C"

while true; do
	cpu=$(read_temp "k10temp" "temp1_input")
	gpu_edge=$(read_temp "amdgpu" "temp1_input")
	gpu_junction=$(read_temp "amdgpu" "temp2_input")
	nvme=$(read_temp "nvme" "temp1_input")
	
	temps_str="CPU=${cpu}°C GPU_edge=${gpu_edge}°C GPU_junction=${gpu_junction}°C NVMe=${nvme}°C"
	
	if (( cpu >= CPU_CRIT || gpu_edge >= GPU_EDGE_CRIT || gpu_junction >= GPU_JUNCTION_CRIT || nvme >= NVME_CRIT )); then
		((crit_count++))
		
		if (( crit_count == 1 )); then
			log "CRIT" "Critical temperature detected: ${temps_str}"
		fi
		
		if (( crit_count >= GRACE_CRIT )); then
			log "CRIT" "SHUTTING DOWN after ${GRACE_CRIT} sustained critical readings. Final values: ${temps_str}"
			sync
			/sbin/shutdown -h now "Automatic thermal shutdown"
			exit 0
		fi
	else
		crit_count=0
	fi
	
	sleep $INTERVAL
done