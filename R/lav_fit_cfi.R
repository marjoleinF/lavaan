# functions related to CFI and other 'incremental' fit indices

# lower-level functions:
# - lav_fit_cfi
# - lav_fit_rni (same as CFI, but without the max(0,))
# - lav_fit_tli/lav_fit_nnfi
# - lav_fit_rfi
# - lav_fit_nfi
# - lav_fit_pnfi
# - lav_fit_ifi

# higher-level functions:
# - lav_fit_cfi_lavobject

# Y.R. 20 July 2022

# CFI - comparative fit index (Bentler, 1990)
# robust version: Brosseau-Liard & Savalei MBR 2014, equation 15
lav_fit_cfi <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL,
                        c.hat = 1, c.hat.null = 1) {

    # robust?
    if(df > 0 && !missing(c.hat) && !missing(c.hat.null) &&
       c.hat != 1 && c.hat.null != 1) {
        # what to do if X2 = 0 and df = 0? in this case,
        # the scaling factor (ch) will be NA, and we get NA
        # (instead of 1)
        if(X2 < .Machine$double.eps && df == 0) {
            c.hat <- 0
        }
        t1 <- max( c(X2 - (c.hat * df), 0) )
        t2 <- max( c(X2 - (c.hat * df), X2.null - (c.hat.null * df.null), 0) )
    } else {
        t1 <- max( c(X2 - df, 0) )
        t2 <- max( c(X2 - df, X2.null - df.null, 0) )
    }

    if(isTRUE(all.equal(t1, 0)) && isTRUE(all.equal(t2, 0))) {
        CFI <- 1
    } else {
        CFI <- 1 - t1/t2
    }

    CFI
}

# RNI - relative noncentrality index (McDonald & Marsh, 1990)
# same as CFI, but without the max(0,)
lav_fit_rni <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL,
                        c.hat = 1, c.hat.null = 1) {

    # robust?
    if(df > 0 && !missing(c.hat) && !missing(c.hat.null) &&
       c.hat != 1 && c.hat.null != 1) {
        # what to do if X2 = 0 and df = 0? in this case,
        # the scaling factor (ch) will be NA, and we get NA
        # (instead of 1)
        if(X2 < .Machine$double.eps && df == 0) {
            c.hat <- 0
        }
        t1 <- X2 - (c.hat * df)
        t2 <- X2.null - (c.hat.null * df.null)
    } else {
        t1 <- X2 - df
        t2 <- X2.null - df.null
    }

    if(isTRUE(all.equal(t2, 0))) {
        RNI <- as.numeric(NA)
    } else if(!is.finite(t1) || !is.finite(t2)) {
        RNI <- as.numeric(NA)
    } else {
        RNI <- 1 - t1/t2
    }

    RNI
}

# TLI - Tucker-Lewis index (Tucker & Lewis, 1973)
# same as
# NNFI - nonnormed fit index (NNFI, Bentler & Bonett, 1980)
# note: formula in lavaan <= 0.5-20:
# t1 <- X2.null/df.null - X2/df
# t2 <- X2.null/df.null - 1
# if(t1 < 0 && t2 < 0) {
#    TLI <- 1
#} else {
#    TLI <- t1/t2
#}
# note: TLI original formula was in terms of fx/df, not X2/df
# then, t1 <- fx_0/df.null - fx/df
#       t2 <- fx_0/df.null - 1/N (or N-1 for wishart)

# note: in lavaan 0.5-21, we use the alternative formula:
# TLI <- 1 - ((X2 - df)/(X2.null - df.null) * df.null/df)
# - this one has the advantage that a 'robust' version
#   can be derived; this seems non-trivial for the original one
# - unlike cfi, we do not use 'max(0, )' for t1 and t2
#   therefore, t1 can go negative, and TLI can be > 1
lav_fit_tli <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL,
                        c.hat = 1, c.hat.null = 1) {

    # robust?
    if(df > 0 && !missing(c.hat) && !missing(c.hat.null) &&
       c.hat != 1 && c.hat.null != 1) {
        # what to do if X2 = 0 and df = 0? in this case,
        # the scaling factor (ch) will be NA, and we get NA
        # (instead of 1)
        if(X2 < .Machine$double.eps && df == 0) {
            c.hat <- 0
        }
        t1 <- (X2 - c.hat * df) * df.null
        t2 <- (X2.null - c.hat.null * df.null) * df
    } else {
        t1 <- (X2 - df) * df.null
        t2 <- (X2.null - df.null) * df
    }

    if(df > 0 && abs(t2) > 0) {
        TLI <- 1 - t1/t2
    } else if(!is.finite(t1) || !is.finite(t2)) {
        TLI <- as.numeric(NA)
    } else {
       TLI <- 1
    }

    TLI
}

