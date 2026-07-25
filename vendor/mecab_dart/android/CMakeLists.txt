cmake_minimum_required(VERSION 3.4.1)  # for example

# Vendored for shiroikumanojisho (toolchain migration): the bundled
# MeCab sources are C++98-era. NDK 28 defaults to C++17, where the
# `register` storage class and std::unary/binary_function are gone --
# pin C++14 (and silence the register warning) for this module only.
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_compile_options(-Wno-register -Wno-deprecated-declarations)

add_library( mecab_dart

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             ../ios/Classes/char_property.cpp 
             ../ios/Classes/eval.cpp
             ../ios/Classes/nbest_generator.cpp
             ../ios/Classes/tokenizer.cpp
             ../ios/Classes/connector.cpp
             ../ios/Classes/iconv_utils.cpp
             ../ios/Classes/param.cpp
             ../ios/Classes/utils.cpp
             ../ios/Classes/context_id.cpp
             ../ios/Classes/libmecab.cpp
             ../ios/Classes/string_buffer.cpp
             ../ios/Classes/viterbi.cpp
             ../ios/Classes/dictionary.cpp
             ../ios/Classes/dart_ffi.cpp
             ../ios/Classes/tagger.cpp
             ../ios/Classes/writer.cpp
             )
