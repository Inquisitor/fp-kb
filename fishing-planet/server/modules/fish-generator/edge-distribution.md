# Edge Distribution — Design Analysis

> How to make fish near maximum weight progressively rarer while keeping the rest of the distribution uniform — and how to implement it correctly.

Related: [FP-41845](../../../tasks/FP-41845--weight-generation-v2/journal.md) (Phase 2a) | [Interactive comparison tool](decay-comparison.html)

---

## Notation

The following symbols are used throughout this article:

| Symbol | Meaning                                                                         |
|--------|---------------------------------------------------------------------------------|
| `x`    | Normalized weight position within the form range (0 = MinWeight, 1 = MaxWeight) |
| `T`    | Threshold — boundary between central and edge zones (e.g. 0.95)                 |
| `z`    | Edge zone width: `z = 1 − T` (e.g. 0.05)                                        |
| `s`    | Position within edge zone, normalized to [0, 1]: `s = (x − T) / z`              |
| `p(s)` | Edge function — defines the density shape in the edge zone                      |
| `c`    | Normalization constant — ensures total probability = 1                          |
| `A`    | Edge area fraction: `A = ∫₀¹ p(s) ds`                                           |
| `α`    | Power-law steepness parameter                                                   |
| `λ`    | Exponential rate parameter                                                      |

## 1. Problem Statement

Fish weight within a form range (e.g. 80–130 kg for Trophy) is generated uniformly. Every weight in the range is equally likely, including values very close to the maximum. In practice this means:

- Players routinely catch fish at or near max weight
- Leaderboard records are set and broken trivially — top entries cluster at the ceiling
- The leaderboard feels "synthetic": no meaningful spread, no sense of rarity

**Goal:** Introduce a smooth density falloff in the edge zone of the weight range so that fish near the maximum become progressively rarer, while preserving uniform distribution across most of the range.

In plain terms: catching a 129 kg Trophy should feel special. Catching a 130 kg one should be an event. The edge distribution makes this happen mathematically.

### Requirements

The target probability density function (PDF) must satisfy two constraints:

1. **Seamless transition.** The density at the boundary between the central zone and the edge zone must be continuous — no visible cliff, jump, or spike where the two zones meet.

2. **Smooth falloff to zero.** Within the edge zone, the density must decrease smoothly from the central zone level down to zero (or near zero) at the maximum weight.

![Figure 1: Desired PDF shape](edge-distribution-fig1-desired-pdf.svg)

Think of it as a plateau that smoothly transitions into a downhill slope. The flat part (central zone) is the plateau; the declining part (edge zone) is the slope. The transition point must be seamless — no sudden step.

As it turns out, satisfying both constraints simultaneously is harder than it looks. The choice of the edge function matters (§2–3), but even with the right function, the sampling algorithm must be carefully designed (§4–6).

## 2. Why Normal Distribution Doesn't Work

The original specification called for using a normal distribution to achieve the density falloff. However, the normal distribution is a poor candidate for the edge function `p(s)`, for three independent reasons.

**1. Never reaches zero.** The normal PDF φ(x) > 0 for all x ∈ ℝ. Even at 3σ from the mean, the density is still about 0.4% of the peak. For leaderboard purposes, this means fish at maximum weight are rare but achievable with enough fishing — potentially too achievable. A power-law edge function gives **exact zero** at the maximum; an exponential gives e^(−λ) — at λ=7, that is 0.1% of the peak, and at λ=15, it is practically zero (3×10⁻⁷).

**2. Coupled parameters.** The normal distribution has two parameters (μ, σ), and they interact: changing σ to make the falloff steeper also changes the seam height at the boundary and the amount of probability mass in the edge zone. There is no single "steepness" knob. The power-law and exponential each have a single, intuitive parameter (α or λ) that controls exactly one thing: how steep the falloff is.

**3. Wrong shape for the edge zone.** The normal PDF's shape in a truncated interval [T, 1] is determined by where the interval falls relative to the bell curve:

- If μ is far below T: the edge zone sits in a region where the normal PDF is nearly flat — barely any falloff.
- If μ is near T: decent falloff, but significant density remains at the maximum.
- If μ is above T: the density actually *increases* in part of the edge zone — the wrong direction.