# alias for nnfi
lav_fit_nnfi <- lav_fit_tli

# RFI - relative fit index (Bollen, 1986; Joreskog & Sorbom 1993)
lav_fit_rfi <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL) {

    if(df > df.null) {
        RLI <- as.numeric(NA)
    } else if(df > 0 && df.null > 0) {
        t1 <- X2.null/df.null - X2/df
        t2 <- X2.null/df.null
        if(!is.finite(t1) || !is.finite(t2)) {
            RLI <- as.numeric(NA)
        } else if(t1 < 0 || t2 < 0) {
            RLI <- 1
        } else {
            RLI <- t1/t2
        }
    } else {
       RLI <- 1
    }

    RLI
}

# NFI - normed fit index (Bentler & Bonett, 1980)
lav_fit_nfi <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL) {

    if(df > df.null || isTRUE(all.equal(X2.null,0))) {
        NFI <- as.numeric(NA)
    } else if(df > 0) {
        t1 <- X2.null - X2
        t2 <- X2.null
        NFI <- t1/t2
    } else {
        NFI <- 1
    }

    NFI
}

# PNFI - Parsimony normed fit index (James, Mulaik & Brett, 1982)
lav_fit_pnfi <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL) {

    if(df.null > 0 && X2.null > 0) {
        t1 <- X2.null - X2
        t2 <- X2.null
        PNFI <- (df/df.null) * (t1/t2)
    } else {
        PNFI <- as.numeric(NA)
    }

    PNFI
}

# IFI - incremental fit index (Bollen, 1989; Joreskog & Sorbom, 1993)
lav_fit_ifi <- function(X2 = NULL, df = NULL, X2.null = NULL, df.null = NULL) {

    t1 <- X2.null - X2
    t2 <- X2.null - df
    if(!is.finite(t1) || !is.finite(t2)) {
        IFI <- as.numeric(NA)
    } else if(t2 < 0) {
        IFI <- 1
    } else if(isTRUE(all.equal(t2,0))) {
        IFI <- as.numeric(NA)
    } else {
        IFI <- t1/t2
    }

    IFI
}

