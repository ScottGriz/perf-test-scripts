#!/bin/bash
 
# Simple PI using MonteCarlo 
(
  # Production, MR, 1TB sort, 100byte rows, 10m42.219s
  date
  echo "---------------------PI---------------------------------------"
  (
    readonly HADOOP_JAR=/opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar
    time sudo -u hdfs hadoop jar $HADOOP_JAR pi 10 100
  )
)