Furthermore, in a 5% edge zone, the normal PDF barely changes at all. With μ=0.5 and σ=0.55 (production parameters from FP-33182), the density at the maximum is still ~94% of the density at the boundary — essentially flat. The normal distribution is the wrong tool for this job.

**Conclusion:** The edge function must satisfy `p(0) = 1` and `p(1) → 0` by construction, with a single intuitive parameter. The normal distribution guarantees neither.

## 3. Candidate Edge Functions

Two function families satisfy all requirements: power-law and exponential. Both are seamless at the boundary by construction, reach (near) zero at the maximum, and have a single tuning parameter.

![Figure 2: Candidate edge functions — comparison](edge-distribution-fig2-candidates.svg)

### 3.1 Power-Law

**Edge function:**

```
p(s) = (1 − s)^α
```

where `α > 0` is the steepness parameter.

**Properties:**
- `p(0) = 1` — seamless by construction
- `p(1) = 0` — density is exactly zero at max weight (impossible to generate)
- `α` controls the curve shape:
  - `α = 1`: linear (straight line from boundary to max)
  - `α = 2`: quadratic (gentle start, then steeper)
  - `α = 5+`: very steep (most edge zone fish cluster near the boundary)

**Naive sampling** (for illustration — see §5–6 for why this needs refinement):

```
u = random()
if u ≥ T:
    weight = 1 − z × (1 − random())^(1/(α+1))
else:
    weight = u
```

Think of it as a ramp that gets steeper as it approaches the edge: with α=2, the first half of the edge zone still has reasonable density, but the last quarter drops off sharply. With α=5, almost everything bunches near the start of the edge zone and the upper end is practically empty.

**Note on max weight:** Since `p(1) = 0`, a fish at exactly MaxWeight is mathematically impossible. In practice, with floating-point arithmetic and millions of samples, fish at 99.999...% of the range appear — effectively indistinguishable from max. The theoretical zero at the boundary is academic, not practical.

### 3.2 Exponential

**Edge function:**

```
p(s) = exp(−λ · s)
```

where `λ > 0` is the rate parameter.

**Properties:**
- `p(0) = exp(0) = 1` — seamless by construction
- `p(1) = exp(−λ)` — density approaches but never reaches zero (asymptotic)
- `λ` controls the falloff rate:
  - `λ = 3`: gentle (exp(−3) ≈ 0.05 — 5% of uniform density at max)
  - `λ = 7`: moderate (exp(−7) ≈ 0.001 — 0.1% at max)
  - `λ = 15`: aggressive (exp(−15) ≈ 3×10⁻⁷ — essentially zero)

**Naive sampling** (for illustration — see §5–6 for why this needs refinement):

```
u = random()
if u ≥ T:
    maxCdf = 1 − exp(−λ)
    weight = T + z × (−ln(1 − random() × maxCdf) / λ)
else:
    weight = u
```

The key difference from power-law: the exponential never truly reaches zero. No matter how large λ is, there is always some (astronomically small) probability of generating a fish at exactly max weight. This is the "asymptotic" behavior — the curve approaches the floor but never touches it.

In game terms: the world record is always theoretically beatable. With power-law, there is a hard ceiling; with exponential, there is a soft one.

### 3.3 Comparison

| Property              | Power-Law            | Exponential            |
|-----------------------|----------------------|------------------------|
| Seam at threshold     | Continuous           | Continuous             |
| Density at 100%       | = 0 (hard zero)      | > 0 (asymptotic)       |
| Parameter             | α (steepness)        | λ (rate)               |
| Parameter meaning     | "How steep the ramp" | "How fast the falloff" |
| Sampling              | Closed-form, O(1)    | Closed-form, O(1)      |
| Average weight shift  | ~1–3% lower          | ~1–3% lower            |
| Max weight achievable | No (exactly zero)    | Yes (vanishingly rare) |
| Tunability            | Easy (single slider) | Easy (single slider)   |

### WeightK Interaction

Both edge functions operate on the **pre-WeightK** normalized weight. The `weightK` multiplier (from the chum/groundbait system) is applied **after** the edge distribution, as a simple multiplication of the final weight. This means:

- Edge distribution shapes the probability within the form's natural range
- WeightK stretches the result beyond the form maximum (oversize fish)
- The two mechanisms are independent — edge distribution does not suppress or amplify WeightK

