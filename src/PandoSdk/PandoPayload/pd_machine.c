#include <time.h>
#include <sys/time.h>
#include <stdint.h>

#include "pd_machine.h"

uint64_t FUNCTION_ATTRIBUTE pd_get_timestamp()
{
  struct timeval now;
  gettimeofday(&now, NULL);
  return (now.tv_sec * 1000 + now.tv_usec/1000);
}
