cmake_minimum_required(VERSION 3.4.1)  # for example

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
