// Imported from https://rosettacode.org/wiki/Example:Hough_transform/C
// It will be used as a baseline to observe transformation
// Modified and Parallelized by Vipin Bakshi and Andre Lo.

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
 
#include "cairo.h"
#include "apptime.h"
 
#ifndef M_PI
#define M_PI 3.1415927
#endif
 
#define GR(X,Y) (d[(*s)*(Y)+bpp*(X)+((2)%bpp)])
#define GG(X,Y) (d[(*s)*(Y)+bpp*(X)+((1)%bpp)])
#define GB(X,Y) (d[(*s)*(Y)+bpp*(X)+((0)%bpp)])
#define SR(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+2])
#define SG(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+1])
#define SB(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+0])
#define RAD(A)  (M_PI*((double)(A))/180.0)

#define PTHREAD_MAX_THREADS        8

struct computationblock_limits
{
  int rho_start;
  int rho_end;
  int tid;
};

// PTHREAD SUPPORT
static pthread_t threads[PTHREAD_MAX_THREADS];
pthread_attr_t attr;

// Global support.
static int  W, H, th, tw;
static uint8_t* ht;
static uint8_t* d;
static int* s;
static int bpp;

static struct computationblock_limits cl[PTHREAD_MAX_THREADS];

// The worker thread.
void * computationblock(void* data);


uint8_t *houghtransform(uint8_t *dd, int *w, int *h, int *ss, int bbpp)
{
    int ii;
    W = *w, H = *h;
    th = sqrt(W*W + H*H)/2.0;
    tw = 360;
    ht = (uint8_t *)malloc(th*tw*4);
    memset(ht, 0, 4*th*tw); // black bg
    memset(&cl, 0, sizeof(cl));
    d = dd;
    s = ss;
    bpp = bbpp;
    
    // Create pthread attribute with JOINABLE property.
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

    // Disptach threads for work.
    for (ii = 0; ii < PTHREAD_MAX_THREADS; ii++)
    {
      int rc;

      // Load structure with points info to send to thread.
      cl[ii].rho_start = (th / PTHREAD_MAX_THREADS) * ii;
      cl[ii].tid = ii;

      // Check if this is the last thread to be dispatched 
      //	and we have a residue of points to be computed.
      //	If it is true, add the residue points as load to the last thread.
      if ((ii == PTHREAD_MAX_THREADS - 1) &&
          (th % PTHREAD_MAX_THREADS))
      {
	// Last thread to dispatch. Add remaining points to compute to this thread.
	cl[ii].rho_end = (th / PTHREAD_MAX_THREADS)
	                   + cl[ii].rho_start
	                   + (th % PTHREAD_MAX_THREADS);
      }
      else
      {
	// Not the last thread or (last thread but no residue in the number of points to be computed.
	cl[ii].rho_end = (th / PTHREAD_MAX_THREADS)
	  + cl[ii].rho_start;
      }

      rc = pthread_create(&threads[ii], &attr, computationblock, (void *) &cl[ii]);
      if (rc)
      {
	// Error creating threads.
	printf("ERROR! Return code from pthread_create() is %d\n", rc);
	exit(-1);
       }
    }

    // BARRIER for Computation.
    ii = 0;
    for (ii = 0; ii < PTHREAD_MAX_THREADS; ii++)
    {
      int rc;
      void* status;

      rc = pthread_join(threads[ii], &status);
      if (rc)
      {
	printf("ERROR! Return code from pthread_join() is %d\n.", rc);
	exit(-1);
      }
    }
	
    *h = th;   // sqrt(W*W+H*H)/2
    *w = tw;   // 360
    *s = 4*tw;

    pthread_attr_destroy(&attr);

    return ht;
}

