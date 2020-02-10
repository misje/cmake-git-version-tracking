# git_watcher.cmake
# https://raw.githubusercontent.com/misje/cmake-git-version-tracking/master/git_watcher.cmake
#
# Released under the MIT License.
# https://raw.githubusercontent.com/misje/cmake-git-version-tracking/master/LICENSE

# This file defines a target that monitors the state of a git repo.
# If the state changes (e.g. a commit is made), then a file gets reconfigured.
# Here are the primary variables that control script behavior:
#
#   PRE_CONFIGURE_FILE (REQUIRED)
#   -- The path to the file that'll be configured.
#
#   POST_CONFIGURE_FILE (REQUIRED)
#   -- The path to the configured PRE_CONFIGURE_FILE.
#
#   GIT_STATE_FILE (OPTIONAL)
#   -- The path to the file used to store the previous build's git state.
#      Defaults to the current binary directory.
#
#   GIT_WORKING_DIR (OPTIONAL)
#   -- The directory from which git commands will be run.
#      Defaults to the directory with the top level CMakeLists.txt.
#
#   GIT_EXECUTABLE (OPTIONAL)
#   -- The path to the git executable. It'll automatically be set if the
#      user doesn't supply a path.
#
# DESIGN
#   - This script was designed similar to a Python application
#     with a Main() function. I wanted to keep it compact to
#     simplify "copy + paste" usage.
#
#   - This script is invoked under two CMake contexts:
#       1. Configure time (when build files are created).
#       2. Build time (called via CMake -P).
#     The first invocation is what registers the script to
#     be executed at build time.

# Short hand for converting paths to absolute.
macro(PATH_TO_ABSOLUTE var_name)
    get_filename_component(${var_name} "${${var_name}}" ABSOLUTE)
endmacro()

# Check that a required variable is set.
macro(CHECK_REQUIRED_VARIABLE var_name)
    if(NOT DEFINED ${var_name})
        message(FATAL_ERROR "The \"${var_name}\" variable must be defined.")
    endif()
    PATH_TO_ABSOLUTE(${var_name})
endmacro()

# Check that an optional variable is set, or, set it to a default value.
macro(CHECK_OPTIONAL_VARIABLE var_name default_value)
    if(NOT DEFINED ${var_name})
        set(${var_name} ${default_value})
    endif()
    PATH_TO_ABSOLUTE(${var_name})
endmacro()

CHECK_REQUIRED_VARIABLE(PRE_CONFIGURE_FILE)
CHECK_REQUIRED_VARIABLE(POST_CONFIGURE_FILE)
CHECK_OPTIONAL_VARIABLE(GIT_STATE_FILE "${CMAKE_BINARY_DIR}/git-state-hash")
CHECK_OPTIONAL_VARIABLE(GIT_WORKING_DIR "${CMAKE_SOURCE_DIR}")

# Check the optional git variable.
# If it's not set, we'll try to find it using the CMake packaging system.
if(NOT DEFINED GIT_EXECUTABLE)
    find_package(Git QUIET REQUIRED)
endif()
CHECK_REQUIRED_VARIABLE(GIT_EXECUTABLE)

set(_state_variable_names
    # Full semantic version (or empty):
    GIT_TAG_VERSION_FULL
    # Full semantic version + "extra" (but not deb revision) (or empty):
    GIT_TAG_VERSION_FULL_EXTRA
    # Major version number (or -1):
    GIT_TAG_VERSION_MAJOR
    # Minor version number (or -1):
    GIT_TAG_VERSION_MINOR
    # Patch version number (or -1):
    GIT_TAG_VERSION_PATCH
    # Any extra text between version and deb release number (or empty):
    GIT_TAG_VERSION_EXTRA
    # deb release number (or -1):
    GIT_TAG_VERSION_REVISION
    # Number of commits since last tag (or -1):
    GIT_TAG_VERSION_COMMITS
    # Commit SHA (if not a tag, otherwise empty):
    GIT_TAG_VERSION_SHA
    # Whether the working tree is dirty (0 or 1):
    GIT_TAG_VERSION_DIRTY
    # If a clean tag, full semantic version, otherwise commit SHA:
    GIT_TAG_VERSION_ANY
)

# Function: GetGitState
# Description: gets the current state of the git repo.
# Args:
#   _working_dir (in)  string; the directory from which git commands will be executed.
function(GetGitState _working_dir)
    # CMake has a seriously limited regex implementation, so use a small
    # Perl script to parse the output of "git describe --always --dirty":
    execute_process(
        COMMAND "${CMAKE_CURRENT_LIST_DIR}/parse_tag_version.pl"
        WORKING_DIRECTORY "${_working_dir}"
        OUTPUT_VARIABLE output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    # CMake also lacks an elegant way to split a line of key=value pairs into
    # values, so this is the best way transform the command's output into the
    # corresponding values for now:
    string(REPLACE "\n" ";" lines ${output})
    foreach(line IN LISTS lines)
        string(REGEX MATCH "^[^=]+" key ${line})
        string(REPLACE "${key}=" "" value ${line})
        set(ENV{${key}} "${value}")
    endforeach()
endfunction()

# Function: SetupGitMonitoring
# Description: this function sets up custom commands that make the build system
#              check the state of git before every build. If the state has
#              changed, then a file is configured.
function(SetupGitMonitoring)
    add_custom_target(check_git
        ALL
        DEPENDS ${PRE_CONFIGURE_FILE}
        BYPRODUCTS ${POST_CONFIGURE_FILE}
        COMMENT "Checking the git repository for changes"
        COMMAND
            ${CMAKE_COMMAND}
            -D_BUILD_TIME_CHECK_GIT=TRUE
            -DGIT_WORKING_DIR=${GIT_WORKING_DIR}
            -DGIT_EXECUTABLE=${GIT_EXECUTABLE}
            -DGIT_STATE_FILE=${GIT_STATE_FILE}
            -DPRE_CONFIGURE_FILE=${PRE_CONFIGURE_FILE}
            -DPOST_CONFIGURE_FILE=${POST_CONFIGURE_FILE}
            -P "${CMAKE_CURRENT_LIST_FILE}")
endfunction()

# Function: Main
# Description: primary entry-point to the script. Functions are selected based
#              on whether it's configure or build time.
function(Main)
    if(_BUILD_TIME_CHECK_GIT)
        GetGitState("${GIT_WORKING_DIR}")
        foreach(var_name ${_state_variable_names})
            set(${var_name} $ENV{${var_name}})
        endforeach()
        configure_file("${PRE_CONFIGURE_FILE}" "${POST_CONFIGURE_FILE}" @ONLY)
    else()
        # >> Executes at configure time.
        SetupGitMonitoring()
    endif()
endfunction()

Main()
