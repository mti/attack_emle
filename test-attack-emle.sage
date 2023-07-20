#!/usr/bin/env sage

import contextlib
import itertools
load('impl-gen.sage')

# Parameters ("NIST Level-I")
n,d,c_max,x_max,p_max = 64, 3, 4, 4, 26  
q = 256
p = mkP()
G = mkG()

CRED   = '\033[31m'
CGREEN = '\033[32m'
CEND   = '\033[0m'

def make_instance():
    x = vector(ZZ, [ randint(-x_max, x_max) for _ in range(n)])
    with contextlib.redirect_stdout(None):
        h, _, _ = eMLE(x, G[1], 0)
    return x, h

def make_keygen_instance():
    with contextlib.redirect_stdout(None):
        x1, h1, x2, h2, _, _ = keygen()
    return x1, h1, x2, h2
    
def veccenterdiv(v, p):
    w = [round(vi/p) for vi in list(v)]
    return vector(ZZ, w)

def compute_ki(x,h):
    gprime = G[0] + G[1] + G[2]
    hprime = h - mul(G[0], G[1], n, p[0])
    k2 = veccenterdiv(hprime - mul(gprime,x,n,p[2]), p[2])
    k1 = veccenterdiv(hprime - mul(gprime,x,n,p[2]) - p[2]*k2, p[1])
    k0 = veccenterdiv(hprime - mul(gprime,x,n,p[2]) - p[2]*k2 - p[1]*k1, p[0])
    return k0, k1, k2
    
def norm_samples(n):
    def norm_onesamp():
        x, h      = make_instance()
        k0, k1, _ = compute_ki(x,h)
        return float(x.norm()), float(k0.norm()), float(k1.norm())
    return [norm_onesamp() for _ in range(n)]
        
