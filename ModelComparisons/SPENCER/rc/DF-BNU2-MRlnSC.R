# LOGNORMAL NON-DECISION TIME, ANGLE EFFECTS SCALE 
# SPECIFIC TO MR PROJECT ASSUMING $A ANGLE FACTOR and $AS parameter (rate meanlog)
# $st0 is rate sdlog
# Orignal LBA version drifts can be negative

# Distribution random and start funcitons for ballistic normal drift uniform 
# start point two choice model (classic LBA)
#
# Start, distribution and random funcitons for ballistic normal drift uniform 
# start point two choice model (classic LBA)
# generic function names start=sfun PDF=dfun, CDF=pfun, random sample=rfun
# sfun called by mt.R, dfun and pfun by fitting.R, and rfun by simdat in latter

#pc=.01;aprior=.5;tertune=.9;Atune=.5;unitv=F;st0=.05

#st0 is shape parameter
sfun <-function(dati,pnams,pc=.01,
  aprior=.5,tertune=.9,Atune=.5,unitv=F,st0=1) {
# Generic LBA start routine for binary (correct/error) choice 
# Outputs standard b, A, v, sv, ter parameterization by adding columns to
# design attribute of dati (data from one "rlevls" cell with both correct 
# and error data) assuming:
#  Pr(error)=(num_err+aprior)/(num_resp+2*aprior)
#  Correct and error drift rates sum to one, vE = Pr(error)
#  Equal variance SDT sv (with 
#  ter = tertune * min(rt)
#  b = 2 * (mean_correct_rt-ter)/vC
#  A = b*Atune
  
  Di <- attr(dati,"D")
  minter <- as.numeric(dimnames(Di$nc)$minmax[1])*1.01
  # Define output
  ncols=5
  cnams <- c("b","A","v","sv","ter")
  if (any(pnams=="st0")) {
    cnams <- c(cnams,"st0")
    ncols <- ncols+1
  }
  if (any(pnams=="pc")) {
    cnams <- c(cnams,"pc")
    ncols <- ncols+1
  }
  LBAstarts <- matrix(nrow=dim(Di$D)[1],ncol=ncols)
  dimnames(LBAstarts) <- list(NULL,cnams)    
  # identify respone levels
  rlevs <- as.numeric(levels(dati$rcell))
  for (i in rlevs) {
    # get data for current response level
    datii <- dati[dati$rcell==i,]
    # get cells that correspond to current response level
    tmp <- as.numeric(row.names(Di$D))[Di$D$rcell==i]
    Cname <- Di$SC[1] # ASSUMES FIRST SC SCORES CORRECT
    # identify cells for correct and error responses
    cc <- tmp[as.logical(Di$D[tmp,Cname])] 
    ec <- tmp[!as.logical(Di$D[tmp,Cname])]
    # robust proportion correct 
    Pc <- (sum(as.logical(datii[,Cname]))+aprior)/(dim(datii)[1]+2*aprior)
    # relevant RTs
    rt <- datii[,Di$RT]
    # heuristics for v bounded 0-1
    vC <- Pc 
    vE <- 1-Pc 
    sv <- (vE-vC)/(2*qnorm(1-Pc))  
    if (!is.finite(sv)) sv <- 1    #########################
    ter <- pmax(tertune*min(rt[rt>minter])-st0,minter)
    b <- (mean(rt[as.logical(datii[[Cname]])]-ter)*vC)/(1-Atune)
    A <- b*Atune
    if (!unitv) {
      vC <- vC/sv
      vE <- vE/sv
      sv <- 1
    }
    nacc=length(cc)
    cc.cols <- cbind(rep(b,nacc),rep(A,nacc),rep(vC,nacc),
      rep(sv,nacc),rep(ter,nacc))
    nerr=length(ec)
    ec.cols <- cbind(rep(b,nerr),rep(A,nerr),rep(vE,nerr),
      rep(sv,nerr),rep(ter,nerr))  
    if (any(pnams=="st0")) {
      cc.cols <- cbind(cc.cols,rep(st0,nacc))
      ec.cols <- cbind(ec.cols,rep(st0,nerr))
    }
    if (any(pnams=="pc")) {
      cc.cols <- cbind(cc.cols,rep(pc,nacc))
      ec.cols <- cbind(ec.cols,rep(pc,nerr))
    }
    LBAstarts[cc,] <- cc.cols
    LBAstarts[ec,] <- ec.cols
  }
  M2P(data.frame(LBAstarts))
}


