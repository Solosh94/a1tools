# Privacy Payload DLL
# This DLL is injected into target processes to hide windows from screen capture

cmake_minimum_required(VERSION 3.14)

project(privacy_payload LANGUAGES CXX)

add_library(privacy_payload SHARED
  privacy_payload.cpp
)

# Use C++17
target_compile_features(privacy_payload PUBLIC cxx_std_17)

# Define exports
target_compile_definitions(privacy_payload PRIVATE PRIVACY_PAYLOAD_EXPORTS)

# Link required Windows libraries
target_link_libraries(privacy_payload PRIVATE
  user32
)

# Set output name - output to same directory as main executable
set_target_properties(privacy_payload PROPERTIES
  OUTPUT_NAME "privacy_payload"
)
