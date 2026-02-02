cmake_minimum_required(VERSION 3.14)
project(a1_service_helper)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Windows subsystem (no console window)
set(CMAKE_WIN32_EXECUTABLE ON)

add_executable(a1_service_helper WIN32
    a1_service_helper.cpp
)

target_link_libraries(a1_service_helper PRIVATE
    user32
    kernel32
    advapi32
    shlwapi
    shell32
)

# Strip debug info for release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set_target_properties(a1_service_helper PROPERTIES
        MSVC_RUNTIME_LIBRARY "MultiThreaded"
    )
endif()
