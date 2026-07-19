# Finalizing renv.lock before release

The `renv.lock` in this repository lists the required packages but leaves the
`Version` fields blank. A lockfile is only useful if the versions match the
environment that actually produced the results, so regenerate it on the machine
where you run the analysis:

```r
install.packages("renv")
renv::init()          # detects the packages used by technical_validation.R
renv::snapshot()      # writes exact versions into renv.lock
```

Commit the resulting `renv.lock` (and delete this note). The `R.Version` field
should read whatever R version you used; update it if it differs from 4.3.3.

Do not hand-edit version numbers in; let `renv::snapshot()` fill them so they are
guaranteed to match installed reality.