# higher-level function
lav_fit_cfi_lavobject <- function(lavobject = NULL, fit.measures = "cfi",
                                  baseline.model = NULL,
                                  scaled = FALSE, test = "standard") {

    # check lavobject
    stopifnot(inherits(lavobject, "lavaan"))

    # test
    if(missing(test)) {
        test <- lav_utils_get_test(lavobject = lavobject)
        if(test[1] == "none") {
            return(list())
        }
    }

    # scaled?
    if(missing(scaled)) {
        scaled <- lav_utils_get_scaled(lavobject = lavobject)
    }

    # supported fit measures in this function
    # baseline model
    fit.baseline <- c("baseline.chisq", "baseline.df", "baseline.pvalue")
    if(scaled) {
        fit.baseline <- c(fit.baseline, "baseline.chisq.scaled",
                          "baseline.df.scaled", "baseline.pvalue.scaled",
                          "baseline.chisq.scaling.factor")
    }

    fit.cfi.tli <- c("cfi", "tli")
    if(scaled) {
        fit.cfi.tli <- c(fit.cfi.tli, "cfi.scaled", "tli.scaled",
                                      "cfi.robust", "tli.robust")
    }

    # other incremental fit indices
    fit.cfi.other <- c("nnfi", "rfi", "nfi", "pnfi", "ifi", "rni")
    if(scaled) {
        fit.cfi.other <- c(fit.cfi.other, "nnfi.scaled", "rfi.scaled",
                       "nfi.scaled", "pnfi.scaled", "ifi.scaled", "rni.scaled",
                       "nnfi.robust", "rni.robust")
    }

    # which one do we need?
    if(missing(fit.measures)) {
        # default set
        fit.measures <- c(fit.baseline, fit.cfi.tli)
    } else {
        # remove any not-CFI related index from fit.measures
        rm.idx <- which(!fit.measures %in%
                        c(fit.baseline, fit.cfi.tli, fit.cfi.other))
        if(length(rm.idx) > 0L) {
            fit.measures <- fit.measures[-rm.idx]
        }
        if(length(fit.measures) == 0L) {
            return(list())
        }
    }

    # robust?
    robust.flag <- FALSE
    if(scaled && test %in% c("satorra.bentler", "yuan.bentler.mplus",
                             "yuan.bentler")) {
        robust.flag <- TRUE
    }

    # basic test statistics
    TEST <- lavobject@test
    X2 <- TEST[[1]]$stat
    df <- TEST[[1]]$df
    G <- lavobject@Data@ngroups  # number of groups
    N <- lav_utils_get_ntotal(lavobject = lavobject) # N vs N-1

    # scaled X2
    if(scaled) {
        X2.scaled <- TEST[[2]]$stat
        df.scaled <- TEST[[2]]$df
        if(robust.flag) {
            c.hat <- TEST[[2]]$scaling.factor
        }
    }

    # output container
    indices <- list()

    # only do what is needed (per groups)
    cfi.baseline.flag <- cfi.tli.flag <- cfi.other.flag <- FALSE
    if(any(fit.baseline %in% fit.measures)) {
        cfi.baseline.flag <- TRUE
    }
    if(any(fit.cfi.tli %in% fit.measures)) {
        cfi.tli.flag <- TRUE
    }
    if(any(fit.cfi.other %in% fit.measures)) {
        cfi.other.flag <- TRUE
    }

    # 1. BASELINE model
    baseline.test <- NULL

    # we use the following priority:
    # 1. user-provided baseline model
    # 2. baseline model in @external slot
    # 3. baseline model in @baseline slot
    # 4. nothing -> compute independence model

    # 1. user-provided baseline model
    if( !is.null(baseline.model) ) {
        baseline.test <-
            lav_fit_measures_check_baseline(fit.indep = baseline.model,
                                            object    = lavobject)
    # 2. baseline model in @external slot
    } else if( !is.null(lavobject@external$baseline.model) ) {
        fit.indep <- lavobject@external$baseline.model
        baseline.test <-
            lav_fit_measures_check_baseline(fit.indep = fit.indep,
                                            object    = lavobject)
    # 3. internal @baseline slot
    } else if( .hasSlot(lavobject, "baseline") &&
               length(lavobject@baseline) > 0L &&
               !is.null(lavobject@baseline$test) ) {
        baseline.test <- lavobject@baseline$test
    # 4. (re)compute independence model
    } else {
        fit.indep <- try(lav_object_independence(lavobject), silent = TRUE)
        baseline.test <-
            lav_fit_measures_check_baseline(fit.indep = fit.indep,
                                            object    = lavobject)
    }

    if(!is.null(baseline.test)) {
        X2.null <- baseline.test[[1]]$stat
        df.null <- baseline.test[[1]]$df
        if(scaled) {
            X2.null.scaled <- baseline.test[[2]]$stat
            df.null.scaled <- baseline.test[[2]]$df
            if(robust.flag) {
                c.hat.null <- baseline.test[[2]]$scaling.factor
            }
        }
    } else {
        X2.null <- df.null <- as.numeric(NA)
        X2.null.scaled <- df.null.scaled <- as.numeric(NA)
        c.hat.null <- as.numeric(NA)
    }

    # check for NAs of nonfinite numbers
    if(!is.finite(X2) || !is.finite(df) ||
       !is.finite(X2.null) || !is.finite(df.null)) {
        indices[fit.measures] <- as.numeric(NA)
        return(indices)
    }

    # fill in baseline indices
    if(cfi.baseline.flag) {
        indices["baseline.chisq"]  <- X2.null
        indices["baseline.df"]     <- df.null
        indices["baseline.pvalue"] <- baseline.test[[1]]$pvalue
        if(scaled) {
            indices["baseline.chisq.scaled"]  <- X2.null.scaled
            indices["baseline.df.scaled"]     <- df.null.scaled
            indices["baseline.pvalue.scaled"] <- baseline.test[[2]]$pvalue
            indices["baseline.chisq.scaling.factor"] <-
                        baseline.test[[2]]$scaling.factor
        }
    }

    # 2. CFI and TLI
    if(cfi.tli.flag) {
        indices["cfi"] <- lav_fit_cfi(X2 = X2, df = df,
                                      X2.null = X2.null, df.null = df.null)
        indices["tli"] <- lav_fit_tli(X2 = X2, df = df,
                                      X2.null = X2.null, df.null = df.null)
        if(scaled) {
            indices["cfi.scaled"] <-
                lav_fit_cfi(X2 = X2.scaled, df = df.scaled,
                            X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["tli.scaled"] <-
                lav_fit_tli(X2 = X2.scaled, df = df.scaled,
                            X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["cfi.robust"] <- as.numeric(NA)
            indices["tli.robust"] <- as.numeric(NA)
            if(robust.flag) {
                indices["cfi.robust"] <-
                    lav_fit_cfi(X2 = X2, df = df,
                                X2.null = X2.null, df.null = df.null,
                                c.hat = c.hat, c.hat.null = c.hat.null)
                indices["tli.robust"] <-
                    lav_fit_tli(X2 = X2, df = df,
                                X2.null = X2.null, df.null = df.null,
                                c.hat = c.hat, c.hat.null = c.hat.null)
            }
        }
    }

    # 3. other
    # c("nnfi", "rfi", "nfi", "pnfi", "ifi", "rni")
    if(cfi.other.flag) {
        indices["nnfi"] <-
            lav_fit_nnfi(X2 = X2, df = df, X2.null = X2.null, df.null = df.null)
        indices["rfi"] <-
            lav_fit_rfi( X2 = X2, df = df, X2.null = X2.null, df.null = df.null)
        indices["nfi"] <-
            lav_fit_nfi( X2 = X2, df = df, X2.null = X2.null, df.null = df.null)
        indices["pnfi"] <-
            lav_fit_pnfi(X2 = X2, df = df, X2.null = X2.null, df.null = df.null)
        indices["ifi"] <-
            lav_fit_ifi( X2 = X2, df = df, X2.null = X2.null, df.null = df.null)
        indices["rni"] <-
            lav_fit_rni( X2 = X2, df = df, X2.null = X2.null, df.null = df.null)

        if(scaled) {
            indices["nnfi.scaled"] <-
                lav_fit_nnfi(X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["rfi.scaled"] <-
                lav_fit_rfi( X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["nfi.scaled"] <-
                lav_fit_nfi( X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["pnfi.scaled"] <-
                lav_fit_pnfi(X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["ifi.scaled"] <-
                lav_fit_ifi( X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            indices["rni.scaled"] <-
                lav_fit_rni( X2 = X2.scaled, df = df.scaled,
                             X2.null = X2.null.scaled, df.null = df.null.scaled)
            if(robust.flag) {
                indices["nnfi.robust"] <-
                    lav_fit_nnfi(X2 = X2, df = df,
                                 X2.null = X2.null, df.null = df.null,
                                 c.hat = c.hat, c.hat.null = c.hat.null)
                indices["rni.robust"] <-
                    lav_fit_rni(X2 = X2, df = df,
                                X2.null = X2.null, df.null = df.null,
                                c.hat = c.hat, c.hat.null = c.hat.null)
            }
        }
    }

    # return only those that were requested
    indices[fit.measures]
}


# new in 0.6-5
# internal function to check the (external) baseline model, and
# return baseline 'test' list if everything checks out (and NULL otherwise)
lav_fit_measures_check_baseline <- function(fit.indep = NULL, object = NULL) {

    TEST <- NULL

    # check if everything is in order
    if( inherits(fit.indep, "try-error") ) {
        warning("lavaan WARNING: baseline model estimation failed")
        return(NULL)

    } else if( !inherits(fit.indep, "lavaan") ) {
        warning("lavaan WARNING: (user-provided) baseline model ",
                "is not a fitted lavaan object")
        return(NULL)

    } else if( !fit.indep@optim$converged ) {
        warning("lavaan WARNING: baseline model did not converge")
        return(NULL)

    } else {

        # evaluate if estimator/test matches original object
        # note: we do not need to check for 'se', as it may be 'none'
        sameTest <- all(object@Options$test == fit.indep@Options$test)
        if(!sameTest) {
            warning("lavaan WARNING:\n",
                    "\t Baseline model was using test(s) = ",
                    dQuote(fit.indep@Options$test),
                    "\n\t But original model was using test(s) = ",
                    dQuote(object@Options$test),
                    "\n\t Refitting baseline model!")
        }
        sameEstimator <- ( object@Options$estimator ==
                           fit.indep@Options$estimator )
        if(!sameEstimator) {
            warning("lavaan WARNING:\n",
                    "\t Baseline model was using estimator = ",
                    dQuote(fit.indep@Options$estimator),
                    "\n\t But original model was using estimator = ",
                    dQuote(object@Options$estimator),
                    "\n\t Refitting baseline model!")
        }
        if( !sameTest || !sameEstimator ) {
            lavoptions <- object@Options
            lavoptions$estimator   <- object@Options$estimator
            lavoptions$se          <- "none"
            lavoptions$verbose     <- FALSE
            lavoptions$baseline    <- FALSE
            lavoptions$check.start <- FALSE
            lavoptions$check.post  <- FALSE
            lavoptions$check.vcov  <- FALSE
            lavoptions$test        <- object@Options$test
            fit.indep <- try(lavaan(fit.indep,
                                    slotOptions     = lavoptions,
                                    slotData        = object@Data,
                                    slotSampleStats = object@SampleStats,
                                    sloth1          = object@h1,
                                    slotCache       = object@Cache),
                             silent = TRUE)
            # try again
            TEST <- lav_fit_measures_check_baseline(fit.indep = fit.indep,
                                                    object    = object)

        } else {
            # extract what we need
            TEST <- fit.indep@test
        }

    } # converged lavaan object

    TEST
}



