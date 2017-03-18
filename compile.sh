#!/bin/bash
#To compile, just execute "compile.sh <filename without .cu extension>
nvcc $1.cu -o $1 -arch sm_52
