# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "pdfium_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

set(PDFIUM_RELEASE chromium%2F7520)
set(PDFIUM_DIR ${CMAKE_BINARY_DIR}/pdfium)
set(PDFIUM_RELEASE_DIR ${PDFIUM_DIR}/${PDFIUM_RELEASE})

file(MAKE_DIRECTORY ${PDFIUM_RELEASE_DIR})

# Determine target processor name for Windows
IF(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
    SET(CPU_NAME "x64")
ELSEIF(CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
    SET(CPU_NAME "arm64")
ELSE()
    MESSAGE(FATAL_ERROR "Unsupported Windows architecture \"${CMAKE_SYSTEM_PROCESSOR}\". Only AMD64 and ARM64 are supported.")
ENDIF()
message( STATUS "Target Windows CPU Name: ${CPU_NAME}" )

set(PDFIUM_PLATFORM "win")
set(PDFIUM_LIB_FILENAME "pdfium.dll")
set(PDFIUM_LIB_DIR "bin")
set(PDFIUM_WIN_ABI ${CPU_NAME})

set(PDFIUM_ARCHIVE_NAME pdfium-${PDFIUM_PLATFORM}-${PDFIUM_WIN_ABI})
set(PDFIUM_SRC_LIB_FILENAME ${PDFIUM_RELEASE_DIR}/${PDFIUM_LIB_DIR}/${PDFIUM_LIB_FILENAME})

set(PDFIUM_LIBS_DIR ${CMAKE_BINARY_DIR}/.lib/${PDFIUM_RELEASE})
set(PDFIUM_LIBS_ARCH_DIR ${PDFIUM_LIBS_DIR}/${PDFIUM_WIN_ABI})
set(PDFIUM_DEST_LIB_FILENAME ${PDFIUM_LIBS_ARCH_DIR}/${PDFIUM_LIB_FILENAME})

set(PDFIUM_LATEST_DIR ${CMAKE_BINARY_DIR}/.lib/latest)
set(PDFIUM_LATEST_LIBS_ARCH_DIR ${PDFIUM_LATEST_DIR}/${PDFIUM_WIN_ABI})
set(PDFIUM_LATEST_LIB_FILENAME ${PDFIUM_LATEST_LIBS_ARCH_DIR}/${PDFIUM_LIB_FILENAME})

if(NOT EXISTS ${PDFIUM_SRC_LIB_FILENAME})
    # PANORA fork — 2026-05-16. The upstream pdfium_flutter recipe blindly
    # calls file(DOWNLOAD) and never checks the result. On a network where
    # release-assets.githubusercontent.com is blocked (corporate proxy,
    # AdGuard DNS, ESET HTTPS scan, …) the download lays down a 0-byte
    # tarball, the tar extract "succeeds" with zero output, and the build
    # eventually dies six lines later at file(COPY …pdfium.dll) with a
    # cryptic "cannot find / File exists" message that doesn't explain
    # the underlying connectivity failure.
    #
    # New flow:
    #   1. Honour env var $PDFIUM_CACHE_DIR. If a prebuilt tarball is
    #      sitting in that directory (the publisher manually fetched it
    #      once via a working connection and dropped it there), use it
    #      and skip the network round-trip entirely. This also survives
    #      `flutter clean`, which wipes build/ but never touches the
    #      cache dir.
    #   2. Otherwise try file(DOWNLOAD …) WITH a STATUS variable. If the
    #      status is non-zero OR the resulting file is suspiciously small
    #      (< 100 KB; real tarball is ~5 MB), abort with an actionable
    #      error pointing the user at the manual-cache workaround.
    set(_pdfium_tgz "${PDFIUM_RELEASE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz")
    set(_pdfium_url "https://github.com/bblanchon/pdfium-binaries/releases/download/${PDFIUM_RELEASE}/${PDFIUM_ARCHIVE_NAME}.tgz")

    set(_cache_tgz "")
    if(DEFINED ENV{PDFIUM_CACHE_DIR})
        set(_cache_tgz "$ENV{PDFIUM_CACHE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz")
        if(EXISTS "${_cache_tgz}")
            message(STATUS "Using cached PDFium archive: ${_cache_tgz}")
            file(COPY "${_cache_tgz}" DESTINATION "${PDFIUM_RELEASE_DIR}")
        else()
            message(STATUS "PDFIUM_CACHE_DIR set but no archive at: ${_cache_tgz}")
            set(_cache_tgz "")
        endif()
    endif()

    if(NOT EXISTS "${_pdfium_tgz}")
        message(STATUS "Downloading precompiled PDFium from ${_pdfium_url}")
        file(DOWNLOAD
            "${_pdfium_url}"
            "${_pdfium_tgz}"
            STATUS _download_status
            SHOW_PROGRESS
            TLS_VERIFY ON
        )
        list(GET _download_status 0 _download_code)
        list(GET _download_status 1 _download_msg)
        if(NOT _download_code EQUAL 0)
            file(REMOVE "${_pdfium_tgz}")
            message(FATAL_ERROR
                "\n"
                "========================================================================\n"
                "  PDFium archive could NOT be downloaded.\n"
                "------------------------------------------------------------------------\n"
                "  URL    : ${_pdfium_url}\n"
                "  Status : ${_download_code} -- ${_download_msg}\n"
                "\n"
                "  Common causes:\n"
                "    * DNS resolver (AdGuard, Pi-hole, corporate filter) is\n"
                "      blocking release-assets.githubusercontent.com\n"
                "    * Antivirus HTTPS scan is breaking the TLS handshake\n"
                "    * Corporate proxy without proper TLS pass-through\n"
                "\n"
                "  Manual workaround (one-time):\n"
                "    1. From a machine with working network, download:\n"
                "         ${_pdfium_url}\n"
                "    2. Save the file (keep the original name '${PDFIUM_ARCHIVE_NAME}.tgz')\n"
                "       into a local cache directory, e.g.:\n"
                "         <project>/tools/pdfium_cache/\n"
                "    3. Re-run the build with the PDFIUM_CACHE_DIR env var pointing\n"
                "       at that directory. The PANORA build scripts already do this\n"
                "       automatically when tools/pdfium_cache/ exists.\n"
                "========================================================================\n"
            )
        endif()
        # Sanity-check: a 0-byte tarball means the download silently failed
        # (server returned an error body that fit in headers, AV nuked the
        # transfer mid-stream, etc.). Refuse to proceed; the user gets the
        # same actionable message as a hard status failure.
        file(SIZE "${_pdfium_tgz}" _pdfium_tgz_size)
        if(_pdfium_tgz_size LESS 100000)
            file(REMOVE "${_pdfium_tgz}")
            message(FATAL_ERROR
                "\n"
                "========================================================================\n"
                "  PDFium archive downloaded but is only ${_pdfium_tgz_size} bytes\n"
                "  (expected ~5 MB). Something in your network stack truncated the\n"
                "  transfer. See the manual-workaround instructions above.\n"
                "========================================================================\n"
            )
        endif()
    endif()

    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar zxf "${_pdfium_tgz}"
        WORKING_DIRECTORY ${PDFIUM_RELEASE_DIR}
        RESULT_VARIABLE STATUS
        ERROR_QUIET
    )
    if(STATUS AND NOT STATUS EQUAL 0)
        message(FATAL_ERROR "Could not extract PDFium archive: ${STATUS}")
    endif()
    if(NOT EXISTS "${PDFIUM_SRC_LIB_FILENAME}")
        message(FATAL_ERROR
            "\n"
            "  PDFium tarball extracted, but ${PDFIUM_LIB_FILENAME} not found at:\n"
            "    ${PDFIUM_SRC_LIB_FILENAME}\n"
            "  The downloaded archive may be corrupted; delete the .tgz and retry."
        )
    endif()
else()
    message(STATUS "Use existing precompiled PDFium.")
endif()

if (NOT EXISTS ${PDFIUM_DEST_LIB_FILENAME})
    file(MAKE_DIRECTORY ${PDFIUM_LIBS_ARCH_DIR})
    file(COPY ${PDFIUM_SRC_LIB_FILENAME} DESTINATION ${PDFIUM_LIBS_ARCH_DIR})
endif()

# also copy header files for dev use
if (NOT EXISTS ${PDFIUM_LIBS_DIR}/include)
    file(COPY ${PDFIUM_RELEASE_DIR}/include DESTINATION ${PDFIUM_LIBS_DIR})
endif()

file(REMOVE ${PDFIUM_LATEST_DIR})

# Check if we can create symbolic links (requires Developer Mode on Windows)
execute_process(
    COMMAND ${CMAKE_COMMAND} -E create_symlink ${PDFIUM_LIBS_DIR} ${PDFIUM_LATEST_DIR}_test
    RESULT_VARIABLE SYMLINK_RESULT
    ERROR_QUIET
    OUTPUT_QUIET
)

if(EXISTS ${PDFIUM_LATEST_DIR}_test)
    file(REMOVE ${PDFIUM_LATEST_DIR}_test)
endif()

if(SYMLINK_RESULT EQUAL 0)
    # Developer Mode is enabled, use symbolic link
    file(CREATE_LINK ${PDFIUM_LIBS_DIR} ${PDFIUM_LATEST_DIR} SYMBOLIC)
else()
    # Developer Mode is not enabled, fail the build
    message(FATAL_ERROR "\n"
        "========================================================================\n"
        "  ERROR: Windows Developer Mode is not enabled!\n"
        "------------------------------------------------------------------------\n"
        "  The pdfium_flutter build process requires Developer Mode to create symbolic\n"
        "  links. The build cannot continue without Developer Mode enabled.\n"
        "\n"
        "  Please enable Developer Mode by following the instructions at:\n"
        "  https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development#activate-developer-mode\n"
        "\n"
        "  After enabling Developer Mode, restart your computer and run the\n"
        "  build again.\n"
        "========================================================================\n"
    )
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(pdfium_flutter_bundled_libraries
  ${PDFIUM_LATEST_LIB_FILENAME}
  PARENT_SCOPE
)
