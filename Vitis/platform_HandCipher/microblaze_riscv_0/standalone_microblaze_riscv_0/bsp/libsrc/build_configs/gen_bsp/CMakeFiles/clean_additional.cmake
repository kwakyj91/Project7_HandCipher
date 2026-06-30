# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "/home/appletea/workspace_onedevice_2/Project_7_HandCipher/Vitis/platform_HandCipher/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/sleep.h"
  "/home/appletea/workspace_onedevice_2/Project_7_HandCipher/Vitis/platform_HandCipher/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xiltimer.h"
  "/home/appletea/workspace_onedevice_2/Project_7_HandCipher/Vitis/platform_HandCipher/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xtimer_config.h"
  "/home/appletea/workspace_onedevice_2/Project_7_HandCipher/Vitis/platform_HandCipher/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/lib/libxiltimer.a"
  )
endif()
