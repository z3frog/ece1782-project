//////////////////////////////////////////////////////////
// apptime.c
// Author: Andre Lo and Vipin Bakshi
// Purpose: An abstracted time module to provide timing.
/////////////////////////////////////////////////////////
#include <time.h>
#include <stdio.h>
#include <string.h>
#include "apptime.h"


//Prototypes
static uint64_t apptime_get_time(void);


void apptime_start_session(uint64_t * session_time)
{
    *session_time = apptime_get_time();
}

uint64_t apptime_stop_session(uint64_t * session_time)
{
   return apptime_get_time() - *session_time;
}

void apptime_print_res(void)
{
    struct timespec ts;
    clock_getres(CLOCK_MONOTONIC, &ts);
    printf("Timer resolution is: %llu s and %llu ns\n", ts.tv_sec, ts.tv_nsec);
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