void * computationblock(void* data)
{
   uint64_t thread_time;
   int rho, theta, y, x;
   struct computationblock_limits * cl  = (struct computationblock_limits*)(data);

   apptime_start_session(&thread_time);
   for(rho = cl->rho_start; rho < cl->rho_end; rho++)
   {
     for(theta = 0; theta < tw/*720*/; theta++)
       {
	 double C = cos(RAD(theta));
	 double S = sin(RAD(theta));
	 uint32_t totalred = 0;
	 uint32_t totalgreen = 0;
	 uint32_t totalblue = 0;
	 uint32_t totalpix = 0;
	 if ( theta < 45 || (theta > 135 && theta < 225) || theta > 315) {
	   for(y = 0; y < H; y++) {
	     double dx = W/2.0 + (rho - (H/2.0-y)*S)/C;
	     if ( dx < 0 || dx >= W ) continue;
	     x = floor(dx+.5);
	     if (x == W) continue;
	     totalpix++;
	     totalred += GR(x, y);
	     totalgreen += GG(x, y);
	     totalblue += GB(x, y);
	   }
	 } else {
	   for(x = 0; x < W; x++) {
	     double dy = H/2.0 - (rho - (x - W/2.0)*C)/S;
	     if ( dy < 0 || dy >= H ) continue;
	     y = floor(dy+.5);
	     if (y == H) continue;
	     totalpix++;
	     totalred += GR(x, y);
	     totalgreen += GG(x, y);
	     totalblue += GB(x, y);      
	   }
	 }
	 if ( totalpix > 0 ) {
	   double dp = totalpix;
	   SR(theta, rho) = (int)(totalred/dp)   &0xff;
	   SG(theta, rho) = (int)(totalgreen/dp) &0xff;
	   SB(theta, rho) = (int)(totalblue/dp)  &0xff;
	 }
       }
    }
    
    thread_time = apptime_stop_session(&thread_time);
    printf("Thread %d exited. Time: %lld nm\n", cl->tid, thread_time);

    pthread_exit((void*) &cl->tid);
}
 
int main(int argc, char **argv)
{
    cairo_surface_t *inputimg = NULL;
    cairo_surface_t *houghimg = NULL;

    uint8_t *houghdata = NULL, *inputdata = NULL;
    int w, h, s, bpp, format;
    uint64_t measurement_time = 0;
    

#if (CAIRO_HAS_PNG_FUNCTIONS==1)
    printf("cairo supports PNG\n");
#else
    printf("cairo does not support PNG\n");
#endif

    if ( argc < 3 ) return EXIT_FAILURE;

    printf("input file: %s\n", argv[1]);
    printf("output file: %s\n", argv[2]);

    apptime_print_res();

    // Lets measure initialization time.
    apptime_start_session(&measurement_time);
    printf("Initialization...\n");
    inputimg = cairo_image_surface_create_from_png(argv[1]);

    printf("After create from png: %s\n",
        cairo_status_to_string(cairo_surface_status(inputimg)));

    w = cairo_image_surface_get_width(inputimg);
    h = cairo_image_surface_get_height(inputimg);
    s = cairo_image_surface_get_stride(inputimg);  
    format = cairo_image_surface_get_format(inputimg);
    switch(format)
    {
        case CAIRO_FORMAT_ARGB32: bpp = 4; break;
        case CAIRO_FORMAT_RGB24:  bpp = 3; break;
        case CAIRO_FORMAT_A8:     bpp = 1; break;
        default:
            fprintf(stderr, "unsupported %i\n", format);
            goto destroy;
    }

    inputdata = cairo_image_surface_get_data(inputimg);
    measurement_time = apptime_stop_session(&measurement_time);
    printf("Initialization Completed. Time: %lld ns\n", measurement_time);

    // Now lets measure the Hough Time.
    printf("Hough Transform started...\n");
    apptime_start_session(&measurement_time);
    
    houghdata = houghtransform(inputdata, &w, &h, &s, bpp);
    
    measurement_time = apptime_stop_session(&measurement_time);
    printf("Hought transform completed. Time:  %llu ns\n", measurement_time);
    
    printf("w=%d, h=%d\n", w, h);
    houghimg = cairo_image_surface_create_for_data(houghdata,
                        CAIRO_FORMAT_RGB24,
                        w, h, s);
    cairo_surface_write_to_png(houghimg, argv[2]);
 
destroy:
    if (inputimg != NULL) cairo_surface_destroy(inputimg);
    if (houghimg != NULL) cairo_surface_destroy(houghimg);
    pthread_exit(NULL);
    
    return EXIT_SUCCESS;
}
