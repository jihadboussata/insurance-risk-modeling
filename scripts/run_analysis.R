#!/usr/bin/env Rscript
# Execute from repository root. Only base/recommended R packages are used.
source("R/data.R"); source("R/metrics.R"); source("R/distributions.R")
args <- commandArgs(trailingOnly=TRUE)
option <- function(key, default) { i <- match(key,args); if (is.na(i)) default else {
  if (i == length(args)) stop(paste("Missing value for", key)); args[i+1] } }
data_path <- option("--data", "data/raw/Motor_vehicle_insurance_data.csv")
out <- option("--output", "results")
dir.create(out, recursive=TRUE, showWarnings=FALSE)
save_csv <- function(x, file) write.csv(x, file.path(out,file), row.names=FALSE, na="")
d <- read_portfolio(data_path)
parts <- policy_split(d)
prepared <- impute_from_training(engineer(d), parts$train)
d <- prepared$data
tr <- d[parts$train,]; va <- d[parts$validation,]; te <- d[parts$test,]
cohorts <- do.call(rbind,lapply(names(parts),function(name) {
  z <- d[parts[[name]],]; data.frame(partition=name, rows=nrow(z), policies=length(unique(z$ID)),
    start=as.character(min(z$Date_last_renewal)), end=as.character(max(z$Date_last_renewal)),
    claim_rate=mean(z$claim), positive_costs=sum(z$claim), mean_cost=mean(z$Cost_claims_year))
}))
save_csv(cohorts,"cohorts.csv")
save_csv(data.frame(feature=names(prepared$medians),training_median=prepared$medians),"imputation.csv")

# 1. Claim frequency: all model curves use the same MLE parameters.
count_fits <- fit_counts(tr$N_claims_year)
save_csv(count_fits,"count_models.csv")
counts <- tr$N_claims_year
bins <- 0:5
empirical <- tabulate(pmin(counts,5)+1,nbins=6)
poisson <- c(dpois(0:4,mean(counts)),ppois(4,mean(counts),lower.tail=FALSE))
nbsize <- count_fits$size[2]
negative_binomial <- c(dnbinom(0:4,size=nbsize,mu=mean(counts)),pnbinom(4,size=nbsize,mu=mean(counts),lower.tail=FALSE))
count_diagnostics <- data.frame(claims=c("0","1","2","3","4","5+"),observed=empirical,
  poisson_expected=poisson*length(counts), nb_expected=negative_binomial*length(counts))
save_csv(count_diagnostics,"count_diagnostics.csv")
png(file.path(out,"claim_counts.png"),width=1400,height=850,res=160,type="cairo")
par(mar=c(4,4,3,1))
barplot(t(rbind(empirical=empirical/length(counts),Poisson=poisson,NegativeBinomial=negative_binomial)),
  beside=TRUE, names.arg=c("Observed","Poisson MLE","Negative binomial MLE"),
  col=c("#007f86","#f0a14a","#9da9bb","#59719b","#b594b6","#cf6679"),
  legend.text=c("0","1","2","3","4","5+"),args.legend=list(x="topright",bty="n"),
  ylab="Probability",main="Training cohort: annual claim-count distribution")
dev.off()

# 2. Positive annual aggregate cost; this is not individual-claim severity.
positive <- tr$Cost_claims_year[tr$claim==1]
positive_val <- va$Cost_claims_year[va$claim==1]
positive_test <- te$Cost_claims_year[te$claim==1]
fits <- positive_fits(positive)
fit_table <- do.call(rbind,lapply(names(fits),function(name) {
  p <- fits[[name]]; ll <- sum(log_density(positive,name,p)); k <- length(p)
  data.frame(model=name,train_aic=2*k-2*ll,train_bic=log(length(positive))*k-2*ll,
    validation_mean_nll=-mean(log_density(positive_val,name,p)))
}))
selected_distribution <- fit_table$model[which.min(fit_table$validation_mean_nll)]
save_csv(fit_table,"positive_cost_models.csv")
save_csv(do.call(rbind,lapply(names(fits),function(name) data.frame(model=name,parameter=names(fits[[name]]),value=as.numeric(fits[[name]])))),"distribution_parameters.csv")
save_csv(data.frame(selected_model=selected_distribution,test_mean_nll=-mean(log_density(positive_test,selected_distribution,fits[[selected_distribution]]))),"positive_cost_test.csv")
limits <- c(1000,2000,5000,10000,20000)
tail_table <- data.frame(threshold_eur=limits,empirical_train=vapply(limits,function(q)mean(positive>q),numeric(1)),
  empirical_test=vapply(limits,function(q)mean(positive_test>q),numeric(1)))