dfun=function(t,parlist,cv=NULL) {  
  # Defective PDF for responses on node 1 
  # st0>0: adds t0 variability convolution by numerical integration.
  # If length ter or st0 >1, first value used for all, other values ignored

  ################# SINGLE UNIT FUNCTIONS

  # protected normal desity and cdf
  pnormP <- function(x,mean,sd,lower.tail=F){ifelse(abs(x)<7,pnorm(x),ifelse(x<0,0,1))}  
  dnormP <- function(x,mean,sd,lower.tail=F){ifelse(abs(x)<7,dnorm(x),0)}
  
  fptpdf=function(z,A,b,v,sv) {
    # pdf for a single unit
    if (A<1e-10) # LATER solution 
      return(pmax(0,((b/z^2)*dnormP(b/z,mean=v,sd=sv)))) # posdrifts
    zs=z*sv ; zu=z*v ; bminuszu=b-zu
    bzu=bminuszu/zs ; bzumax=(bminuszu-A)/zs
    pmax(0,((v*(pnormP(bzu)-pnormP(bzumax)) +
             sv*(dnormP(bzumax)-dnormP(bzu)))/A)) # posdrifts
  }
  
  fptcdf=function(z,A,b,v,sv) {
    # cdf for a single unit
    if (A<1e-10) # LATER solution 
      return(pmin(1,pmax(0,(pnormP(b/z,mean=v,sd=sv,lower.tail=F))))) # posdrifts
    zs=z*sv ; zu=z*v ; bminuszu=b-zu ; xx=bminuszu-A
    bzu=bminuszu/zs ; bzumax=xx/zs
    tmp1=zs*(dnormP(bzumax)-dnormP(bzu))
    tmp2=xx*pnormP(bzumax)-bminuszu*pnormP(bzu)
    pmin(pmax(0,(1+(tmp1+tmp2)/A)),1) # posdrifts
  }

  n1PDFfixedt0=function(t,A,b,v,sv) {
    # Generates defective PDF for responses on node #1.
    N <- length(v) # Number of responses.
    if (N>2) {
      tmp <- array(dim=c(length(t),N-1))
      for (i in 2:N) tmp[,i-1] <-
        fptcdf(z=t,A=A[i],b=b[i],v=v[i],sv=sv[i])
      G <- apply(1-tmp,1,prod)
    } else {
      G <- 1-fptcdf(z=t,A=A[2],b=b[2],v=v[2],sv=sv[2])
    }
    out <- G*fptpdf(z=t,A=A[1],b=b[1],v=v[1],sv=sv[1])
    out[t<=0 | !is.finite(out)] <- 0
    out
  }
  
  t <- t-parlist$ter[1]
  if ( !any(names(parlist)=="st0") || parlist$scale[1] < -10  || parlist$st0[1]==0) { 
    return(n1PDFfixedt0(t,
      A=parlist$A,b=parlist$b,v=parlist$v,sv=parlist$sv))
  } else {
    tmpf <- function(tau,ti0,A,b,v,sv,scale,shape) 
      n1PDFfixedt0(tau,A,b,v,sv)*dlnorm(ti0-tau,sdlog=shape,meanlog=scale)
    outs <- numeric(length(t))
    for (i in c(1:length(outs))) {
      tmp <- try(integrate(f=tmpf,
        lower=0,upper=t[i],ti0=t[i],
        A=parlist$A,b=parlist$b,v=parlist$v,sv=parlist$sv,
        scale=parlist$scale[1],shape=parlist$st0[1])$value,silent=T)
      if (is.numeric(tmp)) 
        outs[i] <- tmp else
        outs[i] <- 0
    }
    return(outs)
  }
}