### Decision

Both functions are implemented with a GlobalVariable switch. Game designers can evaluate both in the [interactive comparison tool](decay-comparison.html) and the WebAdmin simulator, then choose based on gameplay feel.

The practical difference is philosophical: power-law says "there is a maximum, and it is unreachable." Exponential says "the maximum is reachable, but astronomically unlikely." For leaderboard dynamics, the exponential may be more compelling — the theoretical possibility of a perfect fish creates aspiration, even if it never actually happens.

## 4. Naive Implementations — Lessons from History

The right edge function is only half the story. It must also be correctly integrated into the weight generation pipeline. Two prior implementations attempted this and failed, both for the same fundamental reason: they gave the edge zone a fixed probability budget independent of the edge function shape.

### 4.1 Normal-First (Generate-and-Reroute)

The first approach considered:

1. Generate `x ~ Normal(μ, σ)`
2. If `x > T` → accept (this IS the edge zone value)
3. Else → discard, output `y ~ Uniform(0, T)` instead

**Resulting PDF:**

```
f(x) = Φ(T; μ, σ) / T,     for x ∈ [0, T]     — flat, height depends on how much of the normal falls below T
f(x) = φ(x; μ, σ),          for x > T           — raw normal PDF
```

where `Φ` is the normal CDF and `φ` is the normal PDF.

The intuition: most rolls from the normal distribution fall below threshold and get replaced with uniform. The rare rolls above threshold survive and form the edge zone.

**The Seam Problem:**

At `x = T`, the density jumps from `Φ(T)/T` (left) to `φ(T)` (right). These two values are **generally not equal**.

![Figure 3: Seam discontinuity in the normal-first approach](edge-distribution-fig3-seam-drop.svg)

Concrete examples (T = 0.95):

| μ    | σ    | Left density | Right density | Ratio   | P(edge) |
|------|------|--------------|---------------|---------|---------|
| 0.50 | 0.20 | 1.040        | 0.159         | 6.5× ↓  | 1.2%    |
| 0.50 | 0.55 | 0.835        | 0.515         | 1.6× ↓  | 20.7%   |
| 0.80 | 0.55 | 0.640        | 0.700         | ~1.0    | 39.3%   |

This reveals a fundamental tension:

- **Rare edge** (small σ, μ well below threshold) → large seam discontinuity
- **Smooth seam** (μ near threshold, large σ) → fat edge zone (30–40% of fish in the edge zone)

These goals pull the parameters in opposite directions. There is no (μ, σ) combination that simultaneously produces a rare edge AND a smooth seam.

In simpler terms: the normal distribution was not designed for this job. It is like trying to join a flat road to a mountain slope by parking a car on the edge — the transition is not smooth.

### 4.2 Marsaglia Re-Roll (r12950)

The actual production implementation (FP-33182, revision r12950) took a direct approach:

1. Generate a uniform weight x ∈ [0, 1]
2. If x falls in the edge zones (0–5% or 95–100%), discard it
3. Re-generate x within the same zone using a Marsaglia normal distribution (μ=0.5, σ=0.55)

The intent was correct: replace uniform randomness in the edge zone with a distribution that makes extreme values rarer. But the implementation gave the edge zone exactly 10% of all draws (5% per side), regardless of what the Marsaglia distribution produced inside it. The resulting density at the boundary was discontinuous — the same seam as in §4.1 (see Fig 3).

This suffers from the same structural flaw as normal-first: the edge zone gets a fixed probability budget. And even beyond the seam, using the Marsaglia normal inside the edge zone produces a different, more subtle problem — the same one described in §5.

**Verdict:** Both approaches rejected. The seam discontinuity is structural, not a tuning problem.

## 5. The Normalization Trap

Even with the correct edge function — power-law or exponential — a naive implementation can reproduce the same fundamental flaw. This is a more subtle trap, because the edge function formulas are mathematically correct but the sampling is not.

### The naive approach

```
u = rnd.NextDouble()                    // uniform [0, 1]
if u ≥ T:
    edgeU = (u − T) / z                // rescale to [0, 1] within edge zone
    sampled = Strategy.Sample(edgeU)    // apply edge function inverse CDF
    u = T + sampled · z                // map back
return WeightFromNormalized(u)
```

