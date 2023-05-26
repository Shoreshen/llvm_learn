#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "alg5.h"
#define HALF_W ALG5_WIDTH / 2
#define HALF_H ALG5_HEIGHT / 2
unsigned short(*c1) [HALF_W];
unsigned short(*c2)[HALF_W];
unsigned short(*c3)[HALF_W];
unsigned short(*c4) [HALF_W];

void alg5_func(unsigned short d1[ALG5_HEIGHT][ALG5_WIDTH], unsigned short d2[ALG5_HEIGHT][ALG5_WIDTH][3])
 {
	// unsigned short(*c1) [HALF_W];
	// unsigned short(*c2)[HALF_W];
	// unsigned short(*c3)[HALF_W];
	// unsigned short(*c4) [HALF_W];
	c1 = (unsigned short(*)[HALF_W])malloc(HALF_H * sizeof(unsigned short[HALF_W]));
	c2 = (unsigned short(*)[HALF_W])malloc(HALF_H * sizeof(unsigned short[HALF_W]));
	c3 = (unsigned short(*)[HALF_W])malloc(HALF_H * sizeof(unsigned short[HALF_W]));
	c4 = (unsigned short(*)[HALF_W])malloc(HALF_H * sizeof(unsigned short[HALF_W]));
    for (int i = 0; i < ALG5_HEIGHT * ALG5_WIDTH; i++) {
        int RowIdx = i / ALG5_WIDTH;
        int ColIdx = i % ALG5_WIDTH;
        int RowPos = RowIdx / 2;
        int ColPos = ColIdx / 2;
        if((RowIdx % 2 == 0) && (ColIdx % 2 == 0)) {
            *(*(c1+RowPos)+ColPos) = d1[RowIdx][ColIdx];
        }
        else if ((RowIdx % 2 == 0) && (ColIdx % 2 == 1)) {
            * (*(c2 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
        }
        else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 0)) {
            *(*(c3 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
        }
        else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 1)) {
            *(*(c4 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
        }
    }
    // for (int i = 0; i < ALG5_HEIGHT * ALG5_WIDTH; i++) {
    //     int RowIdx = i / ALG5_WIDTH;
    //     int ColIdx = i % ALG5_WIDTH;
    //     int RowPos = RowIdx / 2;
    //     int ColPos = ColIdx / 2;
    //     if((RowIdx % 2 == 0) && (ColIdx % 2 == 0)) {
    //         d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][1] = (*(*(c2 + RowPos) + ColPos) + *(*(c3 + RowPos) + ColPos)) / 2;
    //         d2[RowIdx][ColIdx][2] = *(*(c4 + RowPos) + ColPos);
    //     }
    //     else if ((RowIdx % 2 == 0) && (ColIdx % 2 == 1)) {
    //         d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][1] = *(*(c2 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][2] = *(*(c3 + RowPos) + ColPos);
    //     }
    //     else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 0)) {
    //         d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][1] = *(*(c2 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][2] = *(*(c3 + RowPos) + ColPos);
    //     }
    //     else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 1)) {
    //         d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
    //         d2[RowIdx][ColIdx][1] = (*(*(c2 + RowPos) + ColPos) + *(*(c3 + RowPos) + ColPos)) / 2;
    //         d2[RowIdx][ColIdx][2] = *(*(c4 + RowPos) + ColPos);
    //     }
    // }

/*  original code 
    for(int RowIdx=0; RowIdx<ALG5_HEIGHT; RowIdx++) {
        for(int ColIdx=0; ColIdx<ALG5_WIDTH; ColIdx++) {
            int RowPos = RowIdx / 2;
            int ColPos = ColIdx / 2;
            if((RowIdx % 2 == 0) && (ColIdx % 2 == 0)) {
                *(*(c1+RowPos)+ColPos) = d1[RowIdx][ColIdx];
            }
            else if ((RowIdx % 2 == 0) && (ColIdx % 2 == 1)) {
                * (*(c2 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
            }
            else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 0)) {
				*(*(c3 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
            }
            else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 1)) {
				*(*(c4 + RowPos) + ColPos) = d1[RowIdx][ColIdx];
            }
        }
    }
    for(int RowIdx=0; RowIdx<ALG5_HEIGHT; RowIdx++) {
        for(int ColIdx=0; ColIdx<ALG5_WIDTH; ColIdx++) {
            int RowPos = RowIdx / 2;
            int ColPos = ColIdx / 2;
            if((RowIdx % 2 == 0) && (ColIdx % 2 == 0)) {
                d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
                d2[RowIdx][ColIdx][1] = (*(*(c2 + RowPos) + ColPos) + *(*(c3 + RowPos) + ColPos)) / 2;
                d2[RowIdx][ColIdx][2] = *(*(c4 + RowPos) + ColPos);
            }
            else if ((RowIdx % 2 == 0) && (ColIdx % 2 == 1)) {
                d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
                d2[RowIdx][ColIdx][1] = *(*(c2 + RowPos) + ColPos);
                d2[RowIdx][ColIdx][2] = *(*(c3 + RowPos) + ColPos);
            }
            else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 0)) {
                d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
				d2[RowIdx][ColIdx][1] = *(*(c2 + RowPos) + ColPos);
				d2[RowIdx][ColIdx][2] = *(*(c3 + RowPos) + ColPos);
            }
            else if ((RowIdx % 2 == 1) && (ColIdx % 2 == 1)) {
                d2[RowIdx][ColIdx][0] = *(*(c1 + RowPos) + ColPos);
				d2[RowIdx][ColIdx][1] = (*(*(c2 + RowPos) + ColPos) + *(*(c3 + RowPos) + ColPos)) / 2;
				d2[RowIdx][ColIdx][2] = *(*(c4 + RowPos) + ColPos);
            }
        }
    }
*/
}