#!/usr/bin/env bash

################################################################################
# Sets up the ZooKeeper node for the simple Storm cluster on GCE. 
#
# See http://datadventures.markbox.io/2013/12/29/storm-on-gce for details. 
#
# Author: Michael Hausenblas
# Licence: Public Domain


################################################################################
# Configuration
#
ZK_DOWNLOAD_URL=http://apache.petsads.us/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz
LOG=/tmp/install_zk.log


################################################################################
#  Installs OpenJDK 6
function install_java() {
	echo "Installing Java ..." >> $LOG

	javacmd=`which java`
	if [ $? -eq 0 ] ;  then
		echo "Java is already installed on this instance, no further action required." >> $LOG
		java -version 2>&1 | head -1 >> $LOG
		jcmd=`python -c "import os; print os.path.realpath('$javacmd')"`
		if [ -x ${jcmd%/jre/bin/java}/bin/javac ] ; then
			JAVA_HOME=${jcmd%/jre/bin/java}
		elif [ -x ${jcmd%/java}/javac ] ; then
			JAVA_HOME=${jcmd%/java}
		else
			JAVA_HOME=""
		fi

		if [ -n "${JAVA_HOME:-}" ] ; then
			echo "	JAVA_HOME=$JAVA_HOME" | tee -a $LOG
			echo "updating /etc/profile.d/javahome.sh" >> $LOG
			echo "JAVA_HOME=${JAVA_HOME}" >> /etc/profile.d/javahome.sh
			echo "export JAVA_HOME" >> /etc/profile.d/javahome.sh
			return 0
		fi

		echo "Could not identify JAVA_HOME; will install Java myself." >> $LOG
	fi

  echo "Installing OpenJDK packages (for rpm distros)" >> $LOG

  sudo yum install -y java-1.6.0-openjdk.x86_64

  JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/jre
  export JAVA_HOME
  
  echo "	JAVA_HOME=$JAVA_HOME" >> $LOG

	if [ -x /usr/bin/java ] ; then
		echo "Java installation complete." >> $LOG

		if [ -n "${JAVA_HOME}" ] ; then
			echo "updating /etc/profile.d/javahome.sh" >> $LOG
			echo "JAVA_HOME=${JAVA_HOME}" >> /etc/profile.d/javahome.sh
			echo "export JAVA_HOME" >> /etc/profile.d/javahome.sh
		fi
	else
		echo "Java installation failed." >> $LOG
	fi
}

################################################################################
#  Installs ZooKeeper 3.4.5
function install_zk() {
	echo "Installing ZooKeeper ..." >> $LOG

  # download tarball into user home sub-directory and extract content
  cd ~
  curl -O ${ZK_DOWNLOAD_URL}
  tar -zxvf zookeeper-3.4.5.tar.gz

  echo "ZK downloaded and extracted." >> $LOG

  # change config settings
  cd zookeeper-3.4.5/conf
  # enable autopurge:
  sed 's/^#autopurge/autopurge/' zoo_sample.cfg > zoo.cfg.tmp
  # set data dir for ZK snapshots:
  sed 's/^dataDir=\/tmp\/zookeeper/dataDir=~\/zk-data/' zoo.cfg.tmp > zoo.cfg
  rm zoo.cfg.tmp
  
  echo "ZK settings adapted." >> $LOG

  # prep directories, env vars and other settings
  mkdir ~/zk-data
  cd /usr/local
  sudo mkdir zookeeper_install
  mv ~/zookeeper-3.4.5 /usr/local/
  sudo ln -s zookeeper-3.4.5 zookeeper
  export ZK_HOME=/usr/local/zookeeper/bin
  echo "ZK_HOME="$ZK_HOME >> ~/.bashrc
  source ~/.bashrc
  sudo service iptables save
  sudo service iptables stop
  echo "ZK installed in "$ZK_HOME
  
  echo "ZooKeeper installation completed." >> $LOG
  
}

################################################################################
# The main script
#
main() {
	echo "ZooKeeper node set up started at "`date`

  install_java
  install_zk

  # install launch scripts from Google Cloud Storage:
  mkdir ~/cluster
  gsutil cp gs://mhausenblas_storm/cluster* ~/cluster
  chmod 755 ~/cluster/*

	echo "ZooKeeper node set up done at "`date`  
	return 0
}

# allow ample time for the network and setup processes to settle before set up
sleep 10
main
exitCode=$?

exit $exitCode