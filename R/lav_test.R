# chi-square test statistic:
# comparing the current model versus the saturated/unrestricted model

lavTest <- function(lavobject, test = "standard", output = "list",
                    drop.list.single = TRUE) {

    # check output
    if(!output %in% c("list", "text")) {
        stop("lavaan ERROR: output should be list or text")
    }

    TEST.NAMES <- c("standard",
                    "satorra.bentler", "yuan.bentler","yuan.bentler.mplus",
                    "mean.var.adjusted", "scaled.shifted",
                    "browne.residual.adf", "browne.residual.nt")

    # extract 'test' slot
    TEST <- lavobject@test

    # which test?
    if(!missing(test)) {
        # check 'test'
        if(!is.character(test)) {
            stop("lavaan ERROR: test should be a character string.")
        } else {
            test <- lav_test_rename(test)
        }

        if(test[1] == "none") {
            return(list())
        } else if(any(test %in% c("bootstrap", "bollen.stine"))) {
            stop("lavaan ERROR: please use bootstrapLavaan() to obtain a bootstrap based test statistic.")
        }
        if(!all(test %in% TEST.NAMES)) {
            bad.idx <- which(!test %in% TEST.NAMES)
            txt <- c("invalid name for test statistic: [", test[bad.idx[1]],
                     "]. Valid names are:\n",
                     paste(TEST.NAMES, collapse = " "))
            stop(lav_txt2message(txt, header = "lavaan ERROR:"))
        }

        # check if we already have it:
        if(all(test %in% names(TEST))) {
            test.idx <- which(names(TEST) %in% test)
            TEST <- TEST[test.idx]
        } else {
            # redo ALL of them, even if already have some in TEST
            # later, we will allow to also change the options (like information)
            # and this should be reflected in the 'info'attribute

            # fill in test in Options slot
            lavobject@Options$test <- test

            # get requested test statistics
            TEST <- lav_model_test(lavobject = lavobject)
        }
    }

    if(output == "list") {
        # remove 'info' attribute
        attr(TEST, "info") <- NULL

        # select only those that were requested (eg remove standard)
        test.idx <- which(names(TEST) %in% test)
        TEST <- TEST[test.idx]

        # if only 1 test, drop outer list
        if(length(TEST) == 1L && drop.list.single) {
            TEST <- TEST[[1]]
        }

        return(TEST)
    } else {
        lav_test_print(TEST)
    }

    invisible(TEST)
}

# allow for 'flexible' names for the test statistics
lav_test_rename <- function(test) {

    test <- tolower(test)

    if(length(target.idx <- which(test %in%
        c("satorra", "sb", "satorra.bentler", "satorra-bentler",
          "m.adjusted", "m", "mean.adjusted", "mean-adjusted"))) > 0L) {
        test[target.idx] <- "satorra.bentler"
    }
    if(length(target.idx <- which(test %in%
        c("yuan", "yb", "yuan.bentler", "yuan-bentler"))) > 0L) {
        test[target.idx] <- "yuan.bentler"
    }
    if(length(target.idx <- which(test %in%
        c("yuan.bentler.mplus", "yuan-bentler.mplus",
          "yuan-bentler-mplus"))) > 0L) {
        test[target.idx] <- "yuan.bentler.mplus"
    }
    if(length(target.idx <- which(test %in%
        c("mean.var.adjusted", "mean-var-adjusted", "mv", "second.order",
          "satterthwaite", "mv.adjusted"))) > 0L) {
        test[target.idx] <- "mean.var.adjusted"
    }
    if(length(target.idx <- which(test %in%
        c("mplus6", "scale.shift", "scaled.shifted",
          "scaled-shifted"))) > 0L) {
        test[target.idx] <- "scaled.shifted"
    }
    if(length(target.idx <- which(test %in%
        c("bootstrap", "boot", "bollen.stine", "bollen-stine"))) > 0L) {
        test[target.idx] <- "bollen.stine"
    }
    if(length(target.idx <- which(test %in%
        c("browne", "residual", "residuals", "browne.residual",
          "browne.residuals", "residual-based", "residual.based",
          "browne.residuals.adf", "browne.residual.adf"))) > 0L) {
        test[target.idx] <- "browne.residual.adf"
    }
    if(length(target.idx <- which(test %in%
        c("browne.residuals.nt", "browne.residual.nt"))) > 0L) {
        test[target.idx] <- "browne.residual.nt"
    }

    test
}