This is simple and intuitive: generate one uniform random number, and if it lands in the edge zone, remap it using the edge function's inverse CDF. The central zone is untouched.

The problem: the probability of landing in the edge zone is **always** equal to the zone fraction (e.g. 5%), regardless of which edge function is selected. All 5% of that probability mass gets redistributed within the edge zone. The redistribution concentrates most of it near the boundary — creating a **density spike**.

This is the same fundamental flaw that doomed the r12950 approach (§4): the edge zone receives a fixed probability budget. With normal-first, the result was a density *drop*. With the correct edge function — a density *spike*. Different symptom, same disease.

![Figure 4: Density spike from naive edge remap](edge-distribution-fig4-naive-spike.svg)

### Why it happens

The central zone has PDF = 1 (pure uniform). The edge zone PDF is derived from the change-of-variables formula. If the edge function maps `edgeU → f(edgeU)`, and the output is `x = T + f(edgeU) · z`, then:

```
PDF_edge(x) = (f⁻¹)'(s)     where s = (x − T) / z
```

For **Power-Law**: `f(v) = 1 − (1−v)^(1/(α+1))`, so `f⁻¹(s) = 1 − (1−s)^(α+1)`.

```
(f⁻¹)'(s) = (α + 1) · (1 − s)^α
```

At `s = 0` (the boundary): `(f⁻¹)'(0) = α + 1`.

The central zone density is 1. The edge zone density at the boundary is `α + 1`. **These are not equal** for any `α > 0` — there is always a discontinuity.

### Spike height

| Strategy          | Density at boundary  | Spike height (vs uniform = 1) |
|-------------------|----------------------|-------------------------------|
| PowerLaw(α=2)     | α + 1 = 3            | 3×                            |
| PowerLaw(α=5)     | α + 1 = 6            | 6×                            |
| PowerLaw(α=50)    | α + 1 = 51           | **51×**                       |
| Exponential(λ=7)  | λ / (1 − e^(−λ)) ≈ 7 | 7×                            |
| Exponential(λ=50) | ≈ 50                 | **50×**                       |

With default parameters (α=50 or λ=50), the spike is **50× the uniform density**. In a histogram, this appears as a sharp pillar at the 95% mark — the exact opposite of the smooth transition that was requested.

Think of it like pouring water through a funnel: 5% of the water (the probability mass in the edge zone) gets squeezed through a funnel that narrows toward the maximum. Most of the water backs up at the entrance of the funnel, creating a pile-up at the boundary.

This is not a bug in the edge function formulas. The formulas correctly implement the inverse CDF of the desired shape. The bug is in how the sampling feeds them: it gives the edge zone exactly `z` probability mass, when the correct amount is `z · A` (where `A < 1` is the area under the edge function).

## 6. The Fix: Normalized Piecewise Inverse CDF

The [interactive comparison tool](decay-comparison.html) already implements the correct algorithm. The key insight: the desired PDF is a **piecewise function** with a normalization constant `c`:

```
f(x) = c                          for x ∈ [0, T]       (central zone)
f(x) = c · p((x − T) / z)        for x ∈ (T, 1]       (edge zone)
```

where `p(0) = 1` (seamless at boundary), `p(1) → 0` (rare at maximum), and:

```
c = 1 / (T + z · A)
```

where `A = ∫₀¹ p(s) ds` is the **edge area fraction** — how much of the zone's width is "filled" by the edge function.

| Strategy       | p(s)    | A = ∫₀¹ p(s) ds      | c (for T=0.95, z=0.05) |
|----------------|---------|----------------------|------------------------|
| CapAtThreshold | 0       | 0                    | 1/0.95 ≈ 1.053         |
| Unrestricted   | 1       | 1                    | 1/1 = 1.000            |
| PowerLaw(α)    | (1−s)^α | **1 / (α + 1)**      | 1.002 (α=2)            |
| Exponential(λ) | e^(−λs) | **(1 − e^(−λ)) / λ** | 1.007 (λ=7)            |

Note how `c` is always very close to 1.0 — the density bump in the central zone is at most ~5%, negligible for game balance.

![Figure 5: Normalized piecewise CDF — seamless transition](edge-distribution-fig5-normalized.svg)

