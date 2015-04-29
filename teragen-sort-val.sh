#!/bin/bash
 
# TeraGen: 1TB = 100BYTE * 10,000,000,000 = 1e2 * 1e10 = 1,000,000,000,000 = 1e12
# hadoop jar hadoop-*examples*.jar teragen <number of 100-byte rows> <output dir>
#hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-examples.jar teragen -Dmapred.compress.map.output=false -Dmapred.map.tasks=112 10000000000 /user/hdfs/terasort-input 
#hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-examples.jar terasort /user/hdfs/terasort-input /user/hdfs/terasort-output
#hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce/hadoop-examples.jar teravalidate /user/hdfs/terasort-output /user/hdfs/terasort-validate
 
#The following can be used to repeat the terasort benchmark for production.
(
  # Production, MR, 1TB sort, 100byte rows, 10m42.219s
  date
  echo "---------------------gen---------------------------------------"
  (
    export EXDIR=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce
    su - hdfs -c "hadoop fs -rm -R -skipTrash in-dir1TB"
    time su - hdfs -c "hadoop jar ${EXDIR}/hadoop-examples.jar teragen -Dmapred.compress.map.output=false -Dmapred.map.tasks=112 10000000000 in-dir1TB"
  )
  date
  echo "---------------------sort---------------------------------------"
  (
    export EXDIR=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce
    su - hdfs -c "hadoop fs -rm -R -skipTrash out-dir1TB"
    date
    time su - hdfs -c "hadoop jar ${EXDIR}/hadoop-examples.jar terasort in-dir1TB out-dir1TB"
    date
  )
  date
  echo "---------------------validate---------------------------------------"
  (
    export EXDIR=/opt/cloudera/parcels/CDH/lib/hadoop-0.20-mapreduce
    su - hdfs -c "hadoop fs -rm -R -skipTrash out-dir1TBVal"
    date
    time su - hdfs -c "hadoop jar ${EXDIR}/hadoop-examples.jar teravalidate out-dir1TB out-dir1TBVal"
    date
  )
)