# t=dati[is.finite(dati[,D$RT]),D$RT]
# doCDF=F
# parlist=list(A=p$A[isin],b=p$b[isin],v=p$v[isin],
#   sv=p$sv[isin],ter=p$ter[isin],st0=p$st0[isin])
pfun=function(t,parlist,doCDF=T,cv=NULL) {
  # Defective CDF for responses on node 1
  # doCDF=F returns inter-t probabilities
  # assumes t is sorted in increasing order with no ties

  outs <- numeric(length(t))
  bad <- t-parlist$ter[1]<=0
  if (all(bad)) return(outs)
  bounds <- c(0,t[!bad]) # Must be at least two as largest t is Inf
  badoffset <- sum(bad)
  if (any(names(parlist)=="st0") && parlist$scale[1]<1e-6)
    parlist$scale[1] <- 0 # integral of intergal can fail for scale small
  for (i in 1:(length(bounds)-1)) {
    tmp="error"
    repeat {
      if (bounds[i]>=bounds[i+1]) {
        outs[i+badoffset] <- 0
        break
      }       
      tmp=try(integrate(f=dfun,lower=bounds[i],upper=bounds[i+1],
        parlist=parlist)$value,silent=T)
      if (is.numeric(tmp)) {
        outs[i+badoffset] <- tmp
        break
      }
      # Try smart lower bound.
      if (bounds[i]<=0) {
		    bounds[i] <- max(c((parlist$b-0.98*parlist$A)/
		      (max(mean(parlist$v),parlist$v[1])+2*parlist$sv),1e-10))
		    next
      }
      # Try smart upper bound.
      if (bounds[i+1]==Inf) {
		    bounds[i+1] <- max(0.02*parlist$b/
          (mean(parlist$v)-2*parlist$sv))
		    next
      }
      return(rep(0,length(outs)))
    }
  }
  if (doCDF) cumsum(outs) else outs
}

# ns=nsim;pi=p[isin,]; sim.mult=NA
# onen=1e4;maxsamp=1e6;warn=T;cv=NULL;remove.outliers=TRUE
rfun=function(ns,pi,tlohi,onen=1e4,maxsamp=1e6,warn=T,cv=NULL,sim.mult=NA,remove.outliers=TRUE) {
# PARAMETERS
#   ns: number of RTs for each response
#   pi: data frame with columns ter, v sv, b and A (at least), one row per accumulator
#   tlohi: lower and upper limits of uniform contaminant
#   onen: number to simulate per loop
#   maxsamp: limit on number of samples to take before giving up
# RETURN list with named elements 
#   rt: matrix[ns rows per choice,contaminate=0/1,choice=1:number of accumulators,rt]
#   n: number samples for each accumulator
  
  # take 5% more than biggest per cycle
  if (max(ns)<onen) onen <- round(max(ns)*1.05)
  nacc <- dim(pi)[1]
  RT <- matrix(ncol=sum(ns),nrow=3)
  Ns <- numeric(nacc)
  nsamp <- 0
  Ni <- 0
  full2col <- 0
  if ( !is.na(sim.mult) ) { # simulated subjects information
    n1 <- sum(ns)/sim.mult
    sim <- vector(mode="list",length=sim.mult)
    repn <- 0
  } else sim=NULL  
  repeat {
    nsamp <- nsamp + onen # number of samples taken
    rts <- matrix(rnorm(nacc*onen,pi$v,pi$sv),nrow=nacc) # actually v
    # remove all neg v
    Ni <- dim(rts)[2] # maybe < onen left 
    if ( Ni>0 ) {
      rts <- (pi$b-runif(nacc*Ni,0,pi$A))/rts # divide by v
      rts[rts<0] <- Inf # negative drifts imply never complete
      rts <- rts+pi$ter # will allow different ter for each response
      # pick the smallest
      win <- apply(rts,2,function(x){m=which.min(x);c(m,x[m])}) 
      # t0 noise
      if ( any(names(pi)=="st0") ) 
        if (pi$st0[1]>1e-3) # greater than 1ms 
          win[2,] <- win[2,] + rlnorm(Ni,sdlog=pi$st0[1],meanlog=pi$scale[1])
      if ( remove.outliers ) {
        bad <- win[2,] <= tlohi[1] | win[2,] >= tlohi[2]
        win <- win[,!bad]
      }       
      Ni <- dim(win)[2]  
      # contaminate
      if ( any(names(pi)=="pc") )
        win <- rbind(rbinom(Ni,1,pi$pc[1]),win) else
        win <- rbind(rep(0,Ni),win)
      if (any(as.logical(win[1,]))) { # contaminated
        win[2,as.logical(win[1,])] <- sample(nacc,sum(win[1,]),T)            # choice
        win[3,as.logical(win[1,])] <- runif(sum(win[1,]),tlohi[1],tlohi[2])  # rt
      }
      # number of each choice to add
      Nsi <- as.vector(table(factor(win[2,],1:nacc))) 
      nadd <- ns-Ns # number left to reach ns
      toadd <- !logical(Ni) 
      for (i in 1:nacc) { # set toadd to T for first nadd choices
        isi <- win[2,]==i
        if (any(isi)) toadd[isi] <- c(1:sum(isi))<=nadd[i]
      }
      endcol <- full2col+sum(toadd) # insert into RT
      if (endcol>full2col) # Is there something to add?
        RT[,(full2col+1):(endcol)] <- win[,toadd]
      full2col <- endcol
      Ns <- Ns + Nsi # number inserted
      if ( !is.null(sim) && (repn <= sim.mult) ) {
        sims <- data.frame(t(win))
        names(sims) <- c("contam","r","rt")
        sims$r <- factor(sims$r,levels=1:length(ns),labels=names(ns))
        navail <- pmin(dim(sims)[1] %/% n1,length(sim)-repn)
        if (navail>0) for (i in 1:navail) {
          sim[[repn+i]] <- sims[(((i-1)*n1)+1):(i*n1),]
        }
        repn <- repn+navail
      }  
    }
    if ( ( (!is.null(sim) & (repn >= sim.mult)) & all(Ns >= ns) ) | nsamp >= maxsamp) break
  }
  if ( warn && nsamp > maxsamp )
    warning(paste("Unable to get sufficient samples. Required =",
                  paste(ns,collapse=" "),"Obtained =",paste(Ns,collapse=" ")))
  names(Ns) <- names(ns)
  list(n=Ns,rt=cbind(contaminate=RT[1,],choice=RT[2,],rt=RT[3,]),sims=sim)
}