### Sampling with a single random draw

The normalized distribution can be sampled from a single `u ~ Uniform(0,1)` using its **piecewise inverse CDF**:

```
u* = T / (T + z · A)          — the split point

if u < u*:
    x = (u / u*) · T          — rescale to [0, T] uniformly
else:
    w = (u − u*) / (1 − u*)   — rescale to [0, 1] within edge range
    x = T + Sample(w) · z     — apply the SAME edge function formula
```

![Figure 6: Single-draw piecewise inverse CDF](edge-distribution-fig6-split-point.svg)

The elegance: **the edge function formulas do not change at all.** `PowerLaw.Sample(w)` still returns `1 − (1−w)^(1/(α+1))`. `Exponential.Sample(w)` still returns `−ln(1 − w·(1−e^(−λ))) / λ`. The only change is in how the sampling decides *which fraction of random draws* reach the edge function.

### Why it works

The split point `u*` divides the unit interval into two parts proportional to the **area** under each region of the PDF. The central zone has area `c · T`, and the edge zone has area `c · z · A`. Their ratio is:

```
P(central) : P(edge) = T : z · A
```

For PowerLaw α=2, z=0.05: `P(edge) = 0.05/3 / (0.95 + 0.05/3) ≈ 1.7%` (not 5%!).

The edge function then maps the edge zone's 1.7% of draws through the inverse CDF, producing the correct shape. At the boundary, the density from both sides equals `c` — no spike.

### Degenerate cases

**CapAtThreshold** (A = 0): `u* = T / T = 1`. Every draw goes to the central zone. Output is uniform in [0, T]. This is the hard ceiling — no fish above threshold. Behavior is identical to the naive approach.

**Unrestricted** (A = 1): `u* = T / (T + z) = T`. For `u < T`: `x = u`. For `u ≥ T`: `w = (u − T)/z`, `Sample(w) = w`, `x = T + w · z = u`. Pure identity — uniform distribution over the full range. Also identical.

Both edge cases are mathematically consistent. The fix changes nothing for these two strategies.

### Handling both edges simultaneously

When both upper and lower edge zones are active, the full distribution has three regions:

```
f(x) = c · p_lo((z_lo − x) / z_lo)    for x ∈ [0, z_lo]              lower edge
f(x) = c                                for x ∈ [z_lo, T]              central zone
f(x) = c · p_up((x − T) / z_up)        for x ∈ [T, 1]                 upper edge
```

Normalization: `c = 1 / (z_lo · A_lo + centralWidth + z_up · A_up)`, where `centralWidth = 1 − z_lo − z_up`.

The single draw splits into three regions:

```
u1 = c · z_lo · A_lo                    — lower edge probability
u2 = u1 + c · centralWidth              — central zone upper bound

if u < u1:       lower edge sampling
if u1 ≤ u < u2:  central zone: x = z_lo + (u − u1) / c
if u ≥ u2:       upper edge sampling
```

When only one edge is active (the other has zoneFraction = 0 or the scope flag is off), the three-region split reduces to the simpler two-region split from above.

## 7. Historical Context

The seam discontinuity problem has been encountered three times in this project:

1. **Polynomials (pre-FP-33182).** Form-specific polynomials were used to bias weight generation across the entire Unique form range. The polynomial distorted the *whole* distribution rather than just the edge, producing a characteristic double-hump artifact visible in production data. Wrong tool, wrong scope.

2. **Normal-first / Marsaglia re-roll (FP-33182, r12950).** Re-rolling edge zone values through a normal distribution created a seam where `Φ(T)/T ≠ φ(T)`. The seam manifests as a density *drop* at the boundary. Correctly diagnosed during Phase 2a design and rejected.

3. **Naive edge remap.** Even with the correct edge function (power-law or exponential), giving the edge zone a fixed probability budget of `z` creates a density *spike* at the boundary. The seam manifests as a density jump of `(α+1)×` or `λ/(1−e^(−λ))×` — up to 51× with default parameters.

The root cause in all three cases is the same: treating the edge zone as an independent region with its own probability budget, rather than as part of a single normalized distribution. The piecewise inverse CDF approach eliminates this class of bug by construction — the normalization constant `c` enforces continuity mathematically.