for(name in names(fits)) tail_table[[name]] <- 1-model_cdf(limits,name,fits[[name]])
save_csv(tail_table,"tail_probabilities.csv")
png(file.path(out,"positive_costs.png"),width=1600,height=750,res=160,type="cairo")
par(mfrow=c(1,2),mar=c(4,4,3,1))
hist(log10(positive),breaks=55,col="#007f86",border="white",main="Positive annual costs: training cohort",xlab="log10(cost in EUR)")
grid <- exp(seq(log(min(positive)),log(max(positive)),length.out=500))
plot(grid,ecdf(positive)(grid),type="l",log="x",lwd=2,xlab="Positive annual cost (EUR)",ylab="Cumulative probability",main="Marginal model fit")
colors <- c("#ce6c31","#007f86","#5e6eae","#b15c8b","#69852e")
for(i in seq_along(fits)) lines(grid,model_cdf(grid,names(fits)[i],fits[[i]]),col=colors[i],lty=i+1,lwd=1.5)
legend("bottomright",legend=c("Empirical",names(fits)),col=c("black",colors),lty=1:6,cex=.75,bty="n")
dev.off()

# 3/4. Prespecified GLMs, selected on validation; all estimators remain train-only.
formulas <- list(demographic=claim ~ age_decades + I(age_decades^2) + experience_decades + vehicle_age + risk + area,
  vehicle=claim ~ age_decades + I(age_decades^2) + experience_decades + vehicle_age + risk + area +
    log_power + second_driver + channel + fuel)
invisible(lapply(formulas,validate_formula))
logits <- lapply(formulas,function(f) glm(f,family=binomial(),data=tr))
if (!all(vapply(logits,function(model)model$converged,logical(1)))) stop("A logistic GLM did not converge.")
logit_validation <- vapply(logits,function(m) rank_metrics(va$claim,predict(m,newdata=va,type="response"))$auc,numeric(1))
logit_name <- names(which.max(logit_validation))
logit <- logits[[logit_name]]
threshold <- f1_threshold(va$claim,predict(logit,newdata=va,type="response"))
p_test <- predict(logit,newdata=te,type="response")
baseline_p <- rep(mean(tr$claim),nrow(te))
classification <- rbind(selected_validation_f1=classification_metrics(te$claim,p_test,threshold),
  selected_default_0.5=classification_metrics(te$claim,p_test,.5),
  training_prior=classification_metrics(te$claim,baseline_p,.5))
save_csv(data.frame(model=rownames(classification),classification,check.names=FALSE),"classification_test.csv")
save_csv(data.frame(model=names(logit_validation),validation_auc=logit_validation),"classification_selection.csv")

gamma_formulas <- lapply(formulas,function(f) {
  f[[2]] <- as.name("Cost_claims_year")
  # No positive agricultural-vehicle costs occur in training. Avoid an
  # unidentifiable category coefficient; retain measured vehicle properties.
  update(f,. ~ . - risk)
})
gammas <- lapply(gamma_formulas,function(f) glm(f,family=Gamma(link="log"),data=tr[tr$claim==1,]))
if (!all(vapply(gammas,function(model)model$converged,logical(1)))) stop("A Gamma GLM did not converge.")
gamma_validation <- vapply(gammas,function(m) cost_metrics(positive_val,
  predict(m,newdata=va[va$claim==1,],type="response"),TRUE)[["mean_gamma_deviance"]],numeric(1))