# A=c(1,1); b=c(2,2); vC=c(2,1); vE=c(1,2); svC=c(.5,.5); svE=c(.5,.5); ter=c(.1,.1); st0=c(.05,.05)
# parlistC=list(A=A,b=b,v=vC,sv=svC,ter=ter)
# parlistE=list(A=A,b=b,v=vE,sv=svE,ter=ter)
# parlistCst=list(A=A,b=b,v=vC,sv=svC,ter=ter,st0=st0,scale=-2)
# parlistEst=list(A=A,b=b,v=vE,sv=svE,ter=ter,st0=st0,scale=-2)
# 
# x=c(1:300)/100; par(mfcol=c(1,2))
# plot(x,dfun(t=x,parlistC),type="l");abline(h=0)
# lines(x,dfun(t=x,parlistCst),col="red")
# plot(x,dfun(t=x,parlistE),type="l");abline(h=0)
# lines(x,dfun(t=x,parlistEst),col="red")
# print(pfun(Inf,parlistC)+pfun(Inf,parlistE))
# print(pfun(Inf,parlistCst)+pfun(Inf,parlistEst))
# 
# par(mfcol=c(1,2))
# tmp=rfun(ns=c(a=1e5,b=1e4),pi=data.frame(parlistCst),tlohi=c(0,100),sim.mult=10)
# pc <- tmp$n[1]/sum(tmp$n)
# pce=pfun(Inf,parlistCst)
# c(pc,pce,pc-pce)
# plot(x,dfun(t=x,parlistCst),type="l");abline(h=0)
# dns <- density(tmp$rt[tmp$rt[,"choice"]==1,"rt"])
# dns$y <- dns$y*pc
# lines(dns,col="red")
# plot(x,dfun(t=x,parlistEst),type="l");abline(h=0)
# dns <- density(tmp$rt[tmp$rt[,"choice"]==2,"rt"])
# dns$y <- dns$y*(1-pc)
# lines(dns,col="red")
