# Attack on NIST candidate signature eMLE-Sig 2.0

This repository contains example code to demonstrate the attack on
eMLE-Sig 2.0 described in [this official comment][commenturl] on the
pqc-forum mailing list.

The attack is mounted against the C reference implementation of eMLE-Sig
2.0, and targets the *n* = 64 parameter set, claimed to reach NIST
Level-I security.

With the notation of the eMLE-Sig 2.0 specification, this attack recovers
the vector $`\mathbf{z} \otimes \mathbf{x}_1`$ from sufficiently many
valid signatures on arbitrary messages, where $`\mathbf{x}_1`$ is (half
of) the signing key, and $`\mathbf{z} = (1,-1,0,0,\ldots,0)`$.

Note that once we know this value, there are only at most 9 choices left
for $`\mathbf{x}_1`$, and moreover the exact same approach also works for
$`\mathbf{x}_2`$, so this is effectively a full key recovery attack.

To build and run the attack:
```
cd eMLE-Sig-I
make test_attack
./test_attack 1000000  #run the attack with 1,000,000 signature samples
./test_attack          #run the attack with the default number of samples (2,500,000)
```

## Remarks

* The exact same attack is expected to break all parameter sets, not just
  level-I. Corresponding experiments are forthcoming.

—Mehdi Tibouchi, July 20, 2023.

## Update (2023–08–03)

The attack has been adapted to the *revised* scheme proposed by the
eMLE-Sig 2.0 submitters, by simply *reducing* the number of signatures
necessary for recovery. See [this comment][commentrevision] on the
mailing list for an explanation of why essentially no change was
necessary.

[commenturl]: https://groups.google.com/a/list.nist.gov/g/pqc-forum/c/zas5PLiBe6A/m/APUe-wfXBQAJ
[commentrevision]: https://groups.google.com/a/list.nist.gov/g/pqc-forum/c/zas5PLiBe6A/m/OYNb3WevAAAJ
