//////////////////////////////////////////////////////////
// apptime.c
// Author: Andre Lo and Vipin Bakshi
// Purpose: An abstracted time module to provide timing.
/////////////////////////////////////////////////////////
#include <time.h>
#include <stdio.h>
#include <string.h>
#include "apptime.h"

// Lazy initialization
static enum APPTIME_UNIT unit_ = APPTIME_UNIT_NS;
static bool is_session_in_progress_ = false;
static uint64_t  session_start_time = 0;


//Prototypes
static uint64_t apptime_get_time(void);


bool apptime_start_session(void)
{
   if (is_session_in_progress_)
   {
       return false;
   }

   session_start_time = apptime_get_time();
   is_session_in_progress_ = true;
   
   return true;
}

bool apptime_stop_session(uint64_t * session_time)
{
   if (!is_session_in_progress_)
   {
      return false;
   }

   is_session_in_progress_ = false;
   *session_time = apptime_get_time() - session_start_time;

   switch (unit_)
   {
      case APPTIME_UNIT_US:
         *session_time /= 1000;
        break;

      case APPTIME_UNIT_MS:
        *session_time /= 1000000;
         break;

      case APPTIME_UNIT_S:
         *session_time /= 1000000000;
        break;

      default:
          break;
     }

   return true;
}

void apptime_print_res(void)
{
    struct timespec ts;
    clock_getres(CLOCK_MONOTONIC, &ts);
    printf("Timer resolution is: %llu s and %llu ns\n", ts.tv_sec, ts.tv_nsec);
}

void apptime_set_time_units(enum APPTIME_UNIT units)
{
  if (units >= APPTIME_UNITS)
    return;

  unit_ = units;
}

/*
 * param: none
 * return: uint64_t var
 *         time in nanosecond resolution
 */
static uint64_t apptime_get_time(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ts.tv_sec * (uint64_t)1000000000) + ts.tv_nsec;
}
