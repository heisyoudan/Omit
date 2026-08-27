#!/usr/bin/env python3
"""Independent fixture oracle. Intentionally imports no Omit production code."""

import json
import math
import sys


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def close(actual, expected):
    return actual is not None and math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12)


def main(path):
    with open(path, encoding="utf-8") as stream:
        records = [json.loads(line) for line in stream if line.strip()]
    by_name = {record["fixtureName"]: record for record in records}
    require(len(records) == 22 and len(by_name) == 22, "expected 22 unique fixture records")

    baseline = by_name["cpuBaseline"]["cpu"]["ticks"]
    current = by_name["cpuValidDelta"]["cpu"]["ticks"]
    usages = []
    for old, new in zip(baseline, current):
        busy = sum(new[key] - old[key] for key in ("user", "system", "nice"))
        idle = new["idle"] - old["idle"]
        usages.append(busy / (busy + idle))
    require(close(by_name["cpuValidDelta"]["cpu"]["calculatedFraction"], sum(usages) / len(usages)), "CPU delta mismatch")
    require(by_name["cpuCounterRollback"]["cpu"].get("calculatedFraction") is None, "CPU rollback must be unavailable")
    require(by_name["cpuInvalidSnapshot"]["cpu"]["availability"] == "unavailable", "invalid CPU snapshot must be unavailable")

    vm = by_name["vmDeterministic"]["memory"]
    page = vm["pageSize"]
    gross = sum(vm[key] * page for key in ("activePages", "inactivePages", "speculativePages", "wiredPages", "compressedPages"))
    reclaimable = sum(vm[key] * page for key in ("purgeablePages", "externalPages"))
    expected_used = min(max(gross - reclaimable, 0), vm["physicalMemory"])
    require(vm["calculatedUsedBytes"] == expected_used, "memory used mismatch")
    require(vm["calculatedActiveBytes"] == min(vm["activePages"] * page, vm["physicalMemory"]), "memory active mismatch")
    require(close(vm["calculatedFraction"], expected_used / vm["physicalMemory"]), "memory fraction mismatch")

    first = by_name["networkFirstSample"]["network"]
    valid = by_name["networkValidDelta"]["network"]
    interval = valid["counterUptime"] - first["counterUptime"]
    require(close(valid["calculatedDownloadBytesPerSecond"], (valid["receivedBytes"] - first["receivedBytes"]) / interval), "network RX rate mismatch")
    require(close(valid["calculatedUploadBytesPerSecond"], (valid["transmittedBytes"] - first["transmittedBytes"]) / interval), "network TX rate mismatch")
    reasons = {
        "networkFirstSample": "firstSample", "networkInterfaceSwitch": "interfaceSwitch",
        "networkCounterReset": "counterReset", "networkSleepGap": "sleepGap",
        "networkDisconnect": "disconnect",
    }
    for name, expected in reasons.items():
        require(by_name[name]["network"]["baselineResetReason"] == expected, f"{name} reset reason mismatch")

    battery_expected = {
        "batteryNoBattery": "noBattery", "batteryUnavailable": "unavailable",
        "batteryOnBattery100": "onBattery", "batteryCharging": "charging",
        "batteryPowerAdapter": "externalPower", "batteryFullyCharged": "fullyCharged",
    }
    for name, expected in battery_expected.items():
        require(by_name[name]["battery"]["mappedState"] == expected, f"{name} mapping mismatch")

    thermal_expected = {state: state for state in ("nominal", "fair", "serious", "critical")}
    thermal_expected["unknown"] = "unavailable"
    for raw, expected in thermal_expected.items():
        require(by_name[f"thermal-{raw}"]["thermal"]["mappedState"] == expected, f"thermal {raw} mapping mismatch")

    print("PASS: independent raw-counter oracle validated 22 fixtures")


if __name__ == "__main__":
    require(len(sys.argv) == 2, "usage: verify_fixture_jsonl.py PATH")
    main(sys.argv[1])
