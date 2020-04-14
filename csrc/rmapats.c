// file = 0; split type = patterns; threshold = 100000; total count = 0.
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "rmapats.h"

void  hsG_0__0 (struct dummyq_struct * I1253, EBLK  * I1247, U  I675);
void  hsG_0__0 (struct dummyq_struct * I1253, EBLK  * I1247, U  I675)
{
    U  I1506;
    U  I1507;
    U  I1508;
    struct futq * I1509;
    struct dummyq_struct * pQ = I1253;
    I1506 = ((U )vcs_clocks) + I675;
    I1508 = I1506 & ((1 << fHashTableSize) - 1);
    I1247->I716 = (EBLK  *)(-1);
    I1247->I720 = I1506;
    if (I1506 < (U )vcs_clocks) {
        I1507 = ((U  *)&vcs_clocks)[1];
        sched_millenium(pQ, I1247, I1507 + 1, I1506);
    }
    else if ((peblkFutQ1Head != ((void *)0)) && (I675 == 1)) {
        I1247->I722 = (struct eblk *)peblkFutQ1Tail;
        peblkFutQ1Tail->I716 = I1247;
        peblkFutQ1Tail = I1247;
    }
    else if ((I1509 = pQ->I1153[I1508].I734)) {
        I1247->I722 = (struct eblk *)I1509->I733;
        I1509->I733->I716 = (RP )I1247;
        I1509->I733 = (RmaEblk  *)I1247;
    }
    else {
        sched_hsopt(pQ, I1247, I1506);
    }
}
void  hs_0_M_52_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_52_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            (*(FPLSELV  *)((pcode + 32) + 8U))(*(UB  **)(pcode + 48), (vec32  *)I1560, *(U  *)(pcode + 32), *(U  *)(pcode + 56));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 64) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
void  hs_0_M_53_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_53_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 32) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
void  hs_0_M_90_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_90_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            (*(FPLSELV  *)((pcode + 32) + 8U))(*(UB  **)(pcode + 48), (vec32  *)I1560, *(U  *)(pcode + 32), *(U  *)(pcode + 56));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 64) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
void  hs_0_M_91_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_91_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 32) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
void  hs_0_M_107_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_107_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            (*(FPLSELV  *)((pcode + 32) + 8U))(*(UB  **)(pcode + 48), (vec32  *)I1560, *(U  *)(pcode + 32), *(U  *)(pcode + 56));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 64) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
void  hs_0_M_108_0__simv_daidir (UB  * pcode, vec32  * I987, U  I900)
{
    UB  * I1570;
    typedef
    UB
     * TermTypePtr;
    U  I1338;
    U  I1294;
    TermTypePtr  I1297;
    U  I1336;
    vec32  * I1330;
    I1297 = (TermTypePtr )pcode;
    I1338 = *I1297;
    I1297 -= I1338;
    I1294 = 2U;
    pcode = (UB  *)(I1297 + I1294);
    pcode = (UB  *)(((UP )(pcode + 0) + 3U) & ~3LU);
    I1336 = (1 + (((I900) - 1) / 32));
    I1330 = (vec32  *)(pcode + 0);
    {
        U  I1266;
        vec32  * I1299 = I1330 + I1338 * I1336;
        I1266 = 0;
        for (; I1266 < I1336; I1266++) {
            if (I987[I1266].I1 != I1299[I1266].I1 || I987[I1266].I2 != I1299[I1266].I2) {
                break ;
            }
        }
        if (I1266 == I1336) {
            return  ;
        }
        for (; I1266 < I1336; I1266++) {
            I1299[I1266].I1 = I987[I1266].I1;
            I1299[I1266].I2 = I987[I1266].I2;
        }
    }
    I987 = (vec32  *)(I1330 + I1294 * I1336);
    rmaEvalWandW(I987, I1330, I900, I1294);
    pcode += ((I1294 + 1) * I1336 * sizeof(vec32 ));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    {
        EBLK  * I1247;
        struct dummyq_struct * pQ;
        U  I1249;
        I1249 = 0;
        pQ = (struct dummyq_struct *)&vcs_clocks;
        {
            RmaEblk  * I1247 = (RmaEblk  *)(pcode + 8);
            vec32  * I1524 = (vec32  *)((pcode + 48));
            if (rmaChangeCheckAndUpdateW(I1524, I987, I900)) {
                if (!(I1247->I716)) {
                    pQ->I1147->I716 = (EBLK  *)I1247;
                    pQ->I1147 = (EBLK  *)I1247;
                    I1247->I716 = (RP )((EBLK  *)-1);
                }
            }
        }
    }
}
void  hs_0_M_108_9__simv_daidir (UB  * pcode, vec32  * I987)
{
    U  I900;
    I900 = *(U  *)((pcode + 0) - sizeof(RP ));
    I987 = (vec32  *)(pcode + 40);
    pcode = ((UB  *)I987) + sizeof(vec32 ) * (1 + (((I900) - 1) / 32));
    pcode = (UB  *)(((UP )(pcode + 0) + 7U) & ~7LU);
    I900 = *(U  *)((pcode + 0));
    U  I1365;
    vec32  * I1341 = 0;
    {
        U  I1336 = (1 + (((I900) - 1) / 32));
        pcode += 4;
        pcode = (UB  *)((((RP )pcode + 0) + 3) & (~3));
        I1341 = (vec32  *)((pcode + 0));
        pcode += (I1336 * sizeof(vec32 ));
        rmaUpdateW(I1341, I987, I900);
    }
    {
        pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
        ((void)0);
        {
            RP  * I710 = (RP  *)(pcode + 0);
            RP  I1435;
            I1435 = *I710;
            if (I1435) {
                U  I1436 = I900;
                hsimDispatchCbkMemOptNoDynElabVector(I710, I987, 2, I1436);
            }
        }
    }
    {
        RmaRootForceCbkCg  * I1421;
    }
    {
        void * I1560 = I987;
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        {
            (*(FPLSELV  *)((pcode + 0) + 8U))(*(UB  **)(pcode + 16), (vec32  *)I1560, *(U  *)(pcode + 0), *(U  *)(pcode + 24));
            I1560 = (void *)I987;
        }
    }
    {
        U  I1266;
        U  I1286;
        U  I1272;
        U  I864;
        RmaIbfPcode  * I1010;
        pcode = (UB  *)((((RP )pcode + 32) + 7) & (~7));
        I1286 = *(U  *)(pcode + 4);
        I1272 = *(U  *)(pcode + 8);
        I864 = *(U  *)(pcode + 12);
        pcode = (UB  *)((((RP )pcode + 16) + 7) & (~7));
        I1010 = (RmaIbfPcode  *)(pcode + 0);
        for (; I864 > 0; I864--) {
            U  I1290 = I1272 >> 5;
            U  I907 = I1272 % 32;
            vec32  * I766 = ((vec32  *)I987) + I1290;
            U  I1 = (I766->I1 >> I907) & 0x1;
            U  I2 = (I766->I2 >> I907) & 0x1;
            scalar  I788 = (I1 << 1) + I2;
            RP  I1110 = 0;
            I1110 = (RP )I1010->I986;
            ((void (*)(RP   , U   ))(I1110))(I1010->pcode, I788);
            I1272 += 1 + I1286;
            I1010++;
        }
        pcode = (UB  *)I1010;
    }
    pcode = (UB  *)((((RP )pcode + 0) + 7) & (~7));
    ((FPV )(((RmaIbfIp  *)(pcode + 0))->I986))((void *)((RmaIbfIp  *)(pcode + 0))->I718, (UB  *)I987);
}
#ifdef __cplusplus
extern "C" {
#endif
void SinitHsimPats(void);
#ifdef __cplusplus
}
#endif
