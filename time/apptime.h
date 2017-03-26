//////////////////////////////////////////////////////////
// apptime.h
// Author: Andre Lo and Vipin Bakshi
// Purpose: An abstracted time module to provide timing.
/////////////////////////////////////////////////////////\

#ifndef _APPTIME_H_
#define _APPTIME_H_

#include <float.h>
#include <stdbool.h>

enum APPTIME_UNIT
{
  APPTIME_UNIT_US,
  APPTIME_UNIT_MS,
  APPTIME_UNIT_S,
  APPTIME_UNITS  
};

/**
 *  param: none
 *  returns: true if new timing session was started.
 *           false if new timing session could not be stated.
 *                 usually if another timing session was not stopped.
 **/
bool apptime_start_session(void);

/**
 *  param: uint32_t* session_time
 *         Denotes the time that was spent in the session.
 *  returns: true if timing session was stopped
 *           false if timing session was not stopped
 *                 usually if a timing session was not in progress.
 **/
bool apptime_stop_session(double* session_time);

/**
 *  param: enum APPTIME_UNITS units
 *         Units for timestamps
 *  returns: true if units were updated.
 *           false if units were not updated.
 *        
 **/
void apptime_set_time_units(enum APPTIME_UNIT units);

#endif
