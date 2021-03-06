rm(list=ls())
dname="spen.LBA"

source("rc/utils.R")
source("rc/fitting.R")
source("rc/DF-BNU2p.R")
source("rc/AA-2n.R")
source("rc/MP-BNU2-B2v.R")
library(hydra)
hydraInit(local=8,script.dir=".hydra")   
hydraSource("rc/utils.R")
hydraSource("rc/fitting.R")
hydraSource("rc/DF-BNU2p.R")
hydraSource("rc/AA-2n.R")
hydraSource("rc/MP-BNU2-B2v.R")

hydra.hfits(dname)
hydra.fix.fits(dname)
hydra.simdat(dname,sim.mult=100)
print(warnings())
