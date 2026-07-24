//  MeCab -- Yet Another Part-of-Speech and Morphological Analyzer
//
//
//  Copyright(C) 2001-2006 Taku Kudo <taku@chasen.org>
//  Copyright(C) 2004-2006 Nippon Telegraph and Telephone Corporation
#ifndef MECAB_THREAD_H
#define MECAB_THREAD_H
#ifdef __cplusplus
#include "config.h"

namespace MeCab {

class thread {
 private:

 public:
  static void* wrapper(void *ptr) {
    thread *p = static_cast<thread *>(ptr);
    p->run();
    return 0;
  }

  virtual void run() {}

  void start() {
  }

  void join() {
  }

  virtual ~thread() {}
};
}
#endif
#endif
