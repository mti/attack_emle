# Attack on NIST candidate signature eMLE-Sig 2.0

This repository contains example code to demonstrate the attack on
eMLE-Sig 2.0 described in [this official comment][commenturl] on the
pqc-forum mailing list.

The attack is mounted against the SageMath implementation of eMLE-Sig 2.0
provided in the submission package (`impl-gen.sage`), and targets the *n*
= 64 parameter set, claimed to reach NIST Level-I security. This attack
recovers the secret key (*x*<sub>1</sub>, *x*<sub>2</sub>) from the
public key with good probabiliy in a few minutes (over 80% success rate
with BKZ block size 20).

To run the attack on 25 keys with default settings (and a systemwide
SageMath installation available):
```
sage test_attack_emle.sage
```
See the code itself to tweak the settings (such as the BKZ block size in
use).

## Remarks

* The same attack is expected to break all parameter sets, not just
  level-I, just by adjusting `scalex`, `scalek0` and `e` appropriately
  for other levels. Appropriate preset values are forthcoming.
  Expect somewhat slower runtimes due to higher dimensions, however.

* We have taken on faith that the SageMath implementation provided by the
  authors in their submission package is actually consistent with the C
  implementation. Even if discrepancies exist, however, the attack should
  carry over with only minor changes, since the analysis breaks the
  specification itself.

—Mehdi Tibouchi, July 20, 2023.

[commenturl]: https://groups.google.com/a/list.nist.gov/g/pqc-forum/c/zas5PLiBe6A/m/EVmNzzglBQAJ