gamma_name <- names(which.min(gamma_validation)); gamma_model <- gammas[[gamma_name]]
conditional_prediction <- predict(gamma_model,newdata=te,type="response")
positive_comparison <- rbind(selected=cost_metrics(positive_test,conditional_prediction[te$claim==1],TRUE),
  training_mean=cost_metrics(positive_test,rep(mean(positive),length(positive_test)),TRUE))
save_csv(data.frame(model=rownames(positive_comparison),positive_comparison,check.names=FALSE),"conditional_cost_test.csv")
save_csv(data.frame(model=names(gamma_validation),validation_gamma_deviance=gamma_validation),"conditional_cost_selection.csv")
annual_comparison <- rbind(two_part=cost_metrics(te$Cost_claims_year,p_test*conditional_prediction),
  training_mean=cost_metrics(te$Cost_claims_year,rep(mean(tr$Cost_claims_year),nrow(te))))
save_csv(data.frame(model=rownames(annual_comparison),annual_comparison,check.names=FALSE),"annual_cost_test.csv")
coefficients <- function(model,label) {
  s <- coef(summary(model)); data.frame(model=label,term=rownames(s),coefficient=s[,1],
    working_independence_standard_error=s[,2],multiplicative_effect=exp(s[,1]))
}
save_csv(rbind(coefficients(logit,"claim_odds"),coefficients(gamma_model,"positive_annual_mean")),"coefficients.csv")
save_csv(data.frame(logistic_model=logit_name,gamma_model=gamma_name,validation_f1_threshold=threshold,
  train_rows=nrow(tr),validation_rows=nrow(va),test_rows=nrow(te)),"run_summary.csv")

png(file.path(out,"classification.png"),width=1600,height=750,res=160,type="cairo")
par(mfrow=c(1,2),mar=c(4,4,3,1))
curve <- rank_metrics(te$claim,p_test)$curve
plot(c(0,curve$false_positive_rate,1),c(0,curve$recall,1),type="l",col="#007f86",lwd=2,
  xlab="False positive rate",ylab="True positive rate",main=sprintf("New policies in 2018: AUC %.3f",classification[1,"auc"]))
abline(0,1,lty=2,col="gray")
plot(curve$recall,curve$precision,type="l",col="#007f86",lwd=2,xlab="Recall",ylab="Precision",ylim=c(0,1),
  main=sprintf("Test average precision %.3f",classification[1,"average_precision"]))
abline(h=mean(te$claim),lty=2,col="gray")
dev.off()
png(file.path(out,"annual_costs.png"),width=1200,height=800,res=160,type="cairo")
par(mar=c(4,4,3,1))
groups <- pmin(10L, ceiling(rank(p_test*conditional_prediction,ties.method="first")/nrow(te)*10))
observed <- tapply(te$Cost_claims_year,groups,mean)
predicted <- tapply(p_test*conditional_prediction,groups,mean)
plot(1:10,observed,type="b",pch=16,col="#007f86",ylim=range(c(observed,predicted)),
  xlab="Decile of predicted annual cost (test only)",ylab="Mean annual cost (EUR)",main="Two-part model: held-out calibration by risk decile")
lines(1:10,predicted,type="b",pch=17,col="#ce6c31")
legend("topleft",c("Observed","Predicted"),col=c("#007f86","#ce6c31"),pch=c(16,17),lty=1,bty="n")
dev.off()
capture.output(sessionInfo(),file=file.path(out,"sessionInfo.txt"))
writeLines(c(paste("Source file MD5:",unname(tools::md5sum(data_path))),
  paste("Source rows:",nrow(d)),paste("Source policies:",length(unique(d$ID))),
  "Only aggregate outputs are exported; source identifiers and dates are not included."),file.path(out,"provenance.txt"))
print(cohorts); print(classification); print(positive_comparison); print(annual_comparison)