lav_model_test <- function(lavobject      = NULL,
                           lavmodel       = NULL,
                           lavpartable    = NULL,
                           lavpta         = NULL,
                           lavsamplestats = NULL,
                           lavimplied     = NULL,
                           lavh1          = list(),
                           lavoptions     = NULL,
                           x              = NULL,
                           VCOV           = NULL,
                           lavcache       = NULL,
                           lavdata        = NULL,
                           lavloglik      = NULL,
                           test.UGamma.eigvals = FALSE) {

    # lavobject?
    if(!is.null(lavobject)) {
        lavmodel       <- lavobject@Model
        lavpartable    <- lavobject@ParTable
        lavpta         <- lavobject@pta
        lavsamplestats <- lavobject@SampleStats
        lavimplied     <- lavobject@implied
        lavh1          <- lavobject@h1
        lavoptions     <- lavobject@Options
        x              <- lavobject@optim$x
            fx                   <- lavobject@optim[["fx"]]
            fx.group             <- lavobject@optim[["fx.group"]]
            attr(fx, "fx.group") <- fx.group
            attr(x, "fx")        <- fx
        VCOV           <- lavobject@vcov$vcov
        lavcache       <- lavobject@Cache
        lavdata        <- lavobject@Data
        lavloglik      <- lavobject@loglik
    }

    test <- lavoptions$test

    TEST <- list()

    # degrees of freedom (ignoring constraints)
    df <- lav_partable_df(lavpartable)

    # handle equality constraints (note: we ignore inequality constraints,
    # active or not!)
    # we use the rank of con.jac (even if the constraints are nonlinear)
    if(nrow(lavmodel@con.jac) > 0L) {
        ceq.idx <- attr(lavmodel@con.jac, "ceq.idx")
        if(length(ceq.idx) > 0L) {
            neq <- qr(lavmodel@con.jac[ceq.idx,,drop=FALSE])$rank
            df <- df + neq
        }
    } else if(lavmodel@ceq.simple.only) {
        # needed??
        ndat <- lav_partable_ndat(lavpartable)
        npar <- max(lavpartable$free)
        df <- ndat - npar
    }

    # shortcut: return empty list if one of the conditions below is true:
    # - test == "none"
    # - df < 0
    # - estimator == "MML"
    if(test[1] == "none" || df < 0L || lavoptions$estimator == "MML") {

        TEST[[1]] <- list(test       = test[1],
                          stat       = as.numeric(NA),
                          stat.group = as.numeric(NA),
                          df         = df,
                          refdistr   = "unknown",
                          pvalue     = as.numeric(NA))

        if(length(test) > 1L) {
            TEST[[2]] <- list(test       = test[2],
                              stat       = as.numeric(NA),
                              stat.group = as.numeric(NA),
                              df         = df,
                              refdistr   = "unknown",
                              pvalue     = as.numeric(NA))
        }

        attr(TEST, "info") <-
        list(ngroups = lavdata@ngroups, group.label = lavdata@group.label,
             information = lavoptions$information,
             h1.information = lavoptions$h1.information,
             observed.information = lavoptions$observed.information)

        return(TEST)
    }


    ######################
    ## TEST == STANDARD ##
    ######################

    # get chisq value, per group

    # PML
    if(lavoptions$estimator == "PML" && test[1] != "none") {

        # attention!
        # if the thresholds are saturated (ie, nuisance parameters)
        # we should use the ctr_pml_plrt() function.
        #
        # BUT, if the thresholds are structured (eg equality constraints)
        # then we MUST use the ctr_pml_plrt2() function.
        #
        # This was not done automatically < 0.6-6
        #


        thresholds.structured <- FALSE
        # check
        th.idx <- which(lavpartable$op == "|")
        if(any(lavpartable$free[th.idx] == 0L)) {
            thresholds.structured <- TRUE
        }

        eq.idx <- which(lavpartable$op == "==")
        if(length(eq.idx) > 0L) {
            th.labels <- lavpartable$plabel[th.idx]
            eq.labels <- unique(c(lavpartable$lhs[eq.idx],
                                  lavpartable$rhs[eq.idx]))
            if(any(th.labels %in% eq.labels)) {
                thresholds.structured <- TRUE
            }
        }

        # switch between ctr_pml_plrt() and ctr_pml_plrt2()
        if(thresholds.structured) {
            pml_plrt <- ctr_pml_plrt2
        } else {
            pml_plrt <- ctr_pml_plrt
        }

        PML <- pml_plrt(lavobject      = NULL,
                        lavmodel       = lavmodel,
                        lavdata        = lavdata,
                        lavoptions     = lavoptions,
                        lavpta         = lavpta,
                        x              = x,
                        VCOV           = VCOV,
                        lavcache       = lavcache,
                        lavsamplestats = lavsamplestats,
                        lavpartable    = lavpartable)
        # get chi.group from PML, since we compare to `unrestricted' model,
        # NOT observed data
        chisq.group <- PML$PLRTH0Sat.group

    # twolevel
    } else if(lavdata@nlevels > 1L) {

        if(length(lavh1) > 0L) {
            # LRT
            chisq.group <- -2 * (lavloglik$loglik.group - lavh1$loglik.group)
        } else {
            chisq.group <- rep(as.numeric(NA), lavdata@ngroups)
        }

    } else {
        # get fx.group
        fx <- attr(x, "fx")
        fx.group <- attr(fx, "fx.group")

        # always compute `standard' test statistic
        ## FIXME: the NFAC is now implicit in the computation of fx...
        NFAC <- 2 * unlist(lavsamplestats@nobs)
        if(lavoptions$estimator == "ML" && lavoptions$likelihood == "wishart") {
            # first divide by two
            NFAC <- NFAC / 2; NFAC <- NFAC - 1; NFAC <- NFAC * 2
        } else if(lavoptions$estimator == "DLS") {
            NFAC <- NFAC / 2; NFAC <- NFAC - 1; NFAC <- NFAC * 2
        }

        chisq.group <- fx.group * NFAC
    }

    # check for negative values
    chisq.group[ chisq.group < 0 ] <- 0.0

    # global test statistic
    chisq <- sum(chisq.group)

    # reference distribution: always chi-square, except for the
    # non-robust version of ULS and PML
    if(lavoptions$estimator == "ULS" || lavoptions$estimator == "PML") {
        refdistr <- "unknown"
        pvalue <- as.numeric(NA)
    } else {
        refdistr <- "chisq"

        # pvalue  ### FIXME: what if df=0? NA? or 1? or 0?
        # this is not trivial, since
        # 1 - pchisq(0, df=0) = 1
        # but
        # 1 - pchisq(0.00000000001, df=0) = 0
        # and
        # 1 - pchisq(0, df=0, ncp=0) = 0
        #
        # This is due to different definitions of limits (from the left,
        # or from the right)
        #
        # From 0.5-17 onwards, we will use NA if df=0, to be consistent
        if(df == 0) {
            pvalue <- as.numeric(NA)
        } else {
            pvalue <- 1 - pchisq(chisq, df)
        }
    }

    TEST[["standard"]] <- list(test       = "standard",
                               stat       = chisq,
                               stat.group = chisq.group,
                               df         = df,
                               refdistr   = refdistr,
                               pvalue     = pvalue)

    if(length(test) == 1L && test == "standard") {
        # we are done
        attr(TEST, "info") <-
        list(ngroups = lavdata@ngroups, group.label = lavdata@group.label,
             information = lavoptions$information,
             h1.information = lavoptions$h1.information,
             observed.information = lavoptions$observed.information)
        return(TEST)
    } else {
        # strip 'standard' from test list
        if(length(test) > 1L) {
            standard.idx <- which(test == "standard")
            if(length(standard.idx) > 0L) {
                test <- test[-standard.idx]
            }
        }
    }




    ######################
    ## additional tests ## # new in 0.6-5
    ######################

    for(this.test in test) {

        if(lavoptions$estimator == "PML") {
            if(this.test == "mean.var.adjusted") {
                LABEL <- "mean+var adjusted correction (PML)"
                TEST[[this.test]] <-
                    list(test                 = this.test,
                         stat                 = PML$stat,
                         stat.group           = TEST[[1]]$stat.group*PML$scaling.factor,
                         df                   = PML$df,
                         pvalue               = PML$p.value,
                         scaling.factor       = 1/PML$scaling.factor,
                         label                = LABEL,
                         shift.parameter      = as.numeric(NA),
                         trace.UGamma         = as.numeric(NA),
                         trace.UGamma4        = as.numeric(NA),
                         trace.UGamma2        = as.numeric(NA),
                         UGamma.eigenvalues   = as.numeric(NA))
            } else {
                warning("test option ", this.test,
                        " not available for estimator PML")
            }



        } else if(this.test %in% c("satorra.bentler",
                                   "mean.var.adjusted",
                                   "scaled.shifted")) {

            out <- lav_test_satorra_bentler(lavobject = NULL,
                             lavsamplestats = lavsamplestats,
                             lavmodel       = lavmodel,
                             lavimplied     = lavimplied,
                             lavdata        = lavdata,
                             lavoptions     = lavoptions,
                             TEST.unscaled  = TEST[[1]],
                             E.inv          = attr(VCOV, "E.inv"),
                             Delta          = attr(VCOV, "Delta"),
                             WLS.V          = attr(VCOV, "WLS.V"),
                             Gamma          = attr(VCOV, "Gamma"),
                             test           = this.test,
                             mimic          = lavoptions$mimic,
                             method         = "original", # since 0.6-13
                             return.ugamma  = FALSE)
            TEST[[this.test]] <- out[[this.test]]

        } else if(this.test %in% c("browne.residual.adf",
                                   "browne.residual.nt")) {

            ADF <- TRUE
            if(this.test == "browne.residual.nt") {
                ADF <- FALSE
            }
            out <- lav_test_browne(lavobject      = NULL,
                                   lavdata        = lavdata,
                                   lavsamplestats = lavsamplestats,
                                   lavmodel       = lavmodel,
                                   lavoptions     = lavoptions,
                                   ADF            = ADF)
            TEST[[this.test]] <- out

        } else if(this.test %in% c("yuan.bentler",
                                   "yuan.bentler.mplus")) {

            out <- lav_test_yuan_bentler(lavobject = NULL,
                             lavsamplestats = lavsamplestats,
                             lavmodel       = lavmodel,
                             lavdata        = lavdata,
                             lavimplied     = lavimplied,
                             lavh1          = lavh1,
                             lavoptions     = lavoptions,
                             TEST.unscaled  = TEST[[1]],
                             E.inv          = attr(VCOV, "E.inv"),
                             B0.group       = attr(VCOV, "B0.group"),
                             test           = this.test,
                             mimic          = lavoptions$mimic,
                             #method         = "default",
                             return.ugamma  = FALSE)
            TEST[[this.test]] <- out[[this.test]]

        } else if(this.test == "bollen.stine") {

            # check if we have bootstrap lavdata
            BOOT.TEST <- attr(VCOV, "BOOT.TEST")
            if(is.null(BOOT.TEST)) {
                if(!is.null(lavoptions$bootstrap)) {
                    R <- lavoptions$bootstrap
                } else {
                    R <- 1000L
                }
                boot.type <- "bollen.stine"
                BOOT.TEST <-
                    lav_bootstrap_internal(object          = NULL,
                                           lavmodel.       = lavmodel,
                                           lavsamplestats. = lavsamplestats,
                                           lavpartable.    = lavpartable,
                                           lavoptions.     = lavoptions,
                                           lavdata.        = lavdata,
                                           R               = R,
                                           verbose         = lavoptions$verbose,
                                           type            = boot.type,
                                           FUN             = "test")

                # new in 0.6-12: always warn for failed and nonadmissible
                error.idx <- attr(BOOT.TEST, "error.idx")
                nfailed <- length(attr(BOOT.TEST, "error.idx")) # zero if NULL
                if(nfailed > 0L && lavoptions$warn) {
                    warning("lavaan WARNING: ", nfailed,
                            " bootstrap runs failed or did not converge.")
                }

                notok <- length(attr(BOOT.TEST, "nonadmissible")) # zero if NULL
                if(notok > 0L && lavoptions$warn) {
                    warning("lavaan WARNING: ", notok,
                        " bootstrap runs resulted in nonadmissible solutions.")
                }

                if(length(error.idx) > 0L) {
                    # new in 0.6-13: we must still remove them!
                    BOOT.TEST <- BOOT.TEST[-error.idx,,drop = FALSE]
                    # this also drops the attributes
                }

                BOOT.TEST <- drop(BOOT.TEST)
            }

            # bootstrap p-value
            boot.larger <- sum(BOOT.TEST > chisq)
            boot.length <- length(BOOT.TEST)
            pvalue.boot <- boot.larger/boot.length

            TEST[[this.test]] <- list(test        = this.test,
                                      stat        = chisq,
                                      stat.group  = chisq.group,
                                      df          = df,
                                      pvalue      = pvalue.boot,
                                      refdistr    = "bootstrap",
                                      boot.T      = BOOT.TEST,
                                      boot.larger = boot.larger,
                                      boot.length = boot.length)
        }

    } # additional tests

    # add additional information as an attribute, needed for independent
    # printing
    attr(TEST, "info") <-
        list(ngroups = lavdata@ngroups, group.label = lavdata@group.label,
             information = lavoptions$information,
             h1.information = lavoptions$h1.information,
             observed.information = lavoptions$observed.information)

    TEST
}


