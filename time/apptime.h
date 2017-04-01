//////////////////////////////////////////////////////////
// apptime.h
// Author: Andre Lo and Vipin Bakshi
// Purpose: An abstracted time module to provide timing.
/////////////////////////////////////////////////////////\

#ifndef _APPTIME_H_
#define _APPTIME_H_

#include <stdbool.h>
#include <stdint.h>

enum APPTIME_UNIT
{
    APPTIME_UNIT_NS,
    APPTIME_UNIT_US,
    APPTIME_UNIT_MS,
    APPTIME_UNIT_S,
    APPTIME_UNITS  
};

/**
 *  param: uint64_t* session_time
 *         Denotes the start time.
 *  returns: none
 **/
void apptime_start_session(uint64_t* start_time);

/**
 *  param: uint64_t* session_time
 *         Denotes the time that was spent in the session.
 *  returns: uint64_t
 *           the time spent in the session.               
 **/
uint64_t apptime_stop_session(uint64_t* start_time);

/**
 *  param: none
 *  returns: none
 **/
void apptime_print_res();
#endif
