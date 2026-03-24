## Candidate Edge Functions

Two function families satisfy all requirements: power-law and exponential. Both are seamless at the boundary by construction, reach (near) zero at the maximum, and have a single tuning parameter.

### {status:PowerLaw|color:red}

**Edge function:**

$$p(s) = (1 - s)^\alpha$$

where $\alpha > 0$ is the steepness parameter.

**Properties:**
- $p(0) = 1$ — seamless by construction
- $p(1) = 0$ — density is exactly zero at max weight (impossible to generate)
- $\alpha$ controls the curve shape:
  - $\alpha = 1$: linear (straight line from boundary to max)
  - $\alpha = 2$: quadratic (gentle start, then steeper)
  - $\alpha = 5+$: very steep (most edge zone fish cluster near the boundary)

**Naive sampling:**

```
u = random()
if u ≥ T:
    weight = 1 − z × (1 − random())^(1/(α+1))
else:
    weight = u
```

~~~panel type=info title="In simple terms"
Think of it as a ramp that gets steeper as it approaches the edge: with $\alpha=2$, the first half of the edge zone still has reasonable density, but the last quarter drops off sharply. With $\alpha=5$, almost everything bunches near the start of the edge zone, and the upper end is practically empty.
~~~

### {status:Exponential|color:green}

**Edge function:**

$$p(s) = e^{-\lambda \cdot s}$$

where $\lambda > 0$ is the rate parameter.

### Comparison

| Property              | {status:PowerLaw|color:red} | {status:Exponential|color:green} |
|-----------------------|-----------------------------|----------------------------------|
| Density at 100%       | $= 0$ (hard zero)          | $> 0$ (asymptotic)              |
| Parameter             | $\alpha$ (steepness)        | $\lambda$ (rate)                |

<!-- {toc} -->
