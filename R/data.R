# Data contract and a forward, policy-disjoint evaluation protocol.
read_portfolio <- function(path) {
  d <- read.csv(path, sep = ";", dec = ".", stringsAsFactors = FALSE,
                na.strings = c("", "NA"), check.names = FALSE)
  required <- c("ID", "Date_last_renewal", "Date_birth", "Date_driving_licence",
                "Year_matriculation", "N_claims_year", "Cost_claims_year", "Power",
                "Area", "Second_driver", "Type_risk", "Distribution_channel", "Type_fuel")
  if (!all(required %in% names(d))) stop("Missing columns in the source dataset.")
  for (name in c("Date_last_renewal", "Date_birth", "Date_driving_licence")) {
    d[[name]] <- as.Date(d[[name]], format = "%d/%m/%Y")
    if (anyNA(d[[name]])) stop(paste("Invalid dates in", name))
  }
  numeric_fields <- c("N_claims_year", "Cost_claims_year", "Power", "Year_matriculation")
  for (name in numeric_fields) d[[name]] <- as.numeric(d[[name]])
  if (anyNA(d[, c("N_claims_year", "Cost_claims_year")]) ||
      any(d$N_claims_year < 0 | d$Cost_claims_year < 0) ||
      any(d$N_claims_year != floor(d$N_claims_year))) stop("Invalid claim outcomes.")
  if (anyDuplicated(d[, c("ID", "Date_last_renewal")])) stop("Duplicate policy/renewal rows.")
  d$renewal_year <- as.integer(format(d$Date_last_renewal, "%Y"))
  d$claim <- as.integer(d$N_claims_year > 0)
  if (any((d$Cost_claims_year > 0) != (d$claim == 1))) {
    stop("Claim occurrence and positive cost differ; revise the two-part model definition.")
  }
  d
}

policy_split <- function(d) {
  train <- which(d$renewal_year <= 2016)
  validation <- which(d$renewal_year == 2017 & !d$ID %in% d$ID[train])
  test <- which(d$renewal_year == 2018 & !d$ID %in% d$ID[c(train, validation)])
  parts <- list(train = train, validation = validation, test = test)
  if (any(lengths(parts) == 0)) stop("The documented 2015-2018 cohorts are required.")
  parts
}

engineer <- function(d) {
  # Ages are measured at the actual policy renewal, never at today's date.
  d$age_decades <- as.numeric(d$Date_last_renewal - d$Date_birth) / 365.25 / 10
  d$experience_decades <- as.numeric(d$Date_last_renewal - d$Date_driving_licence) / 365.25 / 10
  d$vehicle_age <- d$renewal_year - d$Year_matriculation
  d$log_power <- log1p(d$Power)
  d$risk <- factor(d$Type_risk, levels = 1:4)
  d$area <- factor(d$Area, levels = 0:1)
  d$second_driver <- factor(d$Second_driver, levels = 0:1)
  d$channel <- factor(d$Distribution_channel, levels = 0:1)
  d$fuel <- factor(ifelse(is.na(d$Type_fuel), "Unknown", d$Type_fuel), levels = c("D", "P", "Unknown"))
  # Invalid source values become missing, with imputation learned on training rows.
  d$age_decades[d$age_decades < 1.6 | d$age_decades > 11] <- NA_real_
  d$experience_decades[d$experience_decades < 0] <- NA_real_
  d$vehicle_age[d$vehicle_age < 0 | d$vehicle_age > 100] <- NA_real_
  d
}

impute_from_training <- function(d, train) {
  fields <- c("age_decades", "experience_decades", "vehicle_age", "log_power")
  medians <- vapply(d[train, fields, drop = FALSE], median, numeric(1), na.rm = TRUE)
  if (any(!is.finite(medians))) stop("An entire training feature is missing.")
  for (field in fields) d[[field]][!is.finite(d[[field]])] <- medians[[field]]
  list(data = d, medians = medians)
}

validate_formula <- function(formula) {
  forbidden <- c("ID", "Date_lapse", "Lapse", "Date_next_renewal", "N_claims_history",
                 "R_Claims_history", "Premium", "Value_vehicle", "Seniority", "Max_policies", "Max_products")
  predictors <- all.vars(formula[[3]])
  if (any(predictors %in% forbidden)) stop("A predictor has unverified or future availability.")
  if (any(predictors %in% c("N_claims_year", "Cost_claims_year", "claim"))) stop("Outcome-derived predictor.")
  invisible(TRUE)
}