def norm_keygen_samples(n):
    def norm_onesamp():
        x1, h1, x2, h2 = make_keygen_instance()
        k01, k11, _    = compute_ki(x1,h1)
        k02, k12, _    = compute_ki(x2,h2)
        return [ (float(x1.norm()), float(k01.norm()), float(k11.norm())),
                 (float(x2.norm()), float(k02.norm()), float(k12.norm())) ]
    return list(itertools.chain(*[norm_onesamp() for _ in range(n//2)]))

def estimate_scaleparams(nsamp=1000,keygen=True):
    if keygen:
        l = norm_keygen_samples(nsamp)
    else:
        l = norm_samples(nsamp)

    avgxnorm   = mean([x     for (x,k0,k1) in l])
    avgk0norm  = mean([k0    for (x,k0,k1) in l])
    avgk1norm  = mean([k1    for (x,k0,k1) in l])
    avgxscale  = mean([k1/x  for (x,k0,k1) in l])
    avgk0scale = mean([k1/k0 for (x,k0,k1) in l])

    print("Select scalex  ~ %.1f ~ %.1f" % (avgxscale,  avgk1norm/avgxnorm ))
    print("Select scalek0 ~ %.1f ~ %.1f" % (avgk0scale, avgk1norm/avgk0norm))

def estimate_eparam(nsamp=1000,keygen=True,scalex=64,scalek0=20):
    if keygen:
        l = norm_keygen_samples(nsamp)
    else:
        l = norm_samples(nsamp)

    variance = mean(
            [(scalex*x)^2 + (scalek0*k0)^2 + k1^2 for (x,k0,k1) in l]) / (3*n)

    print("Select e ~ %.1f" % sqrt(variance))

def construct_modp2_lattice(scalex=1, scalek0=1):
    I = identity_matrix(n)
    invp1 = (1/p[1]) % p[2]
    gprime = G[0] + G[1] + G[2]

    L = block_matrix(
        [[scalex*I, 0*I, matrix.circulant((-invp1 * gprime) % p[2])],
         [0*I, scalek0*I, ((-p[0]*invp1)%p[2])*I],
         [0*I, 0*I, p[2]*I]])
    return L

def reduce_mod_hnf(x,H):
    y = x
    for i in range(3*n):
        y -= round(y[i] / H[i,i]) * H[i]
    return y

def attack(h,scalex=64,scalek0=20,e=163,L=None,bsize=20):
    invp1 = (1/p[1]) % p[2]
    hprime = h - mul(G[0], G[1], n, p[0])
    target = vector(ZZ,[0]*(2*n) + list((invp1*hprime)%p[2]))

    if L is None:
        L = construct_modp2_lattice(scalex, scalek0)    
    M = L.stack(target)
    Lkannan = M.augment(vector(ZZ, [0]*(3*n) + [e]))

    Lred = Lkannan.BKZ(block_size=bsize)
    if abs(Lred[0][-1]) == e:
        recx = Lred[0][:n] / scalex * round(e/Lred[0][-1])
        return vector(ZZ, recx)
    return None

def precompute_reduced_lattice(scalex=64,scalek0=20,bsize=20):
    L = construct_modp2_lattice(scalex, scalek0)
    return L.BKZ(block_size=bsize)

def test_attack_emle(tests,scalex=64,scalek0=20,e=163,L=None,bsize=20):
    print("Attack against the eMLE problem")
    print("-------------------------------")
    succ = 0
    if L is None:
        print("Precompute key-independent reduction:")
        L = precompute_reduced_lattice(scalex,scalek0,bsize)
        print("| ...done")
    else:
        print("Using provided precomputed reduced basis.")
    
    for i in range(tests):
        print("Instance %d/%d:" % (i+1, tests))
        x, h = make_instance()
        print("| x = " + x[:15].__str__()[:-1] + ", ...)")
        """
        k0, k1, _ = compute_ki(x,h)
        print("| norm(a·x,b·k_0,k1) = %.1f" % float(vector(ZZ,
            list(scalex*x) + list(scalek0*k0) + list(k1)).norm()))
        print("| |k1|/|x| = %.1f; |k1|/|k0| = %.1f" %
            (float(k1.norm() / x.norm()), float(k1.norm() / k0.norm())))
        """
        v = attack(h,scalex,scalek0,e,L,bsize)
        if v is not None:
            print("| v = " + v[:15].__str__()[:-1] + ", ...)")
        if v==x:
            print("| " + CGREEN + "...success!" + CEND)
            succ += 1
        else:
            print("| " + CRED + "...failed." + CEND)
    
    print("%d/%d correct recoveries (%.1f%% success rate)" %
        (succ, tests, 100.*float(succ/tests)))
        
def test_attack_keygen(tests,scalex=64,scalek0=20,e=163,L=None,bsize=20):
    print("Attack against eMLE-Sig 2.0 keys")
    print("--------------------------------")
    succ = 0
    if L is None:
        print("Precompute key-independent reduction:")
        L = precompute_reduced_lattice(scalex,scalek0,bsize)
        print("| ...done")
    else:
        print("Using provided precomputed reduced basis.")
    
    for i in range(tests):
        print("Instance %d/%d:" % (i+1, tests))
        x1, h1, x2, h2 = make_keygen_instance()
        print("| x1 = " + x1[:15].__str__()[:-1] + ", ...)")
        print("| x2 = " + x2[:15].__str__()[:-1] + ", ...)")
        v = attack(h1,scalex,scalek0,e,L,bsize)
        if v==x1:
            print("| " + CGREEN + "x1 correctly recovered!" + CEND)
            succ += 1
        else:
            print("| " + CRED + "x1 recovery failed" + CEND)
        v = attack(h2,scalex,scalek0,e,L,bsize)
        if v==x2:
            print("| " + CGREEN + "x2 correctly recovered!" + CEND)
            succ += 1
        else:
            print("| " + CRED + "x2 recovery failed" + CEND)
    
    print("%d/%d correct recoveries (%.1f%% success rate)" %
        (succ, 2*tests, 100.*float(succ/tests/2)))

test_attack_keygen(25, 64, 20, 163) 

# vim: ts=4 ft=python
