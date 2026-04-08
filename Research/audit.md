# Audit: swift-effects

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/modularization-audit-foundations-batch-A.md (2026-03-20)

**Modularization compliance — MOD-001 through MOD-014**

**Targets**: Effects (3), Effects Built-in (3), Effects Testing (5)

| Rule | Verdict | Notes |
|------|---------|-------|
| MOD-001 Core | PASS | `Effects` (3 files) is the Core. Both variants depend on it. |
| MOD-002 Ext Dep Central | **FAIL** | Effects re-exports Effect Primitives and Dependency Primitives. But Effects Built-in adds Witness Primitives independently, and Effects Testing adds Async Primitives and Clocks independently. These are genuinely different deps, so this is a borderline case. |
| MOD-003 Variant Decomp | PASS | Built-in and Testing are independent. |
| MOD-004 Constraint Iso | N/A | No ~Copyable types. |
| MOD-005 Umbrella | N/A | Only one main Core product. Built-in and Testing are variants, not an umbrella composition. An umbrella could be added but the package is small enough to not need one. |
| MOD-006 Dep Min | PASS | Each target declares only what it needs. |
| MOD-007 Graph Shape | PASS | Max depth = 1. |
| MOD-008 Split Decision | PASS | All targets have reasonable file counts (3-5). |
| MOD-009 Inline Variant | N/A | No inline variants. |
| MOD-010 StdLib Integration | N/A | No stdlib extensions observed. |
| MOD-011 Test Support | N/A | No test support product. Effects Testing serves a similar role but is a main product, not test support. |
| MOD-012 Naming | PASS | Names follow L3 convention: `Effects`, `Effects Built-in`, `Effects Testing`. |
| MOD-013 MARK | N/A | Only 3 source targets (below 5 threshold). |
| MOD-014 Cross-Pkg Traits | N/A | No cross-package optional integrations. |

**Detailed Findings**:

1. **F-EFFECTS-001** (MOD-002, minor): Effects Built-in adds `Witness Primitives` and Effects Testing adds `Async Primitives` + `Clocks` independently. These are genuinely variant-specific deps (not shared across variants), so the violation is borderline acceptable. The deps could be centralized through Core only if other targets would also use them, which they do not.
