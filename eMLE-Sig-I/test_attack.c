#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "api.h"

/* This is horrible but circumvents the fact that basic functions are
 * marked as static and unavailable in the headers.
 */
#include "impl.c"
#include "nist.c"

#define MLEN 16
#define NSAMPLES 2500000

void print_progress(size_t count, size_t max, double u[], double v[]) {
    const int bar_width = 50;

    double progress = (double) count / max;
    int bar_length = progress * bar_width;

    double dotp = 0., normu = 0., normv = 0., corr;
    int reccoeffs = 0;
    for(size_t j=0; j<n; j++) {
        normu += u[j] * u[j];
        normv += v[j] * v[j];
        dotp  += u[j] * v[j];
    }
    corr = dotp / sqrt(normu*normv);
    
    if(count > 0) {
        double factor = 1/((double) count);
        for(size_t j=0; j<n; j++)
            reccoeffs += (lround(v[j]*factor) == lround(u[j]));
    }

    printf("\rSigs: [");
    for (int i = 0; i < bar_width; ++i) {
        printf("%c", (i<bar_length)?'#':' ');
    }
    printf("] %.2f%% [%.3f; %d]", progress * 100, corr, reccoeffs);
    fflush(stdout);
}

int main(int argc, char** argv)
{
    int nsamples;
    unsigned long long smlen;
    uint8_t m[MLEN + CRYPTO_BYTES];
    uint8_t sm[MLEN + CRYPTO_BYTES];
    uint8_t pk[CRYPTO_PUBLICKEYBYTES];
    uint8_t sk[CRYPTO_SECRETKEYBYTES];
    uint8_t pkh[64];

    pubkey_t    pkey;
    privkey_t   skey;
    signature_t sig;

    crypto_sign_keypair(pk, sk);
    unpack_sk(&skey, sk);
    unpack_pk(&pkey, pk);
    gen_pkh(pkh, &pkey, n);

    double sacc[N_MAX], x1z[N_MAX], x1zrec[N_MAX]; 
    for(size_t j=0; j<n; j++) {
        sacc[j] = 0.;
        x1z[j]  = skey.x1[j] - skey.x1[(j+1)%n];
    }

    if(argc > 1)
        nsamples = atoi(argv[1]);
    else
        nsamples = NSAMPLES;

    printf("Attack on %s with %d samples...\n\n",
            CRYPTO_ALGNAME, nsamples);
    for (int i=0; i < nsamples; i++) {
        randombytes(m, MLEN);

        crypto_sign(sm, &smlen, m, MLEN, sk);
        unpack_sig(&sig, sm);

        int64_t c1[N_MAX], c2[N_MAX];
        hashVec(c1, c2, m, MLEN, sig.u, pkh, n);

        double r = 1/((double)c1[0] - 1.5);
        for(size_t j=0; j<n; j++) {
            sacc[j] += r*sig.s[j];
        }
        if((i+1)%100==0) {
            for(size_t j=0; j<n; j++) {
                x1zrec[j] = sacc[j] - sacc[(j+1)%n];
            }
            print_progress(i+1, nsamples, x1z, x1zrec);
        }
    }

    printf("\n\nx1z    = [");
    for(size_t j=0; j<n; j++)
        printf("%ld%s", lround(x1z[j]), (j==n-1)?"]\n":", ");
    printf("x1zrec = [");
    for(size_t j=0; j<n; j++)
        printf("%ld%s", lround(x1zrec[j]/nsamples), (j==n-1)?"]\n":", ");
    printf("delta  = [");
    for(size_t j=0; j<n; j++)
        printf("%ld%s", lround(x1z[j]) - lround(x1zrec[j]/nsamples), (j==n-1)?"]\n":", ");
    /*
    print_progress(nsamples, nsamples, x1z, x1zrec);
    printf("\n\n");

    for(j=0; j<N; j++)
        Grec[j] /= (double)nsamples;

    double dotp = 0., normG = 0., normGrec = 0., factor;
    int reccoeffs = 0;
    for(j=0; j<N; j++) {
        normGrec += Grec[j] * Grec[j];
        normG    += G[0].vec[0].coeffs[j] * G[0].vec[0].coeffs[j];
        dotp     += Grec[j] * G[0].vec[0].coeffs[j];
    }

    factor = sqrt(2.*N/normGrec/3.);
    for(int j=0; j<N; j++) {
        Grec[j] *= factor;
        reccoeffs += (lround(Grec[j]) == G[0].vec[0].coeffs[j]);
    }
    
    printf("Out of %d total signatures, %d had c[0]==1 or c[0]==-1 (%.2f%%).\n",
            nsamples, select, 100.*((double)select) / ((double)nsamples));
    printf("Correlation between recovered G and real one: %.3f.\n",
            dotp/sqrt(normG*normGrec));
    printf("Number of correctly recovered coefficients by rounding: %d/%d\n",
            reccoeffs, N);

    */
    return 0;
}

/*
vim: ts=4 expandtab
*/
