// Imported from https://rosettacode.org/wiki/Example:Hough_transform/C
// It will be used as a baseline to observe transformation
// Modified and Parallelized with CUDA by Vipin Bakshi and Andre Lo.

// GPU v?
// DETAILS: can take an extra param: ./<bin name> <input file> <output file> <grid size>
// if grid size is not entered, default is 12, which is default for v1

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

// These are macros to access the R, G and B values
// of the input  (d) data/ output data (ht) image buffers
#define GR(X,Y) (d[(stride)*(Y)+bpp*(X)+((2)%bpp)])
#define GG(X,Y) (d[(stride)*(Y)+bpp*(X)+((1)%bpp)])
#define GB(X,Y) (d[(stride)*(Y)+bpp*(X)+((0)%bpp)])
#define SR(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+2])
#define SG(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+1])
#define SB(X,Y) (ht[4*tw*((Y)%th)+4*((X)%tw)+0])
#define RAD(A)  (M_PI*((double)(A))/180.0)
#define tw       360

// Kernel
// todo: experiment with 3D instead of 1D grid?
static int grid;
__global__ void computationalkernel(uint8_t *d, uint8_t *ht, int W, int H, int stride, int bpp, int th)
{
    int rho, y, x;
    int theta = threadIdx.x + blockIdx.x * blockDim.x; // theta is based on grid/ block id

    for(rho = 0; rho < th; rho++)
    {
        double C = cos(RAD(theta));  // todo: call sincos instead?
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


// d  is pointer to input data
// w, h, s is input data's width, height, and stridge
// bpp is bits per pixel of input data
uint8_t *houghtransform(uint8_t *h_in, int *w, int *h, int *s, int bpp)
{
    // Error code to check return values for CUDA calls
    cudaError_t err = cudaSuccess;
    uint64_t measurement_time = 0;

    int W = *w, H = *h;
    int th = sqrt(W*W + H*H)/2.0;
    int outputBytes= th*tw*4;

    // alloc space for output buffer CPU side
    uint8_t *h_ht = (uint8_t *)malloc(outputBytes);

    apptime_start_session(&measurement_time);
    
    // alloc space for output buffer device side
    uint8_t *d_out;
    err = cudaMalloc((void **)&d_out, outputBytes);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate %d bytes for  d_out (error code %s)!\n", outputBytes, cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaMemset((void *)d_out, 0, outputBytes); // black bg
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to cudaMemset d_out (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    printf("allocated output buffers\n");
    
    // alloc space and init input buffer device side
    uint8_t *d_in;
    err = cudaMalloc((void **)&d_in, (*s * *h)); // bytes = stride * height
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device d_in (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    err = cudaMemcpy(d_in, h_in, (*s * *h), cudaMemcpyHostToDevice);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy d_in from host to device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    printf("allocated input buffers\n");
    measurement_time = apptime_stop_session(&measurement_time);
    printf("Allocations/ copy to device completed. Time:  %llu ns\n", measurement_time);

    apptime_start_session(&measurement_time);
    // todo: play with grid, block dimensions
    // right now this spawns 360 total kernels, for 360 values of theta
    computationalkernel <<<grid, (360/ grid)>>> (d_in, d_out, W, H, *s, bpp, th);

    cudaThreadSynchronize(); // wait for all GPU threads to complete
    printf("cudaThreadSynchronize done\n");

    measurement_time = apptime_stop_session(&measurement_time);
    printf("CUDA computations completed. Time:  %llu ns\n", measurement_time);


    apptime_start_session(&measurement_time);    
    // Copy resulting output from device
    cudaMemcpy(h_ht, d_out, outputBytes, cudaMemcpyDeviceToHost);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy d_out from host to device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    
    printf("copy result back to host done\n");

    // Clean up
    err = cudaFree(d_in);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free d_in (error code %s)!\n", cudaGetErrorString(err));
    }

    err = cudaFree(d_out);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free d_out (error code %s)!\n", cudaGetErrorString(err));
    }
    
    measurement_time = apptime_stop_session(&measurement_time);
    printf("Copy back to host/ cleanup completed. Time:  %llu ns\n", measurement_time);
    
    // h, w, and s are returned as the height, width, stride of the output image
    // ht is the buffer containing the transformed output image
    *h = th;   // sqrt(W*W+H*H)/2
    *w = tw;   // 360
    *s = 4*tw; // 4 because 4 bytes per pixel output format
    return h_ht;
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

    //todo: take in argv[3] as grid size?
    grid = 12; // must be a factor of 360 (we calculate using theta for every degree of 360 degs)

    if (argc > 3)
    {
        grid = atoi(argv[3]);
    }
    printf("grid = %d\n", grid);
    
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

    printf("input buffer  width %d, height %d, stride %d, bpp %d\n",
        w, h, s, bpp);

    // Now lets measure the Hough Time.
    printf("Hough Transform using CUDA started...\n");
    //apptime_start_session(&measurement_time);

    houghdata = houghtransform(inputdata, &w, &h, &s, bpp);

    //measurement_time = apptime_stop_session(&measurement_time);
    //printf("Hought transform completed. Time:  %llu ns\n", measurement_time);

    printf("w=%d, h=%d\n", w, h);
    houghimg = cairo_image_surface_create_for_data(houghdata,
                        CAIRO_FORMAT_RGB24,
                        w, h, s);
    cairo_surface_write_to_png(houghimg, argv[2]);

destroy:
    if (inputimg != NULL) cairo_surface_destroy(inputimg);
    if (houghimg != NULL) cairo_surface_destroy(houghimg);

    return EXIT_SUCCESS;
}
