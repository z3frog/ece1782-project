// Imported from https://rosettacode.org/wiki/Example:Hough_transform/C
// It will be used as a baseline to observe transformation
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
 
#include "cairo.h"
 
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
uint8_t *houghtransform(uint8_t *d, int *w, int *h, int *s, int bpp)
{
    int rho, theta, y, x, W = *w, H = *h;
    int th = sqrt(W*W + H*H)/2.0;
    int tw = 360;
    uint8_t *ht = (uint8_t *)malloc(th*tw*4);
    memset(ht, 0, 4*th*tw); // black bg


    for(rho = 0; rho < th; rho++)
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
 
    *h = th;   // sqrt(W*W+H*H)/2
    *w = tw;   // 360
    *s = 4*tw;
    return ht;
}
 
int main(int argc, char **argv)
{
    cairo_surface_t *inputimg = NULL;
    cairo_surface_t *houghimg = NULL;

    uint8_t *houghdata = NULL, *inputdata = NULL;
    int w, h, s, bpp, format;

#if (CAIRO_HAS_PNG_FUNCTIONS==1)
    printf("cairo supports PNG\n");
#else
    printf("cairo does not support PNG\n");
#endif

    if ( argc < 3 ) return EXIT_FAILURE;

    printf("input file: %s\n", argv[1]);
    printf("output file: %s\n", argv[2]);

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
    houghdata = houghtransform(inputdata, &w, &h, &s, bpp);

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
