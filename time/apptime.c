//////////////////////////////////////////////////////////
// apptime.h
// Author: Andre Lo and Vipin Bakshi
// Purpose: An abstracted time module to provide timing.
/////////////////////////////////////////////////////////\
#include <float.h>
#include <stdbool.h>
#include <time.h>

#include "apptime.h"

// Lazy initialization
static enum APPTIME_UNIT unit_ = APPTIME_UNIT_US;
static bool is_session_in_progress_ = false;
static double session_start_time = 0;

static double apptime_get_time(void);


bool apptime_start_session(void)
{
   if (is_session_in_progress_)
   {
       return false;
   }

   session_start_time = apptime_get_time();
   is_session_in_progress = true;
}

bool apptime_stop_session(double* session_time)
{
   if (!is_session_in_progress)
   {
      return false;
   }

   is_session_in_progress = false;
   *session_time = apptime_get_time() - session_start_time;

   switch (unit_)
   {
      case APPTIME_UNIT_MS:
        *session_time /= 1000;
         break;

      case APPTIME_UNIT_S:
         *session_time /= 1000000;
	 break;
	 
      default:
          break;
     }

   return true;
}

void apptime_set_time_units(enum APPTIME_UNIT units)
{
  if (units >= APPTIME_UNITS)
    return;

  unit_ = units;
}

/*
 * param: none
 * return: double var
 *         time in microsecond resolution
 */
static double apptime_get_time(void)
{
   // TODO: Do some error checking here.
   struct timeval tv;
   gettimeofday(&tv, NULL);
   return (double)(tv.tv_sec * 1000000) + (double)(tv.tv_usec);
}
