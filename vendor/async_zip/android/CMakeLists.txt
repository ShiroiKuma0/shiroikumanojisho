cmake_minimum_required(VERSION 3.4.1)

add_library(
    async_zip

    # Sets the library as a shared library.
    SHARED

    # Provides a relative path to your source file(s).
    ../ios/Classes/zip.c)

#find_library(
#    log-lib
#    log
#)
#
#target_link_libraries(
#    async_zip
#    ${log-lib}
#)