# Modeling protocol and assumptions

## Data unit and availability

One row is a policy–product period; ID repeats across periods. It does not uniquely identify a person across products. Count and cost describe the current period. The provided data has exactly matching indicators N_claims_year > 0 and Cost_claims_year > 0; the two-part implementation checks this and stops if the relationship changes.

Date_last_renewal anchors age, driving experience and vehicle age. Static insured/vehicle characteristics and underwriting channel are the intended predictor set. Cumulative N_claims_history and R_Claims_history may include contemporaneous outcomes and are excluded. Premium, Seniority, Policies_in_force, maximum-product fields and lapse information are not used: their historical point-in-time interpretation is insufficient for this forecast design. Value_vehicle is explicitly a 31/12/2019 market value in the source paper and is excluded. The data is an anonymized retrospective extraction, so full operational availability is still not established.

Invalid negative vehicle ages or implausible ages are treated as missing; training-only medians impute numeric fields. Missing fuel has an explicit Unknown category. Factors use the source codebook. No source IDs or birthdates are exported in results.

## Evaluation cohorts

Train: renewal years 2015–2016. Validation: new IDs first represented in 2017. Test: IDs absent from both development sets, renewed in 2018. The remaining later observations of seen IDs are excluded. This is simultaneously forward in renewal time and disjoint in available policy ID. It targets unseen-policy performance, not the easier task of predicting another year for an already modeled policy. Different-product household links remain unobservable.

The panel's last period ends during 2018 and was extracted in 2019. Claims can develop further, observation/exposure may differ, and cohorts are not exchangeable. Counts and costs are for the recorded periods; no claims-per-exposure-year rate or fully developed ultimate premium is claimed. Euro values are nominal, without an inflation adjustment.

## Marginal distributions

Poisson uses the sample mean. Negative binomial uses the same MLE mean and a numerical profile MLE for size, with variance mu + mu²/size. All plots and expected counts use those exact fitted parameters. The final count category is 5+ with the complete remaining probability mass. AIC/BIC are descriptive working-likelihood criteria because repeated policy rows violate simple iid assumptions; there are no chi-square significance claims.

Positive costs use exponential, lognormal, Gamma, Weibull and Lomax (Pareto II, support x >= 0) MLE fits on training positives. Positive parameters are optimized on log scales with finite bounds and convergence checks. The lognormal log-standard-deviation uses the MLE divisor n. Validation mean negative log density selects the marginal distribution before the test score is computed. Tail tables compare empirical and fitted exceedance probabilities. There is no naive KS p-value: fitting parameters on the sample, rounding/ties and within-policy dependence invalidate its usual calibration.

## GLMs and expected cost

Two prespecified logistic formulas (demographic/basic vehicle versus a richer vehicle specification) are selected by validation AUC. Probabilities remain training-fitted. Validation F1 chooses an optional classification threshold; the standard 0.5 threshold is reported alongside it. No loss matrix is specified, so neither is called a profit-optimal threshold.

Gamma GLMs use a log link and the corresponding formulas, excluding the risk-category factor: the training positive-cost sample contains no agricultural-vehicle positives, making that factor's conditional-cost effect unidentifiable. Vehicle age, power, fuel and other measured characteristics remain. Validation mean Gamma deviance selects the conditional model. No refit on validation takes place.

Expected annual cost is P(claim | X) × E(cost | claim, X). This is an expected claims-cost estimate before expenses, capital loadings, taxes and profit; it is not a quoted commercial insurance premium. Test MAE/RMSE and mean predictions are compared with training-derived constant baselines. A risk-decile calibration plot makes the cohort shift visible.

## Interpretation

The held-out logistic AUC is only about 0.564. The annual-cost model does not improve RMSE over a constant baseline. Rare agricultural records have no positive training examples; related coefficients and predictions need particular care. Coefficients are descriptive associations, not causal effects. Standard errors are explicitly labeled working-independence estimates; no unqualified Wald confidence intervals or significance conclusions are reported. A policy-cluster bootstrap, exposure audit, stronger point-in-time features and an external-period validation would be needed for inference or a substantive pricing application.
