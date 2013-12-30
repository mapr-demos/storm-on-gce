#!/usr/bin/env bash

################################################################################
# Sets up a Slave node for the simple Storm cluster on GCE. 
#
# See http://datadventures.markbox.io/2013/12/29/storm-on-gce for details. 
#
# Author: Michael Hausenblas
# Licence: Public Domain


################################################################################
# Configuration
#
ZMQ_DOWNLOAD_URL=https://github.com/downloads/saltstack/salt/zeromq-2.1.7-1.el6.x86_64.rpm
JZMQ_DOWNLOAD_URL=https://s3.amazonaws.com/cdn.michael-noll.com/rpms/jzmq-2.1.0.el6.x86_64.rpm
STORM_DOWNLOAD_URL=https://dl.dropboxusercontent.com/s/dj86w8ojecgsam7/storm-0.9.0.1.zip

STORM_CONFIG=/usr/local/storm/conf/storm.yaml
LOG=/tmp/install_slave.log


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

  JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk.x86_64
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
#  Installs Storm dependencies (ZeroMQ, etc.)
function install_storm_dep() {
	echo "Installing Storm dependencies ..." >> $LOG

  cd /tmp
  wget $ZMQ_DOWNLOAD_URL
  sudo yum install -y zeromq-2.1.7-1.el6.x86_64.rpm    
  wget $JZMQ_DOWNLOAD_URL
  sudo yum install -y jzmq-2.1.0.el6.x86_64.rpm
  
  echo "Storm dependencies installation completed." >> $LOG
}

################################################################################
#  Adds a dedicated Storm user
function add_storm_user() {
  echo "Adding Storm user ..." >> $LOG
  sudo groupadd -g 53001 storm
  sudo mkdir -p /app/home
  sudo useradd -u 53001 -g 53001 -d /app/home/storm -s /bin/bash storm -c "Storm service account"
  sudo chmod 700 /app/home/storm
  sudo chage -I -1 -E -1 -m -1 -M -1 -W -1 -E -1 storm
  echo "Adding Storm user done." >> $LOG
}

################################################################################
#  Installs Storm
function install_storm() {
  echo "Installing Storm ..." >> $LOG

  # download, extract and configure Storm
  cd /tmp
  curl -O $STORM_DOWNLOAD_URL
  cd /usr/local
  sudo unzip /tmp/storm-0.9.0.1.zip
  sudo chown -R storm:storm storm-0.9.0.1
  sudo ln -s storm-0.9.0.1 storm
  
  export STORM_HOME=/usr/local/storm/
  echo "STORM_HOME="$STORM_HOME >> ~/.bashrc
  source ~/.bashrc

  # set up storm.local.dir
  sudo mkdir -p /app/storm
  sudo chown -R storm:storm /app/storm
  sudo chmod 750 /app/storm
  
  sudo echo 'storm.zookeeper.servers:
    - "zk"

nimbus.host: "nimbus"
nimbus.childopts: "-Xmx1024m -Djava.net.preferIPv4Stack=true"

ui.childopts: "-Xmx768m -Djava.net.preferIPv4Stack=true"

supervisor.childopts: "-Djava.net.preferIPv4Stack=true"
worker.childopts: "-Xmx768m -Djava.net.preferIPv4Stack=true"

storm.local.dir: "/app/storm"' > $STORM_CONFIG
  
  sudo service iptables save
  sudo service iptables stop
  
  echo "Storm installation completed." >> $LOG
}


################################################################################
# The main script
#
main() {
	echo "Slave node set up started at "`date`
  
  install_java
  install_storm_dep
  
  add_storm_user
  install_storm
	
  # install launch scripts from Google Cloud Storage:
  sudo su - storm
  mkdir ~/cluster
  gsutil cp gs://mhausenblas_storm/cluster* ~/cluster
  chmod 755 ~/cluster/*
  
  echo "Slave node set up done at "`date`  
	return 0
}

# allow ample time for the network and setup processes to settle before set up
sleep 10
main
exitCode=$?

exit $exitCode