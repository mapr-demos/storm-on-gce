#!/usr/bin/env bash

################################################################################
# Launches Nimbus on GCE. 
#
# See http://datadventures.markbox.io/2013/12/29/storm-on-gce for details. 
#
# Author: Michael Hausenblas
# Licence: Public Domain

sudo su - storm
nohup /usr/local/storm/bin/storm ui &